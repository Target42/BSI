package httpx

import (
	"fmt"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"time"

	"github.com/Target42/BSI/isms-server/internal/auth"
	"github.com/Target42/BSI/isms-server/internal/domain"
	"github.com/Target42/BSI/isms-server/internal/service"
)

func (u *webUI) workplaceGet(w http.ResponseWriter, r *http.Request) {
	user, project, role, ok := u.projectAccess(w, r, "viewer")
	if !ok {
		return
	}
	target, ok := u.loadProjectTarget(w, r, project)
	if !ok {
		return
	}
	u.renderWorkplace(w, r, user, project, roleCanEdit(role), target, "")
}

func (u *webUI) renderWorkplace(w http.ResponseWriter, r *http.Request, user *auth.Claims, project domain.Project, canEdit bool, target domain.TargetObject, errMsg string) {
	objects, err := u.store.ListTargetObjects(r.Context(), project.ID)
	if err != nil {
		http.Error(w, "Zielobjekte konnten nicht geladen werden.", http.StatusInternalServerError)
		return
	}
	bausteine, err := u.store.ListBausteine(r.Context(), webCatalogStandard, project.CatalogVersion)
	if err != nil {
		http.Error(w, "Katalog konnte nicht geladen werden.", http.StatusInternalServerError)
		return
	}
	own, inherited, err := u.inheritedMaps(r, project.ID, objects, target)
	if err != nil {
		http.Error(w, "Anwendbarkeit konnte nicht geladen werden.", http.StatusInternalServerError)
		return
	}
	merged := service.MergeApplicability(own, inherited)
	recs := recommendationIndex(bausteine, target)
	requirements, err := u.store.ListRequirementsByCatalog(r.Context(), webCatalogStandard, project.CatalogVersion)
	if err != nil {
		http.Error(w, "Anforderungen konnten nicht geladen werden.", http.StatusInternalServerError)
		return
	}
	reqsByBaustein := map[int64][]domain.Requirement{}
	for _, req := range requirements {
		if req.Withdrawn {
			continue
		}
		reqsByBaustein[req.BausteinID] = append(reqsByBaustein[req.BausteinID], req)
	}
	assessmentsByTarget := map[int64]map[int64]domain.RequirementAssessment{}
	loadAssessments := func(targetID int64) (map[int64]domain.RequirementAssessment, error) {
		if cached, ok := assessmentsByTarget[targetID]; ok {
			return cached, nil
		}
		items, err := u.store.ListAssessments(r.Context(), project.ID, targetID)
		if err != nil {
			return nil, err
		}
		byReq := make(map[int64]domain.RequirementAssessment, len(items))
		for _, item := range items {
			byReq[item.RequirementID] = item
		}
		assessmentsByTarget[targetID] = byReq
		return byReq, nil
	}

	query := strings.TrimSpace(r.URL.Query().Get("q"))
	status := r.URL.Query().Get("status")
	if status == "" {
		status = "Anwendbar"
	}
	highlight := queryFlag(r, "highlight", true)
	selectedID, _ := strconv.ParseInt(r.URL.Query().Get("baustein"), 10, 64)
	needle := strings.ToLower(query)
	today := time.Now().Format("2006-01-02")

	rows := make([]webWorkBaustein, 0, 32)
	var selected webWorkBaustein
	for _, b := range bausteine {
		current := merged[b.ID]
		item, isInherited := inherited[b.ID]
		if !workplaceStatusMatch(status, current, isInherited) {
			continue
		}
		if needle != "" {
			hay := strings.ToLower(strings.Join([]string{b.ExternalID, b.Title, b.GroupName}, " "))
			if !strings.Contains(hay, needle) {
				continue
			}
		}
		assessTarget := target.ID
		if isInherited {
			assessTarget = item.SourceTargetID
		}
		assessments, err := loadAssessments(assessTarget)
		if err != nil {
			http.Error(w, "Bewertungen konnten nicht geladen werden.", http.StatusInternalServerError)
			return
		}
		total, open := countWorkplaceProgress(reqsByBaustein[b.ID], target.ProtectionNeed, assessments)
		rec := recs[b.ID]
		row := webWorkBaustein{
			Baustein:      b,
			Status:        current,
			Inherited:     isInherited,
			SourceCaption: item.SourceCaption,
			Recommended:   rec.BausteinID != 0,
			RecommendTier: rec.Tier,
			OpenCount:     open,
			TotalCount:    total,
		}
		rows = append(rows, row)
		if b.ID == selectedID {
			selected = row
		}
	}

	var workReqs []webWorkReq
	if selected.ID == 0 && len(rows) > 0 {
		selected = rows[0]
	}
	if selected.ID != 0 {
		assessTarget := target.ID
		if selected.Inherited {
			assessTarget = inherited[selected.ID].SourceTargetID
		}
		assessments, _ := loadAssessments(assessTarget)
		for _, req := range reqsByBaustein[selected.ID] {
			if !domain.RequirementLevelApplies(req.Level, target.ProtectionNeed) {
				continue
			}
			assessment := assessments[req.ID]
			st := assessment.Status
			if st == "" {
				st = "Offen"
			}
			overdue := assessment.DueDate != nil && *assessment.DueDate < today && st != "Erfüllt" && st != "Entfällt"
			workReqs = append(workReqs, webWorkReq{Requirement: req, Status: st, Overdue: overdue})
		}
	}

	notice := ""
	if errMsg == "" && r.URL.Query().Get("saved") == "bulk" {
		n, _ := strconv.Atoi(r.URL.Query().Get("n"))
		to := strings.TrimSpace(r.URL.Query().Get("to"))
		if to == "" {
			to = "gesetzt"
		}
		notice = germanCount(n, "Anforderung", "Anforderungen") + " auf " + to + " gesetzt."
	}

	u.render(w, r, "workplace", webPage{
		DisplayName:        user.DisplayName,
		CanEdit:            canEdit,
		Project:            project,
		Target:             target,
		Query:              query,
		StatusFilter:       status,
		StatusFilters:      []string{"Anwendbar", "Benötigt", "Möglicherweise", "Alle"},
		HighlightRecs:      highlight,
		WorkBausteine:      rows,
		WorkReqs:           workReqs,
		Baustein:           selected.Baustein,
		HighlightID:        selected.ID,
		Inherited:          selected.Inherited,
		AssessmentStatuses: webAssessmentStatuses,
		Error:              errMsg,
		Notice:             notice,
	})
}

func workplaceStatusMatch(filter, status string, inherited bool) bool {
	switch filter {
	case "Benötigt", "Möglicherweise":
		return status == filter
	case "Alle":
		return status != "" || inherited
	default: // Anwendbar
		return domain.ApplicabilityCountsForReport(status)
	}
}

func countWorkplaceProgress(items []domain.Requirement, need string, assessments map[int64]domain.RequirementAssessment) (total, open int) {
	for _, req := range items {
		if !domain.RequirementLevelApplies(req.Level, need) {
			continue
		}
		total++
		status := assessments[req.ID].Status
		if status == "" || status == "Offen" {
			open++
		}
	}
	return total, open
}

func recommendationIndex(bausteine []domain.Baustein, target domain.TargetObject) map[int64]service.Recommendation {
	out := map[int64]service.Recommendation{}
	for _, rec := range service.BuildRecommendations(bausteine, target) {
		out[rec.BausteinID] = rec
	}
	return out
}

func (u *webUI) inheritedMaps(r *http.Request, projectID int64, objects []domain.TargetObject, target domain.TargetObject) (map[int64]string, map[int64]service.InheritedBaustein, error) {
	own, err := u.store.ApplicabilityMap(r.Context(), projectID, target.ID)
	if err != nil {
		return nil, nil, err
	}
	parentMaps := map[int64]map[int64]string{}
	for _, parent := range service.AncestorChain(objects, target) {
		applied, err := u.store.ApplicabilityMap(r.Context(), projectID, parent.ID)
		if err != nil {
			return nil, nil, err
		}
		parentMaps[parent.ID] = applied
	}
	return own, service.CollectInherited(objects, target, own, parentMaps), nil
}

func (u *webUI) workplaceURL(projectID, targetID, bausteinID int64, query, status string, highlight bool) string {
	path := fmt.Sprintf("/projects/%d/targets/%d", projectID, targetID)
	values := url.Values{}
	if query != "" {
		values.Set("q", query)
	}
	if status != "" && status != "Anwendbar" {
		values.Set("status", status)
	}
	if !highlight {
		values.Set("highlight", "0")
	}
	if bausteinID > 0 {
		values.Set("baustein", strconv.FormatInt(bausteinID, 10))
	}
	if encoded := values.Encode(); encoded != "" {
		path += "?" + encoded
	}
	return u.href(path)
}

func (u *webUI) deviationSave(w http.ResponseWriter, r *http.Request) {
	_, project, _, ok := u.projectAccess(w, r, "editor")
	if !ok {
		return
	}
	target, ok := u.loadProjectTarget(w, r, project)
	if !ok {
		return
	}
	if err := r.ParseForm(); err != nil {
		http.Error(w, "Ungültige Anfrage.", http.StatusBadRequest)
		return
	}
	bausteinID, err := strconv.ParseInt(r.FormValue("bausteinID"), 10, 64)
	if err != nil || bausteinID <= 0 {
		http.Error(w, "Ungültiger Baustein.", http.StatusBadRequest)
		return
	}
	requirementID, _ := strconv.ParseInt(r.FormValue("requirementID"), 10, 64)
	objects, err := u.store.ListTargetObjects(r.Context(), project.ID)
	if err != nil {
		http.Error(w, "Zielobjekte konnten nicht geladen werden.", http.StatusInternalServerError)
		return
	}
	_, inherited, err := u.inheritedMaps(r, project.ID, objects, target)
	if err != nil {
		http.Error(w, "Anwendbarkeit konnte nicht geladen werden.", http.StatusInternalServerError)
		return
	}
	if _, ok := inherited[bausteinID]; !ok {
		http.Error(w, "Abweichungstext nur bei geerbten Bausteinen.", http.StatusConflict)
		return
	}
	if err := u.store.SaveDeviation(r.Context(), project.ID, target.ID, bausteinID, strings.TrimSpace(r.FormValue("deviation"))); err != nil {
		http.Error(w, "Abweichungstext konnte nicht gespeichert werden.", http.StatusInternalServerError)
		return
	}
	if requirementID > 0 {
		http.Redirect(w, r, u.href(fmt.Sprintf("/projects/%d/targets/%d/requirements/%d?saved=deviation", project.ID, target.ID, requirementID)), http.StatusSeeOther)
		return
	}
	http.Redirect(w, r, u.workplaceURL(project.ID, target.ID, bausteinID, "", "", true), http.StatusSeeOther)
}

func queryFlag(r *http.Request, name string, defaultOn bool) bool {
	vals := r.URL.Query()[name]
	if len(vals) == 0 {
		return defaultOn
	}
	return vals[len(vals)-1] == "1"
}
