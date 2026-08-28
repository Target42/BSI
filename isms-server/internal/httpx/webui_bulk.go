package httpx

import (
	"fmt"
	"net/http"
	"net/url"
	"strconv"
	"strings"

	"github.com/Target42/BSI/isms-server/internal/domain"
	"github.com/Target42/BSI/isms-server/internal/service"
)

func matchApplicabilityFilter(filter, display string, inherited bool) bool {
	switch filter {
	case "", "Alle":
		return true
	case "Gesetzt":
		return display != ""
	case "Ungesetzt":
		return display == ""
	case "Geerbt":
		return inherited
	default:
		return display == filter
	}
}

func bulkRequirementIDs(
	items []domain.Requirement,
	need string,
	assessments map[int64]domain.RequirementAssessment,
	onlyOpen bool,
	already string,
) []int64 {
	out := make([]int64, 0, len(items))
	for _, req := range items {
		if req.Withdrawn {
			continue
		}
		if !domain.RequirementLevelApplies(req.Level, need) {
			continue
		}
		status := assessments[req.ID].Status
		if status == "" {
			status = "Offen"
		}
		if onlyOpen && status != "Offen" {
			continue
		}
		if already != "" && status == already {
			continue
		}
		out = append(out, req.ID)
	}
	return out
}

func germanCount(n int, singular, plural string) string {
	if n == 1 {
		return "1 " + singular
	}
	return fmt.Sprintf("%d %s", n, plural)
}

func (u *webUI) applicabilityBulk(w http.ResponseWriter, r *http.Request) {
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
	status := strings.TrimSpace(r.FormValue("status"))
	if !validApplicabilityStatus(status) || status == "" {
		u.renderApplicability(w, r, user, project, true, target, "Bitte einen Anwendbarkeitsstatus wählen.")
		return
	}
	if status == "Ungesetzt" {
		status = ""
	}

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
	query := strings.TrimSpace(r.FormValue("q"))
	filter := r.FormValue("filter")
	if filter == "" {
		filter = "Alle"
	}
	highlight := r.FormValue("highlight") == "1"
	needle := strings.ToLower(query)
	ids := make([]int64, 0, 32)
	for _, b := range bausteine {
		current := own[b.ID]
		item, isInherited := inherited[b.ID]
		display := current
		if display == "" && isInherited {
			display = item.Status
		}
		if !matchApplicabilityFilter(filter, display, isInherited) {
			continue
		}
		if needle != "" {
			hay := strings.ToLower(strings.Join([]string{b.ExternalID, b.Title, b.GroupName}, " "))
			if !strings.Contains(hay, needle) {
				continue
			}
		}
		ids = append(ids, b.ID)
	}
	if len(ids) == 0 {
		u.renderApplicability(w, r, user, project, true, target, "Keine Bausteine für diesen Filter.")
		return
	}
	for _, id := range ids {
		if status == "" {
			if err := u.store.DeleteApplicability(r.Context(), project.ID, target.ID, id); err != nil {
				u.renderApplicability(w, r, user, project, true, target, "Anwendbarkeit konnte nicht gelöscht werden.")
				return
			}
			continue
		}
		if _, err := u.store.SaveApplicability(r.Context(), domain.BausteinApplicability{
			ProjectID:      project.ID,
			TargetObjectID: target.ID,
			BausteinID:     id,
			Status:         status,
		}); err != nil {
			u.renderApplicability(w, r, user, project, true, target, "Anwendbarkeit konnte nicht gespeichert werden.")
			return
		}
	}
	to := status
	if to == "" {
		to = "ungesetzt"
	}
	http.Redirect(w, r, u.applicabilityURL(project.ID, target.ID, query, filter, highlight, "bulk", strconv.Itoa(len(ids)), to), http.StatusSeeOther)
}

func (u *webUI) assessmentsBulk(w http.ResponseWriter, r *http.Request) {
	user, project, _, ok := u.projectAccess(w, r, "editor")
	if !ok {
		return
	}
	target, ok := u.loadProjectTarget(w, r, project)
	if !ok {
		return
	}
	if err := r.ParseForm(); err != nil {
		u.renderWorkplace(w, r, user, project, true, target, "Ungültige Anfrage.")
		return
	}
	status := strings.TrimSpace(r.FormValue("status"))
	if !validAssessmentStatus(status) {
		u.renderWorkplace(w, r, user, project, true, target, "Bitte einen Bewertungsstatus wählen.")
		return
	}
	bausteinID, err := strconv.ParseInt(r.FormValue("bausteinID"), 10, 64)
	if err != nil || bausteinID <= 0 {
		u.renderWorkplace(w, r, user, project, true, target, "Ungültiger Baustein.")
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
	if _, ok := inherited[bausteinID]; ok {
		u.renderWorkplace(w, r, user, project, true, target, "Geerbte Bewertungen werden am übergeordneten Zielobjekt geändert.")
		return
	}
	merged := service.MergeApplicability(own, inherited)
	if !domain.ApplicabilityCountsForReport(merged[bausteinID]) {
		u.renderWorkplace(w, r, user, project, true, target, "Der Baustein ist hier nicht anwendbar.")
		return
	}
	requirements, err := u.store.ListRequirements(r.Context(), bausteinID)
	if err != nil {
		http.Error(w, "Anforderungen konnten nicht geladen werden.", http.StatusInternalServerError)
		return
	}
	items, err := u.store.ListAssessments(r.Context(), project.ID, target.ID)
	if err != nil {
		http.Error(w, "Bewertungen konnten nicht geladen werden.", http.StatusInternalServerError)
		return
	}
	assessments := make(map[int64]domain.RequirementAssessment, len(items))
	for _, item := range items {
		assessments[item.RequirementID] = item
	}
	onlyOpen := r.FormValue("onlyOpen") == "1"
	ids := bulkRequirementIDs(requirements, target.ProtectionNeed, assessments, onlyOpen, status)
	if len(ids) == 0 {
		u.renderWorkplace(w, r, user, project, true, target, "Keine passenden Anforderungen für diesen Massenstatus.")
		return
	}
	for _, id := range ids {
		current := assessments[id]
		if _, err := u.store.SaveAssessment(r.Context(), domain.RequirementAssessment{
			ProjectID:      project.ID,
			TargetObjectID: target.ID,
			RequirementID:  id,
			Status:         status,
			Note:           current.Note,
			Responsible:    current.Responsible,
			DueDate:        current.DueDate,
			Version:        0,
		}); err != nil {
			u.renderWorkplace(w, r, user, project, true, target, "Bewertungen konnten nicht gespeichert werden.")
			return
		}
	}
	query := strings.TrimSpace(r.FormValue("q"))
	filter := r.FormValue("filter")
	highlight := r.FormValue("highlight") != "0"
	path := u.workplaceURL(project.ID, target.ID, bausteinID, query, filter, highlight)
	sep := "?"
	if strings.Contains(path, "?") {
		sep = "&"
	}
	http.Redirect(w, r, path+sep+"saved=bulk&n="+strconv.Itoa(len(ids))+"&to="+url.QueryEscape(status), http.StatusSeeOther)
}

func (u *webUI) applicabilityURL(projectID, targetID int64, query, filter string, highlight bool, saved, n, to string) string {
	path := fmt.Sprintf("/projects/%d/targets/%d/applicability", projectID, targetID)
	values := url.Values{}
	if query != "" {
		values.Set("q", query)
	}
	if filter != "" && filter != "Alle" {
		values.Set("status", filter)
	}
	if highlight {
		values.Set("highlight", "1")
	}
	if saved != "" {
		values.Set("saved", saved)
	}
	if n != "" {
		values.Set("n", n)
	}
	if to != "" {
		values.Set("to", to)
	}
	if encoded := values.Encode(); encoded != "" {
		path += "?" + encoded
	}
	return u.href(path)
}
