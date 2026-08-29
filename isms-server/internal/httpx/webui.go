package httpx

import (
	"embed"
	"errors"
	"fmt"
	"html/template"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"time"

	"github.com/Target42/BSI/isms-server/internal/auth"
	"github.com/Target42/BSI/isms-server/internal/catalog"
	"github.com/Target42/BSI/isms-server/internal/domain"
	"github.com/Target42/BSI/isms-server/internal/repository"
	"github.com/Target42/BSI/isms-server/internal/service"
	"github.com/go-chi/chi/v5"
)

//go:embed webuiassets/app.css webuiassets/app.js webuiassets/favicon.svg webuiassets/templates/*.html
var webUIAssets embed.FS

var webStatusFilters = []string{"Alle", "Offen", "Teilweise", "Erfüllt", "Entfällt", "Überfällig"}
var webMeasureStatusFilters = []string{"Alle", "Offen", "In Bearbeitung", "Erledigt"}
var webMeasureStatuses = []string{"Offen", "In Bearbeitung", "Erledigt"}
var webAssessmentStatuses = []string{"Offen", "Teilweise", "Erfüllt", "Entfällt"}
var webMemberRoles = []string{"owner", "editor", "viewer"}
var webCiaLevels = []string{domain.CiaNormal, domain.CiaHigh, domain.CiaVeryHigh}
var webApplicabilityStatuses = []string{"Benötigt", "Möglicherweise", "Nicht relevant"}
var webCatalogStandard = "IT-Grundschutz"

type webUI struct {
	auth    *auth.Service
	store   *repository.Store
	reports *service.ReportService
	base    string
	tmpl    *template.Template
	css     []byte
	js      []byte
	favicon []byte
	limiter *loginLimiter
}

type webPage struct {
	Title                 string
	Error                 string
	Notice                string
	DisplayName           string
	Email                 string
	CanEdit               bool
	CanOwn                bool
	LoggedIn              bool
	IsMember              bool
	IsAdmin               bool
	CurrentUserID         int64
	OwnerCount            int
	Members               []repository.ProjectMember
	MemberRoles           []string
	MemberEmail           string
	Projects              []domain.Project
	Project               domain.Project
	Summary               domain.ReportSummary
	Targets               []webTargetRow
	AddUnder              int64
	AddUnderName          string
	AddTypes              []string
	ParentOptions         []domain.TargetObject
	CiaLevels             []string
	CatalogVersions       []string
	ApplicabilityRows     []webApplicabilityRow
	ApplicabilityStatuses []string
	Users                 []domain.User
	Rows                  []domain.ReportRow
	Query                 string
	StatusFilter          string
	StatusFilters         []string
	HideDone              bool
	Measures              []webMeasureRow
	MeasureStatuses       []string
	Assessment            domain.RequirementAssessment
	AssessmentStatuses    []string
	Requirement           domain.Requirement
	Requirements          []domain.Requirement
	Baustein              domain.Baustein
	Target                domain.TargetObject
	RelatedMeasures       []webMeasureRow
	Measure               domain.Measure
	CSVHref               string
	Hint                  string
	Recommendations       []webRecommendation
	SelectedVersion       string
	Bausteine             []domain.Baustein
	CatalogHits           []service.CatalogHit
	CatalogTruncated      bool
	CatalogGroups         []webCatalogGroup
	HighlightID           int64
	BausteinCount         int
	RequirementCount      int
	WorkBausteine         []webWorkBaustein
	WorkReqs              []webWorkReq
	HighlightRecs         bool
	Inherited             bool
	InheritedFrom         string
	Deviation             string
	PrintDate             string
	NextPath              string
	CSRFToken             string
}

type webWorkBaustein struct {
	domain.Baustein
	Status        string
	Inherited     bool
	SourceCaption string
	Recommended   bool
	RecommendTier string
	OpenCount     int
	TotalCount    int
}

type webWorkReq struct {
	domain.Requirement
	Status  string
	Overdue bool
}

type webRecommendation struct {
	service.Recommendation
	Current  string
	Locked   bool
	Selected bool
}

type webTargetRow struct {
	ID             int64
	Name           string
	Type           string
	Depth          int
	ProtectionNeed string
	IsRoot         bool
	ChildTypes     []string
	Summary        domain.ReportSummary
}

type webApplicabilityRow struct {
	domain.Baustein
	Status        string
	OwnStatus     string
	Inherited     bool
	SourceCaption string
	Recommended   bool
	RecommendTier string
}

type webCatalogGroup struct {
	Name      string
	Bausteine []domain.Baustein
	Hits      []service.CatalogHit
}

type webMeasureRow struct {
	domain.Measure
	Overdue bool
}

func newWebUI(authService *auth.Service, store *repository.Store, reports *service.ReportService, publicBase string, limiter *loginLimiter) *webUI {
	u := &webUI{
		auth:    authService,
		store:   store,
		reports: reports,
		base:    strings.TrimRight(publicBase, "/"),
		limiter: limiter,
	}
	css, err := webUIAssets.ReadFile("webuiassets/app.css")
	if err != nil {
		panic("web ui css: " + err.Error())
	}
	js, err := webUIAssets.ReadFile("webuiassets/app.js")
	if err != nil {
		panic("web ui js: " + err.Error())
	}
	favicon, err := webUIAssets.ReadFile("webuiassets/favicon.svg")
	if err != nil {
		panic("web ui favicon: " + err.Error())
	}
	u.css = css
	u.js = js
	u.favicon = favicon

	tmpl, err := template.New("webui").Funcs(template.FuncMap{
		"href":            u.href,
		"roleLabel":       roleLabel,
		"visibilityLabel": domain.VisibilityLabel,
		"formatDate":      formatWebDate,
		"formatDue":       formatDueDate,
		"dueValue":        dueValue,
		"statusClass":     statusClass,
		"padLeft":         padLeft,
		"reqHTML":         reqHTML,
	}).ParseFS(webUIAssets, "webuiassets/templates/*.html")
	if err != nil {
		panic("web ui templates: " + err.Error())
	}
	u.tmpl = tmpl
	return u
}

func (u *webUI) href(path string) string {
	if path == "" {
		path = "/"
	}
	if !strings.HasPrefix(path, "/") {
		path = "/" + path
	}
	return u.base + path
}

func (u *webUI) cookiePath() string {
	if u.base == "" {
		return "/"
	}
	return u.base
}

func (u *webUI) mount(r chi.Router) {
	r.Get("/ui/app.css", u.serveCSS)
	r.Get("/ui/app.js", u.serveJS)
	r.Get("/ui/favicon.svg", u.serveFavicon)
	r.Get("/login", u.loginGet)
	r.With(u.limitLogin).Post("/login", u.loginPost)
	r.Post("/logout", u.logout)

	r.Group(func(g chi.Router) {
		g.Use(u.cookieAuth)
		g.Get("/", u.home)
		g.Get("/projects", u.projects)
		g.Get("/projects/new", u.projectNewGet)
		g.Post("/projects/new", u.projectCreate)
		g.Get("/projects/{projectID}", u.projectHome)
		g.Get("/projects/{projectID}/report", u.report)
		g.Get("/projects/{projectID}/report.csv", u.reportCSV)
		g.Get("/projects/{projectID}/cockpit", u.cockpit)
		g.Get("/projects/{projectID}/members", u.members)
		g.Post("/projects/{projectID}/members", u.memberAdd)
		g.Post("/projects/{projectID}/members/{userID}", u.memberUpdate)
		g.Post("/projects/{projectID}/members/{userID}/remove", u.memberRemove)
		g.Post("/projects/{projectID}/targets", u.targetCreate)
		g.Get("/projects/{projectID}/targets/{targetObjectID}", u.workplaceGet)
		g.Get("/projects/{projectID}/targets/{targetObjectID}/edit", u.targetEditGet)
		g.Post("/projects/{projectID}/targets/{targetObjectID}/edit", u.targetEditSave)
		g.Post("/projects/{projectID}/targets/{targetObjectID}/delete", u.targetDelete)
		g.Get("/projects/{projectID}/targets/{targetObjectID}/applicability", u.applicabilityGet)
		g.Post("/projects/{projectID}/targets/{targetObjectID}/applicability", u.applicabilitySave)
		g.Post("/projects/{projectID}/targets/{targetObjectID}/applicability/bulk", u.applicabilityBulk)
		g.Post("/projects/{projectID}/targets/{targetObjectID}/assessments/bulk", u.assessmentsBulk)
		g.Get("/projects/{projectID}/targets/{targetObjectID}/recommendations", u.recommendationsGet)
		g.Post("/projects/{projectID}/targets/{targetObjectID}/recommendations", u.recommendationsApply)
		g.Get("/projects/{projectID}/settings", u.projectSettingsGet)
		g.Post("/projects/{projectID}/settings", u.projectSettingsSave)
		g.Get("/projects/{projectID}/edit", u.projectSettingsGet)
		g.Post("/projects/{projectID}/edit", u.projectSettingsSave)
		g.Post("/projects/{projectID}/delete", u.projectDelete)
		g.Get("/catalog", u.catalogGet)
		g.Get("/catalog/bausteine/{bausteinID}", u.catalogBausteinGet)
		g.Post("/catalog/import", u.catalogImport)
		g.Post("/projects/{projectID}/measures/{measureID}", u.measureStatus)
		g.Get("/projects/{projectID}/measures/{measureID}", u.measureEditGet)
		g.Post("/projects/{projectID}/measures/{measureID}/edit", u.measureEditSave)
		g.Post("/projects/{projectID}/measures/{measureID}/delete", u.measureDelete)
		g.Get("/projects/{projectID}/targets/{targetObjectID}/requirements/{requirementID}", u.assessmentGet)
		g.Post("/projects/{projectID}/targets/{targetObjectID}/requirements/{requirementID}", u.assessmentSave)
		g.Post("/projects/{projectID}/targets/{targetObjectID}/requirements/{requirementID}/measures", u.measureCreate)
		g.Post("/projects/{projectID}/targets/{targetObjectID}/deviation", u.deviationSave)
		g.Get("/account", u.accountGet)
		g.Post("/account/password", u.accountPassword)
		g.Get("/users", u.usersGet)
		g.Post("/users", u.userCreate)
	})
}

func (u *webUI) serveCSS(w http.ResponseWriter, _ *http.Request) {
	w.Header().Set("Content-Type", "text/css; charset=utf-8")
	w.Header().Set("Cache-Control", "no-store")
	_, _ = w.Write(u.css)
}

func (u *webUI) serveJS(w http.ResponseWriter, _ *http.Request) {
	w.Header().Set("Content-Type", "text/javascript; charset=utf-8")
	w.Header().Set("Cache-Control", "no-store")
	_, _ = w.Write(u.js)
}

func (u *webUI) serveFavicon(w http.ResponseWriter, _ *http.Request) {
	w.Header().Set("Content-Type", "image/svg+xml")
	w.Header().Set("Cache-Control", "public, max-age=86400")
	_, _ = w.Write(u.favicon)
}

func (u *webUI) cookieAuth(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		claims, err := u.auth.ClaimsFromCookie(r)
		if err != nil {
			if errors.Is(err, auth.ErrSessionRevoked) {
				auth.ClearSessionCookie(w, u.cookiePath())
			}
			next.ServeHTTP(w, r)
			return
		}
		next.ServeHTTP(w, r.WithContext(auth.ContextWithUser(r.Context(), claims)))
	})
}

func (u *webUI) limitLogin(next http.Handler) http.Handler {
	return u.limiter.Middleware(next)
}

func safeNextPath(raw string) string {
	raw = strings.TrimSpace(raw)
	if raw == "" || !strings.HasPrefix(raw, "/") || strings.HasPrefix(raw, "//") || strings.Contains(raw, "://") {
		return ""
	}
	return raw
}

func (u *webUI) redirectLogin(w http.ResponseWriter, r *http.Request) {
	next := r.URL.RequestURI()
	target := u.href("/login")
	if next != "" && next != "/login" && !strings.HasPrefix(next, "/login?") {
		target += "?next=" + url.QueryEscape(next)
	}
	http.Redirect(w, r, target, http.StatusSeeOther)
}

func (u *webUI) loginGet(w http.ResponseWriter, r *http.Request) {
	if _, err := u.auth.ClaimsFromCookie(r); err == nil {
		http.Redirect(w, r, u.href("/projects"), http.StatusSeeOther)
		return
	} else if errors.Is(err, auth.ErrSessionRevoked) {
		auth.ClearSessionCookie(w, u.cookiePath())
	}
	u.render(w, r, "login", webPage{Title: "Anmelden", NextPath: safeNextPath(r.URL.Query().Get("next"))})
}

func (u *webUI) loginPost(w http.ResponseWriter, r *http.Request) {
	if err := r.ParseForm(); err != nil {
		u.render(w, r, "login", webPage{Error: "Ungültige Anfrage."})
		return
	}
	next := safeNextPath(r.FormValue("next"))
	email := strings.TrimSpace(r.FormValue("email"))
	password := r.FormValue("password")
	if email == "" || password == "" {
		u.render(w, r, "login", webPage{Email: email, NextPath: next, Error: "E-Mail und Passwort sind erforderlich."})
		return
	}
	if u.store == nil {
		u.render(w, r, "login", webPage{Email: email, NextPath: next, Error: "E-Mail oder Passwort ist falsch."})
		return
	}

	user, passwordHash, err := u.store.FindUserByEmail(r.Context(), email)
	if err != nil || !auth.CheckPassword(passwordHash, password) {
		u.render(w, r, "login", webPage{Email: email, NextPath: next, Error: "E-Mail oder Passwort ist falsch."})
		return
	}

	token, err := u.auth.CreateToken(user.ID, user.Email, user.DisplayName, user.TokenVersion)
	if err != nil {
		u.render(w, r, "login", webPage{Email: email, NextPath: next, Error: "Anmeldung fehlgeschlagen."})
		return
	}
	u.auth.SetSessionCookie(w, r, token.AccessToken, token.ExpiresAt, u.cookiePath())
	if next == "" {
		next = "/projects"
	}
	http.Redirect(w, r, u.href(next), http.StatusSeeOther)
}

func (u *webUI) logout(w http.ResponseWriter, r *http.Request) {
	auth.ClearSessionCookie(w, u.cookiePath())
	http.Redirect(w, r, u.href("/"), http.StatusSeeOther)
}

func (u *webUI) home(w http.ResponseWriter, r *http.Request) {
	user, loggedIn := auth.UserFromContext(r.Context())
	page := webPage{}
	if loggedIn {
		page.DisplayName = user.DisplayName
	}
	if u.store != nil && !loggedIn {
		projects, err := u.store.ListProjects(r.Context(), 0)
		if err != nil {
			page.Error = "Öffentliche Projekte konnten nicht geladen werden."
		} else {
			page.Projects = projects
		}
	}
	u.render(w, r, "home", page)
}

func (u *webUI) projects(w http.ResponseWriter, r *http.Request) {
	user, loggedIn := auth.UserFromContext(r.Context())
	page := webPage{}
	if loggedIn {
		page.DisplayName = user.DisplayName
	}
	if u.store == nil {
		u.render(w, r, "projects", page)
		return
	}
	userID := int64(0)
	if loggedIn {
		userID = user.UserID
	}
	projects, err := u.store.ListProjects(r.Context(), userID)
	if err != nil {
		page.Error = "Projekte konnten nicht geladen werden."
		u.render(w, r, "projects", page)
		return
	}
	notice := ""
	switch r.URL.Query().Get("saved") {
	case "created":
		notice = "Projekt angelegt."
	case "deleted":
		notice = "Projekt gelöscht."
	}
	page.Projects = projects
	page.Notice = notice
	u.render(w, r, "projects", page)
}

func (u *webUI) projectHome(w http.ResponseWriter, r *http.Request) {
	user, project, role, ok := u.projectAccess(w, r, "viewer")
	if !ok {
		return
	}

	summary, targetProgress, err := u.reports.ProjectProgress(r.Context(), project.ID)
	if err != nil {
		u.render(w, r, "project", webPage{
			DisplayName: user.DisplayName,
			Project:     project,
			Error:       "Fortschritt konnte nicht geladen werden.",
		})
		return
	}
	objects, err := u.store.ListTargetObjects(r.Context(), project.ID)
	if err != nil {
		u.render(w, r, "project", webPage{
			DisplayName: user.DisplayName,
			CanEdit:     roleCanEdit(role),
			Project:     project,
			Error:       "Zielobjekte konnten nicht geladen werden.",
		})
		return
	}
	progressByTarget := make(map[int64]domain.ReportSummary, len(targetProgress))
	for _, item := range targetProgress {
		progressByTarget[item.TargetObjectID] = item.Summary
	}
	rows := flattenTargets(objects, progressByTarget)
	addUnder, _ := strconv.ParseInt(r.URL.Query().Get("addUnder"), 10, 64)
	page := webPage{
		DisplayName: displayName(user),
		CanEdit:     roleCanEdit(role),
		CanOwn:      roleCanOwn(role),
		IsMember:    project.IsMember,
		Project:     project,
		Summary:     summary,
		Targets:     rows,
		CiaLevels:   webCiaLevels,
	}
	if errMsg := r.URL.Query().Get("err"); errMsg != "" {
		page.Error = errMsg
	}
	if r.URL.Query().Get("saved") == "1" {
		page.Notice = "Zielobjekt gespeichert."
	}
	if r.URL.Query().Get("saved") == "settings" {
		page.Notice = "Projekteigenschaften gespeichert."
	}
	if addUnder > 0 {
		parent, found := domain.FindTargetByID(objects, addUnder)
		if found && parent.ProjectID == project.ID {
			page.AddUnder = parent.ID
			page.AddUnderName = parent.Name
			page.AddTypes = domain.AllowedChildTargetTypes(parent.Type)
		}
	}
	u.render(w, r, "project", page)
}

func (u *webUI) report(w http.ResponseWriter, r *http.Request) {
	user, project, role, ok := u.projectAccess(w, r, "viewer")
	if !ok {
		return
	}
	rows, err := u.reports.BuildSollIstReport(r.Context(), project.ID, 0, "")
	if err != nil {
		u.render(w, r, "report", webPage{
			DisplayName:   user.DisplayName,
			Project:       project,
			StatusFilters: webStatusFilters,
			Error:         "Report konnte nicht geladen werden.",
		})
		return
	}
	query := strings.TrimSpace(r.URL.Query().Get("q"))
	status := r.URL.Query().Get("status")
	if status == "" {
		status = "Alle"
	}
	filtered := filterReportRows(rows, query, status)
	u.render(w, r, "report", webPage{
		DisplayName:   user.DisplayName,
		CanEdit:       roleCanEdit(role),
		Project:       project,
		Summary:       service.Summarize(rows),
		Rows:          filtered,
		Query:         query,
		StatusFilter:  status,
		StatusFilters: webStatusFilters,
		CSVHref:       u.reportCSVHref(project.ID, query, status),
		PrintDate:     time.Now().Format("02.01.2006, 15:04"),
	})
}

func (u *webUI) reportCSV(w http.ResponseWriter, r *http.Request) {
	_, project, _, ok := u.projectAccess(w, r, "viewer")
	if !ok {
		return
	}
	rows, err := u.reports.BuildSollIstReport(r.Context(), project.ID, 0, "")
	if err != nil {
		http.Error(w, "Report konnte nicht geladen werden.", http.StatusInternalServerError)
		return
	}
	query := strings.TrimSpace(r.URL.Query().Get("q"))
	status := r.URL.Query().Get("status")
	if status == "" {
		status = "Alle"
	}
	filtered := filterReportRows(rows, query, status)
	w.Header().Set("Content-Type", "text/csv; charset=utf-8")
	w.Header().Set("Content-Disposition", `attachment; filename="`+csvFileName(project.Name)+`"`)
	if err := writeSollIstCSV(w, filtered); err != nil {
		http.Error(w, "CSV konnte nicht erzeugt werden.", http.StatusInternalServerError)
	}
}

func (u *webUI) reportCSVHref(projectID int64, query, status string) string {
	path := fmt.Sprintf("/projects/%d/report.csv", projectID)
	values := url.Values{}
	if query != "" {
		values.Set("q", query)
	}
	if status != "" && status != "Alle" {
		values.Set("status", status)
	}
	if encoded := values.Encode(); encoded != "" {
		path += "?" + encoded
	}
	return u.href(path)
}

func (u *webUI) cockpit(w http.ResponseWriter, r *http.Request) {
	user, project, role, ok := u.projectAccess(w, r, "viewer")
	if !ok {
		return
	}
	u.renderCockpit(w, r, user, project, roleCanEdit(role), "")
}

func (u *webUI) renderCockpit(w http.ResponseWriter, r *http.Request, user *auth.Claims, project domain.Project, canEdit bool, errMsg string) {
	items, err := u.store.ListProjectMeasures(r.Context(), project.ID)
	if err != nil {
		u.render(w, r, "cockpit", webPage{
			DisplayName:     user.DisplayName,
			CanEdit:         canEdit,
			Project:         project,
			StatusFilters:   webMeasureStatusFilters,
			MeasureStatuses: webMeasureStatuses,
			Error:           "Maßnahmen konnten nicht geladen werden.",
		})
		return
	}
	query := strings.TrimSpace(r.URL.Query().Get("q"))
	status := r.URL.Query().Get("status")
	if status == "" {
		status = "Alle"
	}
	hideDone := r.URL.Query().Get("hideDone") == "1"
	filtered := filterMeasures(items, query, status, hideDone)
	notice := ""
	if errMsg == "" && r.URL.Query().Get("saved") == "1" {
		notice = "Maßnahme gespeichert."
	}
	u.render(w, r, "cockpit", webPage{
		DisplayName:     user.DisplayName,
		CanEdit:         canEdit,
		Project:         project,
		Error:           errMsg,
		Notice:          notice,
		Query:           query,
		StatusFilter:    status,
		StatusFilters:   webMeasureStatusFilters,
		HideDone:        hideDone,
		Measures:        filtered,
		MeasureStatuses: webMeasureStatuses,
	})
}

func (u *webUI) measureStatus(w http.ResponseWriter, r *http.Request) {
	user, project, role, ok := u.projectAccess(w, r, "editor")
	if !ok {
		return
	}
	if err := r.ParseForm(); err != nil {
		u.renderCockpit(w, r, user, project, true, "Ungültige Anfrage.")
		return
	}
	measureID, err := strconv.ParseInt(chi.URLParam(r, "measureID"), 10, 64)
	if err != nil || measureID <= 0 {
		http.NotFound(w, r)
		return
	}
	measure, err := u.store.GetMeasure(r.Context(), measureID)
	if err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			http.NotFound(w, r)
			return
		}
		http.Error(w, "Maßnahme konnte nicht geladen werden.", http.StatusInternalServerError)
		return
	}
	if measure.ProjectID != project.ID {
		http.NotFound(w, r)
		return
	}
	status := strings.TrimSpace(r.FormValue("status"))
	if !validMeasureStatus(status) {
		u.renderCockpit(w, r, user, project, roleCanEdit(role), "Ungültiger Maßnahmenstatus.")
		return
	}
	version, _ := strconv.Atoi(strings.TrimSpace(r.FormValue("version")))
	_, err = u.store.UpdateMeasure(r.Context(), domain.Measure{
		ID:          measure.ID,
		Title:       measure.Title,
		Description: measure.Description,
		Responsible: measure.Responsible,
		DueDate:     measure.DueDate,
		Status:      status,
		Version:     version,
	})
	if err != nil {
		if errors.Is(err, repository.ErrVersionConflict) {
			u.renderCockpit(w, r, user, project, true,
				"Die Maßnahme wurde inzwischen geändert. Bitte prüfen Sie den aktuellen Stand und speichern Sie erneut.")
			return
		}
		u.renderCockpit(w, r, user, project, true, "Maßnahme konnte nicht gespeichert werden.")
		return
	}
	http.Redirect(w, r, u.href(fmt.Sprintf("/projects/%d/cockpit?saved=1", project.ID)), http.StatusSeeOther)
}

func (u *webUI) members(w http.ResponseWriter, r *http.Request) {
	user, project, role, ok := u.projectMemberAccess(w, r, "viewer")
	if !ok {
		return
	}
	u.renderMembers(w, r, user, project, role, "", "")
}

func (u *webUI) renderMembers(w http.ResponseWriter, r *http.Request, user *auth.Claims, project domain.Project, role, errMsg, email string) {
	members, err := u.store.ListProjectMembers(r.Context(), project.ID)
	if err != nil {
		u.render(w, r, "members", webPage{
			DisplayName:   user.DisplayName,
			CanOwn:        roleCanOwn(role),
			CurrentUserID: user.UserID,
			Project:       project,
			MemberRoles:   webMemberRoles,
			Error:         "Mitglieder konnten nicht geladen werden.",
		})
		return
	}
	owners, err := u.store.CountProjectOwners(r.Context(), project.ID)
	if err != nil {
		u.render(w, r, "members", webPage{
			DisplayName:   user.DisplayName,
			CanOwn:        roleCanOwn(role),
			CurrentUserID: user.UserID,
			Project:       project,
			Members:       members,
			MemberRoles:   webMemberRoles,
			Error:         "Mitglieder konnten nicht geladen werden.",
		})
		return
	}
	notice := ""
	if errMsg == "" {
		switch r.URL.Query().Get("saved") {
		case "1":
			notice = "Mitglied gespeichert."
		case "added":
			notice = "Mitglied hinzugefügt."
		case "removed":
			notice = "Mitglied entfernt."
		}
	}
	u.render(w, r, "members", webPage{
		DisplayName:   user.DisplayName,
		CanOwn:        roleCanOwn(role),
		CurrentUserID: user.UserID,
		OwnerCount:    owners,
		Project:       project,
		Members:       members,
		MemberRoles:   webMemberRoles,
		MemberEmail:   email,
		Error:         errMsg,
		Notice:        notice,
	})
}

func (u *webUI) memberAdd(w http.ResponseWriter, r *http.Request) {
	user, project, role, ok := u.projectAccess(w, r, "owner")
	if !ok {
		return
	}
	if err := r.ParseForm(); err != nil {
		u.renderMembers(w, r, user, project, role, "Ungültige Anfrage.", "")
		return
	}
	email := strings.TrimSpace(r.FormValue("email"))
	memberRole := strings.TrimSpace(r.FormValue("role"))
	if memberRole == "" {
		memberRole = "editor"
	}
	if email == "" {
		u.renderMembers(w, r, user, project, role, "E-Mail ist erforderlich.", email)
		return
	}
	if !validMemberRole(memberRole) {
		u.renderMembers(w, r, user, project, role, "Ungültige Rolle.", email)
		return
	}
	found, _, err := u.store.FindUserByEmail(r.Context(), email)
	if err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			u.renderMembers(w, r, user, project, role,
				"Kein Benutzer mit dieser E-Mail. Anlegen über einen Administrator oder den Desktop-Client.", email)
			return
		}
		u.renderMembers(w, r, user, project, role, "Benutzer konnte nicht gesucht werden.", email)
		return
	}
	if _, err := u.store.AddProjectMember(r.Context(), project.ID, found.ID, memberRole); err != nil {
		u.renderMembers(w, r, user, project, role, "Mitglied konnte nicht hinzugefügt werden.", email)
		return
	}
	http.Redirect(w, r, u.href(fmt.Sprintf("/projects/%d/members?saved=added", project.ID)), http.StatusSeeOther)
}

func (u *webUI) memberUpdate(w http.ResponseWriter, r *http.Request) {
	user, project, role, ok := u.projectAccess(w, r, "owner")
	if !ok {
		return
	}
	if err := r.ParseForm(); err != nil {
		u.renderMembers(w, r, user, project, role, "Ungültige Anfrage.", "")
		return
	}
	memberUserID, err := strconv.ParseInt(chi.URLParam(r, "userID"), 10, 64)
	if err != nil || memberUserID <= 0 {
		http.NotFound(w, r)
		return
	}
	newRole := strings.TrimSpace(r.FormValue("role"))
	if !validMemberRole(newRole) {
		u.renderMembers(w, r, user, project, role, "Ungültige Rolle.", "")
		return
	}
	currentRole, err := u.store.ProjectRole(r.Context(), project.ID, memberUserID)
	if err != nil {
		u.renderMembers(w, r, user, project, role, "Mitglied nicht gefunden.", "")
		return
	}
	if currentRole == "owner" && newRole != "owner" {
		if blocked, blockErr := u.blocksLastOwner(r, project.ID); blockErr != nil {
			u.renderMembers(w, r, user, project, role, "Rolle konnte nicht geändert werden.", "")
			return
		} else if blocked {
			u.renderMembers(w, r, user, project, role, "Der letzte Besitzer kann nicht herabgestuft werden.", "")
			return
		}
	}
	if _, err := u.store.UpdateProjectMemberRole(r.Context(), project.ID, memberUserID, newRole); err != nil {
		u.renderMembers(w, r, user, project, role, "Rolle konnte nicht geändert werden.", "")
		return
	}
	http.Redirect(w, r, u.href(fmt.Sprintf("/projects/%d/members?saved=1", project.ID)), http.StatusSeeOther)
}

func (u *webUI) memberRemove(w http.ResponseWriter, r *http.Request) {
	user, project, role, ok := u.projectAccess(w, r, "owner")
	if !ok {
		return
	}
	memberUserID, err := strconv.ParseInt(chi.URLParam(r, "userID"), 10, 64)
	if err != nil || memberUserID <= 0 {
		http.NotFound(w, r)
		return
	}
	if memberUserID == user.UserID {
		u.renderMembers(w, r, user, project, role, "Sie können sich nicht selbst entfernen.", "")
		return
	}
	currentRole, err := u.store.ProjectRole(r.Context(), project.ID, memberUserID)
	if err != nil {
		u.renderMembers(w, r, user, project, role, "Mitglied nicht gefunden.", "")
		return
	}
	if currentRole == "owner" {
		if blocked, blockErr := u.blocksLastOwner(r, project.ID); blockErr != nil {
			u.renderMembers(w, r, user, project, role, "Mitglied konnte nicht entfernt werden.", "")
			return
		} else if blocked {
			u.renderMembers(w, r, user, project, role, "Der letzte Besitzer kann nicht entfernt werden.", "")
			return
		}
	}
	if err := u.store.RemoveProjectMember(r.Context(), project.ID, memberUserID); err != nil {
		u.renderMembers(w, r, user, project, role, "Mitglied konnte nicht entfernt werden.", "")
		return
	}
	http.Redirect(w, r, u.href(fmt.Sprintf("/projects/%d/members?saved=removed", project.ID)), http.StatusSeeOther)
}

func (u *webUI) blocksLastOwner(r *http.Request, projectID int64) (bool, error) {
	owners, err := u.store.CountProjectOwners(r.Context(), projectID)
	if err != nil {
		return false, err
	}
	return owners <= 1, nil
}

func (u *webUI) measureCreate(w http.ResponseWriter, r *http.Request) {
	user, project, _, ok := u.projectAccess(w, r, "editor")
	if !ok {
		return
	}
	ctx, ok := u.loadAssessmentPage(w, r, project)
	if !ok {
		return
	}
	if ctx.Inherited {
		u.renderAssessment(w, r, user, project, true, ctx, "Maßnahmen zu geerbten Bausteinen gehören zum übergeordneten Zielobjekt.", "")
		return
	}
	if err := r.ParseForm(); err != nil {
		u.renderAssessment(w, r, user, project, true, ctx, "Ungültige Anfrage.", "")
		return
	}
	title := strings.TrimSpace(r.FormValue("title"))
	if title == "" {
		u.renderAssessment(w, r, user, project, true, ctx, "Titel der Maßnahme ist erforderlich.", "")
		return
	}
	status := strings.TrimSpace(r.FormValue("status"))
	if status == "" {
		status = "Offen"
	}
	if !validMeasureStatus(status) {
		u.renderAssessment(w, r, user, project, true, ctx, "Ungültiger Maßnahmenstatus.", "")
		return
	}
	if _, err := u.store.CreateMeasure(r.Context(), domain.Measure{
		ProjectID:      project.ID,
		TargetObjectID: ctx.Target.ID,
		RequirementID:  ctx.Requirement.ID,
		Title:          title,
		Description:    strings.TrimSpace(r.FormValue("description")),
		Responsible:    strings.TrimSpace(r.FormValue("responsible")),
		DueDate:        parseDueDate(r.FormValue("dueDate")),
		Status:         status,
	}); err != nil {
		u.renderAssessment(w, r, user, project, true, ctx, "Maßnahme konnte nicht angelegt werden.", "")
		return
	}
	http.Redirect(w, r, u.assessmentURL(project.ID, ctx.Target.ID, ctx.Requirement.ID, "created"), http.StatusSeeOther)
}

func (u *webUI) measureEditGet(w http.ResponseWriter, r *http.Request) {
	user, project, role, ok := u.projectAccess(w, r, "viewer")
	if !ok {
		return
	}
	measure, ok := u.loadProjectMeasure(w, r, project)
	if !ok {
		return
	}
	notice := ""
	if r.URL.Query().Get("saved") == "1" {
		notice = "Maßnahme gespeichert."
	}
	u.renderMeasure(w, r, user, project, roleCanEdit(role), measure, "", notice)
}

func (u *webUI) measureEditSave(w http.ResponseWriter, r *http.Request) {
	user, project, _, ok := u.projectAccess(w, r, "editor")
	if !ok {
		return
	}
	measure, ok := u.loadProjectMeasure(w, r, project)
	if !ok {
		return
	}
	if err := r.ParseForm(); err != nil {
		u.renderMeasure(w, r, user, project, true, measure, "Ungültige Anfrage.", "")
		return
	}
	title := strings.TrimSpace(r.FormValue("title"))
	if title == "" {
		u.renderMeasure(w, r, user, project, true, measure, "Titel ist erforderlich.", "")
		return
	}
	status := strings.TrimSpace(r.FormValue("status"))
	if !validMeasureStatus(status) {
		u.renderMeasure(w, r, user, project, true, measure, "Ungültiger Maßnahmenstatus.", "")
		return
	}
	version, _ := strconv.Atoi(strings.TrimSpace(r.FormValue("version")))
	updated, err := u.store.UpdateMeasure(r.Context(), domain.Measure{
		ID:          measure.ID,
		Title:       title,
		Description: strings.TrimSpace(r.FormValue("description")),
		Responsible: strings.TrimSpace(r.FormValue("responsible")),
		DueDate:     parseDueDate(r.FormValue("dueDate")),
		Status:      status,
		Version:     version,
	})
	if err != nil {
		if errors.Is(err, repository.ErrVersionConflict) {
			u.renderMeasure(w, r, user, project, true, updated,
				"Die Maßnahme wurde inzwischen geändert. Das Formular zeigt die aktuelle Server-Version.", "")
			return
		}
		u.renderMeasure(w, r, user, project, true, measure, "Maßnahme konnte nicht gespeichert werden.", "")
		return
	}
	http.Redirect(w, r, u.href(fmt.Sprintf("/projects/%d/measures/%d?saved=1", project.ID, measure.ID)), http.StatusSeeOther)
}

func (u *webUI) measureDelete(w http.ResponseWriter, r *http.Request) {
	_, project, _, ok := u.projectAccess(w, r, "editor")
	if !ok {
		return
	}
	measure, ok := u.loadProjectMeasure(w, r, project)
	if !ok {
		return
	}
	if err := u.store.DeleteMeasure(r.Context(), measure.ID); err != nil {
		http.Error(w, "Maßnahme konnte nicht gelöscht werden.", http.StatusInternalServerError)
		return
	}
	http.Redirect(w, r, u.assessmentURL(project.ID, measure.TargetObjectID, measure.RequirementID, "deleted"), http.StatusSeeOther)
}

func (u *webUI) loadProjectMeasure(w http.ResponseWriter, r *http.Request, project domain.Project) (domain.Measure, bool) {
	measureID, err := strconv.ParseInt(chi.URLParam(r, "measureID"), 10, 64)
	if err != nil || measureID <= 0 {
		http.NotFound(w, r)
		return domain.Measure{}, false
	}
	measure, err := u.store.GetMeasure(r.Context(), measureID)
	if err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			http.NotFound(w, r)
			return domain.Measure{}, false
		}
		http.Error(w, "Maßnahme konnte nicht geladen werden.", http.StatusInternalServerError)
		return domain.Measure{}, false
	}
	if measure.ProjectID != project.ID {
		http.NotFound(w, r)
		return domain.Measure{}, false
	}
	return measure, true
}

func (u *webUI) renderMeasure(w http.ResponseWriter, r *http.Request, user *auth.Claims, project domain.Project, canEdit bool, measure domain.Measure, errMsg, notice string) {
	u.render(w, r, "measure", webPage{
		DisplayName:     user.DisplayName,
		CanEdit:         canEdit,
		Project:         project,
		Measure:         measure,
		MeasureStatuses: webMeasureStatuses,
		Error:           errMsg,
		Notice:          notice,
	})
}

func (u *webUI) assessmentURL(projectID, targetID, requirementID int64, saved string) string {
	path := fmt.Sprintf("/projects/%d/targets/%d/requirements/%d", projectID, targetID, requirementID)
	if saved != "" {
		path += "?saved=" + saved
	}
	return u.href(path)
}

func (u *webUI) assessmentGet(w http.ResponseWriter, r *http.Request) {
	user, project, role, ok := u.projectAccess(w, r, "viewer")
	if !ok {
		return
	}
	ctx, ok := u.loadAssessmentPage(w, r, project)
	if !ok {
		return
	}
	notice := ""
	switch r.URL.Query().Get("saved") {
	case "1":
		notice = "Bewertung gespeichert."
	case "measure":
		notice = "Maßnahme gespeichert."
	case "created":
		notice = "Maßnahme angelegt."
	case "deleted":
		notice = "Maßnahme gelöscht."
	case "deviation":
		notice = "Abweichungstext gespeichert."
	}
	u.renderAssessment(w, r, user, project, roleCanEdit(role), ctx, "", notice)
}

func (u *webUI) assessmentSave(w http.ResponseWriter, r *http.Request) {
	user, project, _, ok := u.projectAccess(w, r, "editor")
	if !ok {
		return
	}
	ctx, ok := u.loadAssessmentPage(w, r, project)
	if !ok {
		return
	}
	if ctx.Inherited {
		u.renderAssessment(w, r, user, project, true, ctx, "Geerbte Bewertungen werden am übergeordneten Zielobjekt geändert.", "")
		return
	}
	if err := r.ParseForm(); err != nil {
		u.renderAssessment(w, r, user, project, true, ctx, "Ungültige Anfrage.", "")
		return
	}
	status := strings.TrimSpace(r.FormValue("status"))
	if !validAssessmentStatus(status) {
		u.renderAssessment(w, r, user, project, true, ctx, "Ungültiger Bewertungsstatus.", "")
		return
	}
	version, _ := strconv.Atoi(strings.TrimSpace(r.FormValue("version")))
	saved, err := u.store.SaveAssessment(r.Context(), domain.RequirementAssessment{
		ProjectID:      project.ID,
		TargetObjectID: ctx.Target.ID,
		RequirementID:  ctx.Requirement.ID,
		Status:         status,
		Note:           strings.TrimSpace(r.FormValue("note")),
		Responsible:    strings.TrimSpace(r.FormValue("responsible")),
		DueDate:        parseDueDate(r.FormValue("dueDate")),
		Version:        version,
	})
	if err != nil {
		if errors.Is(err, repository.ErrVersionConflict) {
			ctx.Assessment = saved
			u.renderAssessment(w, r, user, project, true, ctx,
				"Ein anderer Benutzer hat die Bewertung geändert. Das Formular zeigt die aktuelle Server-Version.", "")
			return
		}
		u.renderAssessment(w, r, user, project, true, ctx, "Bewertung konnte nicht gespeichert werden.", "")
		return
	}
	http.Redirect(w, r, u.href(fmt.Sprintf(
		"/projects/%d/targets/%d/requirements/%d?saved=1",
		project.ID, ctx.Target.ID, ctx.Requirement.ID,
	)), http.StatusSeeOther)
}

type webAssessmentContext struct {
	Target        domain.TargetObject
	Requirement   domain.Requirement
	Baustein      domain.Baustein
	Assessment    domain.RequirementAssessment
	Measures      []webMeasureRow
	Inherited     bool
	InheritedFrom string
	Deviation     string
}

func (u *webUI) loadAssessmentPage(w http.ResponseWriter, r *http.Request, project domain.Project) (webAssessmentContext, bool) {
	targetID, err := strconv.ParseInt(chi.URLParam(r, "targetObjectID"), 10, 64)
	if err != nil || targetID <= 0 {
		http.NotFound(w, r)
		return webAssessmentContext{}, false
	}
	requirementID, err := strconv.ParseInt(chi.URLParam(r, "requirementID"), 10, 64)
	if err != nil || requirementID <= 0 {
		http.NotFound(w, r)
		return webAssessmentContext{}, false
	}
	target, err := u.store.GetTargetObject(r.Context(), targetID)
	if err != nil || target.ProjectID != project.ID {
		http.NotFound(w, r)
		return webAssessmentContext{}, false
	}
	requirement, err := u.store.GetRequirement(r.Context(), requirementID)
	if err != nil {
		http.NotFound(w, r)
		return webAssessmentContext{}, false
	}
	baustein, err := u.store.GetBaustein(r.Context(), requirement.BausteinID)
	if err != nil && !errors.Is(err, repository.ErrNotFound) {
		http.Error(w, "Baustein konnte nicht geladen werden.", http.StatusInternalServerError)
		return webAssessmentContext{}, false
	}
	assessTargetID := target.ID
	inherited := false
	inheritedFrom := ""
	deviation := ""
	objects, err := u.store.ListTargetObjects(r.Context(), project.ID)
	if err != nil {
		http.Error(w, "Zielobjekte konnten nicht geladen werden.", http.StatusInternalServerError)
		return webAssessmentContext{}, false
	}
	_, inheritedMap, err := u.inheritedMaps(r, project.ID, objects, target)
	if err != nil {
		http.Error(w, "Anwendbarkeit konnte nicht geladen werden.", http.StatusInternalServerError)
		return webAssessmentContext{}, false
	}
	if item, ok := inheritedMap[baustein.ID]; ok {
		inherited = true
		inheritedFrom = item.SourceCaption
		assessTargetID = item.SourceTargetID
		deviation, err = u.store.GetDeviation(r.Context(), project.ID, target.ID, baustein.ID)
		if err != nil {
			http.Error(w, "Abweichungstext konnte nicht geladen werden.", http.StatusInternalServerError)
			return webAssessmentContext{}, false
		}
	}
	assessment, err := u.store.GetAssessment(r.Context(), project.ID, assessTargetID, requirement.ID)
	if err != nil {
		http.Error(w, "Bewertung konnte nicht geladen werden.", http.StatusInternalServerError)
		return webAssessmentContext{}, false
	}
	items, err := u.store.ListMeasures(r.Context(), project.ID, assessTargetID, requirement.ID)
	if err != nil {
		http.Error(w, "Maßnahmen konnten nicht geladen werden.", http.StatusInternalServerError)
		return webAssessmentContext{}, false
	}
	return webAssessmentContext{
		Target:        target,
		Requirement:   requirement,
		Baustein:      baustein,
		Assessment:    assessment,
		Measures:      toMeasureRows(items),
		Inherited:     inherited,
		InheritedFrom: inheritedFrom,
		Deviation:     deviation,
	}, true
}

func (u *webUI) renderAssessment(w http.ResponseWriter, r *http.Request, user *auth.Claims, project domain.Project, canEdit bool, ctx webAssessmentContext, errMsg, notice string) {
	u.render(w, r, "assessment", webPage{
		DisplayName:        user.DisplayName,
		CanEdit:            canEdit,
		Project:            project,
		Error:              errMsg,
		Notice:             notice,
		Assessment:         ctx.Assessment,
		AssessmentStatuses: webAssessmentStatuses,
		Requirement:        ctx.Requirement,
		Baustein:           ctx.Baustein,
		Target:             ctx.Target,
		RelatedMeasures:    ctx.Measures,
		MeasureStatuses:    webMeasureStatuses,
		Inherited:          ctx.Inherited,
		InheritedFrom:      ctx.InheritedFrom,
		Deviation:          ctx.Deviation,
	})
}

func displayName(user *auth.Claims) string {
	if user == nil {
		return ""
	}
	return user.DisplayName
}

func (u *webUI) projectAccess(w http.ResponseWriter, r *http.Request, minRole string) (*auth.Claims, domain.Project, string, bool) {
	return u.loadProjectAccess(w, r, minRole, false)
}

func (u *webUI) projectMemberAccess(w http.ResponseWriter, r *http.Request, minRole string) (*auth.Claims, domain.Project, string, bool) {
	return u.loadProjectAccess(w, r, minRole, true)
}

func (u *webUI) loadProjectAccess(w http.ResponseWriter, r *http.Request, minRole string, membersOnly bool) (*auth.Claims, domain.Project, string, bool) {
	user, loggedIn := auth.UserFromContext(r.Context())
	needsLogin := membersOnly || domain.RoleRank(minRole) > domain.RoleRank(domain.RoleViewer)
	if needsLogin && !loggedIn {
		u.redirectLogin(w, r)
		return nil, domain.Project{}, "", false
	}
	if u.store == nil {
		http.NotFound(w, r)
		return nil, domain.Project{}, "", false
	}
	projectID, err := strconv.ParseInt(chi.URLParam(r, "projectID"), 10, 64)
	if err != nil || projectID <= 0 {
		http.NotFound(w, r)
		return nil, domain.Project{}, "", false
	}
	project, role, err := u.store.LoadAccessibleProject(r.Context(), projectID, user, minRole, membersOnly)
	if err != nil {
		if errors.Is(err, repository.ErrForbidden) && !loggedIn {
			u.redirectLogin(w, r)
			return nil, domain.Project{}, "", false
		}
		u.writeAccessError(w, err)
		return nil, domain.Project{}, "", false
	}
	if user == nil {
		user = &auth.Claims{}
	}
	return user, project, role, true
}

func (u *webUI) writeAccessError(w http.ResponseWriter, err error) {
	switch {
	case errors.Is(err, repository.ErrNotFound):
		http.Error(w, "Projekt nicht gefunden.", http.StatusNotFound)
	case errors.Is(err, repository.ErrForbidden):
		http.Error(w, "Kein Zugriff auf dieses Projekt.", http.StatusForbidden)
	default:
		http.Error(w, "Zugriffsprüfung fehlgeschlagen.", http.StatusInternalServerError)
	}
}

func (u *webUI) render(w http.ResponseWriter, r *http.Request, name string, data webPage) {
	if r != nil {
		if data.CSRFToken == "" {
			data.CSRFToken = csrfTokenFromContext(r.Context())
		}
		if user, ok := auth.UserFromContext(r.Context()); ok {
			data.LoggedIn = true
			if data.DisplayName == "" {
				data.DisplayName = user.DisplayName
			}
			if u.store != nil {
				admin, err := u.store.IsAdmin(r.Context(), user.UserID)
				if err == nil {
					data.IsAdmin = admin
				}
			}
		}
	}
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.Header().Set("Cache-Control", "no-store")
	if err := u.tmpl.ExecuteTemplate(w, name, data); err != nil {
		http.Error(w, "template error", http.StatusInternalServerError)
	}
}

func filterReportRows(rows []domain.ReportRow, query, status string) []domain.ReportRow {
	needle := strings.ToLower(query)
	out := make([]domain.ReportRow, 0, len(rows))
	for _, row := range rows {
		if status == "Überfällig" && !row.Overdue {
			continue
		}
		if status != "" && status != "Alle" && status != "Überfällig" && row.Status != status {
			continue
		}
		if needle != "" {
			hay := strings.ToLower(strings.Join([]string{
				row.TargetObjectName,
				row.BausteinExternalID,
				row.BausteinTitle,
				row.RequirementExternalID,
				row.RequirementTitle,
				row.Responsible,
				row.Status,
			}, " "))
			if !strings.Contains(hay, needle) {
				continue
			}
		}
		out = append(out, row)
	}
	return out
}

func filterMeasures(items []domain.Measure, query, status string, hideDone bool) []webMeasureRow {
	needle := strings.ToLower(query)
	out := make([]webMeasureRow, 0, len(items))
	for _, item := range items {
		if hideDone && item.Status == "Erledigt" {
			continue
		}
		if status != "" && status != "Alle" && item.Status != status {
			continue
		}
		if needle != "" {
			hay := strings.ToLower(strings.Join([]string{
				item.Title,
				item.Description,
				item.Responsible,
				item.Status,
			}, " "))
			if !strings.Contains(hay, needle) {
				continue
			}
		}
		out = append(out, toMeasureRow(item))
	}
	return out
}

func toMeasureRows(items []domain.Measure) []webMeasureRow {
	out := make([]webMeasureRow, 0, len(items))
	for _, item := range items {
		out = append(out, toMeasureRow(item))
	}
	return out
}

func toMeasureRow(item domain.Measure) webMeasureRow {
	overdue := false
	if item.Status != "Erledigt" && item.DueDate != nil && *item.DueDate != "" {
		overdue = *item.DueDate < time.Now().Format("2006-01-02")
	}
	return webMeasureRow{Measure: item, Overdue: overdue}
}

func validMeasureStatus(status string) bool {
	switch status {
	case "Offen", "In Bearbeitung", "Erledigt":
		return true
	default:
		return false
	}
}

func validAssessmentStatus(status string) bool {
	switch status {
	case "Offen", "Teilweise", "Erfüllt", "Entfällt":
		return true
	default:
		return false
	}
}

func parseDueDate(raw string) *string {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return nil
	}
	return &raw
}

func roleCanEdit(role string) bool {
	return role == "owner" || role == "editor"
}

func roleCanOwn(role string) bool {
	return role == "owner"
}

func validMemberRole(role string) bool {
	switch role {
	case "owner", "editor", "viewer":
		return true
	default:
		return false
	}
}

func roleLabel(role string) string {
	switch role {
	case "owner":
		return "Besitzer"
	case "editor":
		return "Bearbeiter"
	case "viewer":
		return "Leser"
	default:
		if role == "" {
			return "—"
		}
		return role
	}
}

func formatWebDate(t time.Time) string {
	if t.IsZero() {
		return "—"
	}
	return t.Local().Format("02.01.2006")
}

func formatDueDate(raw *string) string {
	if raw == nil || *raw == "" {
		return "—"
	}
	if parsed, err := time.Parse("2006-01-02", *raw); err == nil {
		return parsed.Format("02.01.2006")
	}
	return *raw
}

func dueValue(raw *string) string {
	if raw == nil {
		return ""
	}
	return *raw
}

func padLeft(depth int) string {
	if depth <= 0 {
		return "0px"
	}
	return fmt.Sprintf("%dpx", depth*18)
}

func statusClass(status string, overdue bool) string {
	if overdue {
		return "badge badge-warn"
	}
	switch status {
	case "Erfüllt", "Erledigt", "Benötigt":
		return "badge badge-ok"
	case "Teilweise", "In Bearbeitung", "Möglicherweise":
		return "badge badge-mid"
	case "Entfällt", "Nicht relevant":
		return "badge badge-mute"
	default:
		return "badge"
	}
}

func reqHTML(text string) template.HTML {
	return template.HTML(catalog.FormatRequirementHTML(text))
}
