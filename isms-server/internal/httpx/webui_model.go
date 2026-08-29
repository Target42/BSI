package httpx

import (
	"errors"
	"fmt"
	"net/http"
	"strconv"
	"strings"

	"github.com/Target42/BSI/isms-server/internal/auth"
	"github.com/Target42/BSI/isms-server/internal/domain"
	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgconn"
)

func flattenTargets(items []domain.TargetObject, progress map[int64]domain.ReportSummary) []webTargetRow {
	children := make(map[int64][]domain.TargetObject, len(items))
	var roots []domain.TargetObject
	for _, item := range items {
		if item.ParentID == 0 {
			roots = append(roots, item)
			continue
		}
		children[item.ParentID] = append(children[item.ParentID], item)
	}
	out := make([]webTargetRow, 0, len(items))
	var walk func(domain.TargetObject, int)
	walk = func(item domain.TargetObject, depth int) {
		row := webTargetRow{
			ID:             item.ID,
			Name:           item.Name,
			Type:           item.Type,
			Depth:          depth,
			ProtectionNeed: item.ProtectionNeed,
			IsRoot:         domain.IsRootScopeTarget(item.ParentID, item.Type),
			ChildTypes:     domain.AllowedChildTargetTypes(item.Type),
		}
		if progress != nil {
			row.Summary = progress[item.ID]
		}
		out = append(out, row)
		for _, child := range children[item.ID] {
			walk(child, depth+1)
		}
	}
	for _, root := range roots {
		walk(root, 0)
	}
	return out
}

func validApplicabilityStatus(status string) bool {
	switch status {
	case "", "Ungesetzt", "Benötigt", "Möglicherweise", "Nicht relevant":
		return true
	default:
		return false
	}
}

func (u *webUI) requireAdmin(w http.ResponseWriter, r *http.Request) (*auth.Claims, bool) {
	user, ok := auth.UserFromContext(r.Context())
	if !ok {
		http.Redirect(w, r, u.href("/login"), http.StatusSeeOther)
		return nil, false
	}
	admin, err := u.store.IsAdmin(r.Context(), user.UserID)
	if err != nil || !admin {
		http.Error(w, "Nur Administratoren.", http.StatusForbidden)
		return nil, false
	}
	return user, true
}

func (u *webUI) projectNewGet(w http.ResponseWriter, r *http.Request) {
	user, ok := auth.UserFromContext(r.Context())
	if !ok {
		u.redirectLogin(w, r)
		return
	}
	u.renderProjectNew(w, r, user, domain.Project{Visibility: domain.VisibilityPrivate}, "")
}

func (u *webUI) renderProjectNew(w http.ResponseWriter, r *http.Request, user *auth.Claims, draft domain.Project, errMsg string) {
	versions, _ := u.store.ListCatalogVersions(r.Context())
	if len(versions) == 0 {
		versions = []string{"2023"}
	}
	if draft.CatalogVersion == "" {
		draft.CatalogVersion = versions[0]
	}
	if draft.Visibility == "" {
		draft.Visibility = domain.VisibilityPrivate
	}
	u.render(w, r, "project_new", webPage{
		DisplayName:     user.DisplayName,
		CatalogVersions: versions,
		Project:         draft,
		Error:           errMsg,
	})
}

func (u *webUI) projectCreate(w http.ResponseWriter, r *http.Request) {
	user, ok := auth.UserFromContext(r.Context())
	if !ok {
		http.Redirect(w, r, u.href("/login"), http.StatusSeeOther)
		return
	}
	if err := r.ParseForm(); err != nil {
		u.renderProjectNew(w, r, user, domain.Project{}, "Ungültige Anfrage.")
		return
	}
	name := strings.TrimSpace(r.FormValue("name"))
	desc := strings.TrimSpace(r.FormValue("description"))
	version := strings.TrimSpace(r.FormValue("catalogVersion"))
	visibility := domain.NormalizeVisibility(r.FormValue("visibility"))
	draft := domain.Project{Name: name, Description: desc, CatalogVersion: version, Visibility: visibility}
	if name == "" {
		u.renderProjectNew(w, r, user, draft, "Name ist erforderlich.")
		return
	}
	if version == "" {
		version = "2023"
		draft.CatalogVersion = version
	}
	project, err := u.store.CreateProject(r.Context(), user.UserID, name, desc, version, visibility)
	if err != nil {
		u.renderProjectNew(w, r, user, draft, "Projekt konnte nicht angelegt werden.")
		return
	}
	http.Redirect(w, r, u.href(fmt.Sprintf("/projects/%d", project.ID)), http.StatusSeeOther)
}

func (u *webUI) targetCreate(w http.ResponseWriter, r *http.Request) {
	user, project, _, ok := u.projectAccess(w, r, "editor")
	if !ok {
		return
	}
	if err := r.ParseForm(); err != nil {
		u.renderProjectError(w, r, user, project, true, "Ungültige Anfrage.")
		return
	}
	parentID, _ := strconv.ParseInt(strings.TrimSpace(r.FormValue("parentID")), 10, 64)
	name := strings.TrimSpace(r.FormValue("name"))
	objectType := domain.NormalizeTargetObjectType(r.FormValue("type"))
	if name == "" || objectType == "" {
		u.renderProjectError(w, r, user, project, true, "Name und Typ sind erforderlich.")
		return
	}
	if err := validateTargetObjectPlacement(r.Context(), u.store, project.ID, parentID, objectType, 0); err != nil {
		u.renderProjectError(w, r, user, project, true, err.Error())
		return
	}
	item := domain.TargetObject{
		ProjectID:             project.ID,
		ParentID:              parentID,
		Type:                  objectType,
		Name:                  name,
		Description:           strings.TrimSpace(r.FormValue("description")),
		InheritProtectionNeed: parentID > 0,
		Confidentiality:       domain.CiaNormal,
		Integrity:             domain.CiaNormal,
		Availability:          domain.CiaNormal,
	}
	var parent *domain.TargetObject
	if parentID > 0 {
		p, err := u.store.GetTargetObject(r.Context(), parentID)
		if err != nil {
			u.renderProjectError(w, r, user, project, true, "Übergeordnetes Zielobjekt nicht gefunden.")
			return
		}
		parent = &p
	}
	domain.ApplyTargetObjectProtectionNeed(&item, parent)
	if _, err := u.store.CreateTargetObject(r.Context(), item); err != nil {
		u.renderProjectError(w, r, user, project, true, "Zielobjekt konnte nicht angelegt werden.")
		return
	}
	http.Redirect(w, r, u.href(fmt.Sprintf("/projects/%d?saved=1", project.ID)), http.StatusSeeOther)
}

func (u *webUI) renderProjectError(w http.ResponseWriter, r *http.Request, user *auth.Claims, project domain.Project, canEdit bool, errMsg string) {
	summary, targetProgress, _ := u.reports.ProjectProgress(r.Context(), project.ID)
	objects, _ := u.store.ListTargetObjects(r.Context(), project.ID)
	progressByTarget := make(map[int64]domain.ReportSummary, len(targetProgress))
	for _, item := range targetProgress {
		progressByTarget[item.TargetObjectID] = item.Summary
	}
	u.render(w, r, "project", webPage{
		DisplayName: user.DisplayName,
		CanEdit:     canEdit,
		Project:     project,
		Summary:     summary,
		Targets:     flattenTargets(objects, progressByTarget),
		CiaLevels:   webCiaLevels,
		Error:       errMsg,
	})
}

func (u *webUI) loadProjectTarget(w http.ResponseWriter, r *http.Request, project domain.Project) (domain.TargetObject, bool) {
	targetID, err := strconv.ParseInt(chi.URLParam(r, "targetObjectID"), 10, 64)
	if err != nil || targetID <= 0 {
		http.NotFound(w, r)
		return domain.TargetObject{}, false
	}
	target, err := u.store.GetTargetObject(r.Context(), targetID)
	if err != nil || target.ProjectID != project.ID {
		http.NotFound(w, r)
		return domain.TargetObject{}, false
	}
	return target, true
}

func (u *webUI) targetEditGet(w http.ResponseWriter, r *http.Request) {
	user, project, role, ok := u.projectAccess(w, r, "viewer")
	if !ok {
		return
	}
	target, ok := u.loadProjectTarget(w, r, project)
	if !ok {
		return
	}
	u.renderTargetEdit(w, r, user, project, roleCanEdit(role), target, "")
}

func (u *webUI) renderTargetEdit(w http.ResponseWriter, r *http.Request, user *auth.Claims, project domain.Project, canEdit bool, target domain.TargetObject, errMsg string) {
	objects, err := u.store.ListTargetObjects(r.Context(), project.ID)
	if err != nil {
		http.Error(w, "Zielobjekte konnten nicht geladen werden.", http.StatusInternalServerError)
		return
	}
	blocked := descendantIDs(objects, target.ID)
	blocked[target.ID] = struct{}{}
	var parents []domain.TargetObject
	for _, item := range objects {
		if _, skip := blocked[item.ID]; skip {
			continue
		}
		parents = append(parents, item)
	}
	var addTypes []string
	if !domain.IsRootScopeTarget(target.ParentID, target.Type) {
		if parent, found := domain.FindTargetByID(objects, target.ParentID); found {
			addTypes = domain.AllowedChildTargetTypes(parent.Type)
			foundType := false
			for _, t := range addTypes {
				if t == target.Type {
					foundType = true
					break
				}
			}
			if !foundType {
				addTypes = append([]string{target.Type}, addTypes...)
			}
		}
	}
	notice := ""
	if errMsg == "" && r.URL.Query().Get("saved") == "1" {
		notice = "Zielobjekt gespeichert."
	}
	u.render(w, r, "target", webPage{
		DisplayName:   user.DisplayName,
		CanEdit:       canEdit,
		Project:       project,
		Target:        target,
		ParentOptions: parents,
		AddTypes:      addTypes,
		CiaLevels:     webCiaLevels,
		Error:         errMsg,
		Notice:        notice,
	})
}

func descendantIDs(items []domain.TargetObject, rootID int64) map[int64]struct{} {
	blocked := map[int64]struct{}{}
	changed := true
	for changed {
		changed = false
		for _, item := range items {
			if item.ID == rootID || item.ParentID == rootID {
				if _, seen := blocked[item.ID]; !seen && item.ID != rootID && item.ParentID == rootID {
					blocked[item.ID] = struct{}{}
					changed = true
				}
			}
			if _, parentBlocked := blocked[item.ParentID]; parentBlocked {
				if _, seen := blocked[item.ID]; !seen {
					blocked[item.ID] = struct{}{}
					changed = true
				}
			}
		}
	}
	return blocked
}

func (u *webUI) targetEditSave(w http.ResponseWriter, r *http.Request) {
	user, project, _, ok := u.projectAccess(w, r, "editor")
	if !ok {
		return
	}
	current, ok := u.loadProjectTarget(w, r, project)
	if !ok {
		return
	}
	if err := r.ParseForm(); err != nil {
		u.renderTargetEdit(w, r, user, project, true, current, "Ungültige Anfrage.")
		return
	}
	name := strings.TrimSpace(r.FormValue("name"))
	if name == "" {
		u.renderTargetEdit(w, r, user, project, true, current, "Name ist erforderlich.")
		return
	}
	parentID := current.ParentID
	objectType := current.Type
	if !domain.IsRootScopeTarget(current.ParentID, current.Type) {
		parentID, _ = strconv.ParseInt(strings.TrimSpace(r.FormValue("parentID")), 10, 64)
		if parsed := domain.NormalizeTargetObjectType(r.FormValue("type")); parsed != "" {
			objectType = parsed
		}
	}
	if err := validateTargetObjectPlacement(r.Context(), u.store, project.ID, parentID, objectType, current.ID); err != nil {
		u.renderTargetEdit(w, r, user, project, true, current, err.Error())
		return
	}
	inherit := current.InheritProtectionNeed
	if parentID > 0 {
		inherit = formLast(r, "inherit") == "1"
	} else {
		inherit = false
	}
	item := domain.TargetObject{
		ID:                    current.ID,
		ProjectID:             project.ID,
		ParentID:              parentID,
		Type:                  objectType,
		Confidentiality:       strings.TrimSpace(r.FormValue("confidentiality")),
		Integrity:             strings.TrimSpace(r.FormValue("integrity")),
		Availability:          strings.TrimSpace(r.FormValue("availability")),
		InheritProtectionNeed: inherit,
		ProtectionNeedNote:    strings.TrimSpace(r.FormValue("protectionNeedNote")),
		Name:                  name,
		Description:           strings.TrimSpace(r.FormValue("description")),
	}
	var parent *domain.TargetObject
	if parentID > 0 {
		p, err := u.store.GetTargetObject(r.Context(), parentID)
		if err != nil {
			u.renderTargetEdit(w, r, user, project, true, current, "Übergeordnetes Zielobjekt nicht gefunden.")
			return
		}
		parent = &p
	}
	domain.ApplyTargetObjectProtectionNeed(&item, parent)
	updated, err := u.store.UpdateTargetObject(r.Context(), item)
	if err != nil {
		u.renderTargetEdit(w, r, user, project, true, current, "Zielobjekt konnte nicht gespeichert werden.")
		return
	}
	http.Redirect(w, r, u.href(fmt.Sprintf("/projects/%d/targets/%d/edit?saved=1", project.ID, updated.ID)), http.StatusSeeOther)
}

func formLast(r *http.Request, name string) string {
	vals := r.Form[name]
	if len(vals) == 0 {
		return ""
	}
	return vals[len(vals)-1]
}

func (u *webUI) targetDelete(w http.ResponseWriter, r *http.Request) {
	_, project, _, ok := u.projectAccess(w, r, "editor")
	if !ok {
		return
	}
	target, ok := u.loadProjectTarget(w, r, project)
	if !ok {
		return
	}
	if domain.IsRootScopeTarget(target.ParentID, target.Type) {
		http.Error(w, "Der Informationsverbund kann nicht gelöscht werden.", http.StatusConflict)
		return
	}
	if err := u.store.DeleteTargetObject(r.Context(), target.ID); err != nil {
		http.Error(w, "Zielobjekt konnte nicht gelöscht werden.", http.StatusInternalServerError)
		return
	}
	http.Redirect(w, r, u.href(fmt.Sprintf("/projects/%d?saved=1", project.ID)), http.StatusSeeOther)
}

func (u *webUI) applicabilityGet(w http.ResponseWriter, r *http.Request) {
	user, project, role, ok := u.projectAccess(w, r, "viewer")
	if !ok {
		return
	}
	target, ok := u.loadProjectTarget(w, r, project)
	if !ok {
		return
	}
	u.renderApplicability(w, r, user, project, roleCanEdit(role), target, "")
}

func (u *webUI) renderApplicability(w http.ResponseWriter, r *http.Request, user *auth.Claims, project domain.Project, canEdit bool, target domain.TargetObject, errMsg string) {
	bausteine, err := u.store.ListBausteine(r.Context(), webCatalogStandard, project.CatalogVersion)
	if err != nil {
		http.Error(w, "Katalog konnte nicht geladen werden.", http.StatusInternalServerError)
		return
	}
	objects, err := u.store.ListTargetObjects(r.Context(), project.ID)
	if err != nil {
		http.Error(w, "Zielobjekte konnten nicht geladen werden.", http.StatusInternalServerError)
		return
	}
	own, inherited, err := u.inheritedMaps(r, project.ID, objects, target)
	if err != nil {
		http.Error(w, "Anwendbarkeit konnte nicht geladen werden.", http.StatusInternalServerError)
		return
	}
	recs := recommendationIndex(bausteine, target)
	query := strings.TrimSpace(r.URL.Query().Get("q"))
	if query == "" {
		query = strings.TrimSpace(r.FormValue("q"))
	}
	status := r.URL.Query().Get("status")
	if status == "" {
		status = r.FormValue("filter")
	}
	if status == "" {
		status = "Alle"
	}
	highlight := queryFlag(r, "highlight", false)
	if r.Method == http.MethodPost && r.FormValue("highlight") == "1" {
		highlight = true
	}
	needle := strings.ToLower(query)
	rows := make([]webApplicabilityRow, 0, len(bausteine))
	for _, b := range bausteine {
		current := own[b.ID]
		item, isInherited := inherited[b.ID]
		display := current
		if display == "" && isInherited {
			display = item.Status
		}
		if !matchApplicabilityFilter(status, display, isInherited) {
			continue
		}
		if needle != "" {
			hay := strings.ToLower(strings.Join([]string{b.ExternalID, b.Title, b.GroupName}, " "))
			if !strings.Contains(hay, needle) {
				continue
			}
		}
		rec := recs[b.ID]
		rows = append(rows, webApplicabilityRow{
			Baustein:      b,
			Status:        display,
			OwnStatus:     current,
			Inherited:     isInherited,
			SourceCaption: item.SourceCaption,
			Recommended:   rec.BausteinID != 0,
			RecommendTier: rec.Tier,
		})
	}
	notice := ""
	if errMsg == "" {
		switch r.URL.Query().Get("saved") {
		case "1":
			notice = "Anwendbarkeit gespeichert."
		case "bulk":
			n, _ := strconv.Atoi(r.URL.Query().Get("n"))
			to := strings.TrimSpace(r.URL.Query().Get("to"))
			if to == "" {
				to = "ungesetzt"
			}
			notice = germanCount(n, "Baustein", "Bausteine") + " auf " + to + " gesetzt."
		}
	}
	u.render(w, r, "applicability", webPage{
		DisplayName:           user.DisplayName,
		CanEdit:               canEdit,
		Project:               project,
		Target:                target,
		Query:                 query,
		StatusFilter:          status,
		StatusFilters:         []string{"Alle", "Gesetzt", "Ungesetzt", "Geerbt", "Benötigt", "Möglicherweise", "Nicht relevant"},
		HighlightRecs:         highlight,
		ApplicabilityRows:     rows,
		ApplicabilityStatuses: webApplicabilityStatuses,
		Error:                 errMsg,
		Notice:                notice,
	})
}

func (u *webUI) applicabilitySave(w http.ResponseWriter, r *http.Request) {
	user, project, _, ok := u.projectAccess(w, r, "editor")
	if !ok {
		return
	}
	target, ok := u.loadProjectTarget(w, r, project)
	if !ok {
		return
	}
	if err := r.ParseForm(); err != nil {
		u.renderApplicability(w, r, user, project, true, target, "Ungültige Anfrage.")
		return
	}
	bausteinID, err := strconv.ParseInt(strings.TrimSpace(r.FormValue("bausteinID")), 10, 64)
	if err != nil || bausteinID <= 0 {
		u.renderApplicability(w, r, user, project, true, target, "Ungültiger Baustein.")
		return
	}
	status := strings.TrimSpace(r.FormValue("status"))
	if !validApplicabilityStatus(status) {
		u.renderApplicability(w, r, user, project, true, target, "Ungültiger Anwendbarkeitsstatus.")
		return
	}
	if status == "" || status == "Ungesetzt" {
		if err := u.store.DeleteApplicability(r.Context(), project.ID, target.ID, bausteinID); err != nil {
			u.renderApplicability(w, r, user, project, true, target, "Anwendbarkeit konnte nicht gelöscht werden.")
			return
		}
	} else {
		if _, err := u.store.SaveApplicability(r.Context(), domain.BausteinApplicability{
			ProjectID:      project.ID,
			TargetObjectID: target.ID,
			BausteinID:     bausteinID,
			Status:         status,
		}); err != nil {
			u.renderApplicability(w, r, user, project, true, target, "Anwendbarkeit konnte nicht gespeichert werden.")
			return
		}
	}
	http.Redirect(w, r, u.href(fmt.Sprintf("/projects/%d/targets/%d/applicability?saved=1", project.ID, target.ID)), http.StatusSeeOther)
}

func (u *webUI) accountGet(w http.ResponseWriter, r *http.Request) {
	user, ok := auth.UserFromContext(r.Context())
	if !ok {
		http.Redirect(w, r, u.href("/login"), http.StatusSeeOther)
		return
	}
	notice := ""
	if r.URL.Query().Get("saved") == "1" {
		notice = "Passwort geändert."
	}
	u.render(w, r, "account", webPage{
		DisplayName: user.DisplayName,
		Email:       user.Email,
		Notice:      notice,
	})
}

func (u *webUI) accountPassword(w http.ResponseWriter, r *http.Request) {
	user, ok := auth.UserFromContext(r.Context())
	if !ok {
		http.Redirect(w, r, u.href("/login"), http.StatusSeeOther)
		return
	}
	if err := r.ParseForm(); err != nil {
		u.render(w, r, "account", webPage{DisplayName: user.DisplayName, Email: user.Email, Error: "Ungültige Anfrage."})
		return
	}
	current := r.FormValue("currentPassword")
	next := r.FormValue("newPassword")
	repeat := r.FormValue("confirmPassword")
	if current == "" || next == "" {
		u.render(w, r, "account", webPage{DisplayName: user.DisplayName, Email: user.Email, Error: "Aktuelles und neues Passwort sind erforderlich."})
		return
	}
	if next != repeat {
		u.render(w, r, "account", webPage{DisplayName: user.DisplayName, Email: user.Email, Error: "Das neue Passwort und die Wiederholung stimmen nicht überein."})
		return
	}
	if len(next) < 8 {
		u.render(w, r, "account", webPage{DisplayName: user.DisplayName, Email: user.Email, Error: "Das neue Passwort muss mindestens 8 Zeichen haben."})
		return
	}
	_, hash, err := u.store.FindUserByEmail(r.Context(), user.Email)
	if err != nil || !auth.CheckPassword(hash, current) {
		u.render(w, r, "account", webPage{DisplayName: user.DisplayName, Email: user.Email, Error: "Aktuelles Passwort ist falsch."})
		return
	}
	newHash, err := auth.HashPassword(next)
	if err != nil {
		u.render(w, r, "account", webPage{DisplayName: user.DisplayName, Email: user.Email, Error: "Passwort konnte nicht gespeichert werden."})
		return
	}
	if err := u.store.UpdatePasswordHash(r.Context(), user.UserID, newHash); err != nil {
		u.render(w, r, "account", webPage{DisplayName: user.DisplayName, Email: user.Email, Error: "Passwort konnte nicht gespeichert werden."})
		return
	}
	http.Redirect(w, r, u.href("/account?saved=1"), http.StatusSeeOther)
}

func (u *webUI) usersGet(w http.ResponseWriter, r *http.Request) {
	user, ok := u.requireAdmin(w, r)
	if !ok {
		return
	}
	users, err := u.store.ListUsers(r.Context())
	if err != nil {
		u.render(w, r, "users", webPage{DisplayName: user.DisplayName, Error: "Benutzer konnten nicht geladen werden."})
		return
	}
	notice := ""
	if r.URL.Query().Get("saved") == "1" {
		notice = "Benutzer angelegt."
	}
	u.render(w, r, "users", webPage{
		DisplayName: user.DisplayName,
		Users:       users,
		Notice:      notice,
	})
}

func (u *webUI) userCreate(w http.ResponseWriter, r *http.Request) {
	actor, ok := u.requireAdmin(w, r)
	if !ok {
		return
	}
	if err := r.ParseForm(); err != nil {
		u.renderUsersError(w, r, actor, "Ungültige Anfrage.")
		return
	}
	email := strings.TrimSpace(strings.ToLower(r.FormValue("email")))
	displayName := strings.TrimSpace(r.FormValue("displayName"))
	password := r.FormValue("password")
	if email == "" || displayName == "" || password == "" {
		u.renderUsersError(w, r, actor, "E-Mail, Name und Passwort sind erforderlich.")
		return
	}
	if len(password) < 8 {
		u.renderUsersError(w, r, actor, "Das Passwort muss mindestens 8 Zeichen haben.")
		return
	}
	hash, err := auth.HashPassword(password)
	if err != nil {
		u.renderUsersError(w, r, actor, "Benutzer konnte nicht angelegt werden.")
		return
	}
	created, err := u.store.CreateUser(r.Context(), email, displayName, hash)
	if err != nil {
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23505" {
			u.renderUsersError(w, r, actor, "Diese E-Mail ist bereits vergeben.")
			return
		}
		u.renderUsersError(w, r, actor, "Benutzer konnte nicht angelegt werden.")
		return
	}
	if r.FormValue("isAdmin") == "1" {
		if err := u.store.SetUserAdmin(r.Context(), created.ID, true); err != nil {
			u.renderUsersError(w, r, actor, "Benutzer angelegt, Admin-Recht konnte nicht gesetzt werden.")
			return
		}
	}
	http.Redirect(w, r, u.href("/users?saved=1"), http.StatusSeeOther)
}

func (u *webUI) renderUsersError(w http.ResponseWriter, r *http.Request, user *auth.Claims, errMsg string) {
	users, _ := u.store.ListUsers(r.Context())
	u.render(w, r, "users", webPage{
		DisplayName: user.DisplayName,
		Users:       users,
		Error:       errMsg,
	})
}
