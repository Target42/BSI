package httpx

import (
	"fmt"
	"net/http"
	"strconv"

	"github.com/Target42/BSI/isms-server/internal/auth"
	"github.com/Target42/BSI/isms-server/internal/domain"
	"github.com/Target42/BSI/isms-server/internal/service"
)

func (u *webUI) recommendationsGet(w http.ResponseWriter, r *http.Request) {
	user, project, role, ok := u.projectAccess(w, r, "viewer")
	if !ok {
		return
	}
	target, ok := u.loadProjectTarget(w, r, project)
	if !ok {
		return
	}
	u.renderRecommendations(w, r, user, project, roleCanEdit(role), target, "")
}

func (u *webUI) renderRecommendations(w http.ResponseWriter, r *http.Request, user *auth.Claims, project domain.Project, canEdit bool, target domain.TargetObject, errMsg string) {
	bausteine, err := u.store.ListBausteine(r.Context(), webCatalogStandard, project.CatalogVersion)
	if err != nil {
		http.Error(w, "Katalog konnte nicht geladen werden.", http.StatusInternalServerError)
		return
	}
	applied, err := u.store.ApplicabilityMap(r.Context(), project.ID, target.ID)
	if err != nil {
		http.Error(w, "Anwendbarkeit konnte nicht geladen werden.", http.StatusInternalServerError)
		return
	}
	recs := service.BuildRecommendations(bausteine, target)
	rows := make([]webRecommendation, 0, len(recs))
	for _, rec := range recs {
		current := applied[rec.BausteinID]
		locked := current != ""
		rows = append(rows, webRecommendation{
			Recommendation: rec,
			Current:        current,
			Locked:         locked,
			Selected:       !locked && rec.Tier == service.TierCore,
		})
	}
	notice := ""
	if errMsg == "" {
		if n := r.URL.Query().Get("saved"); n != "" {
			if n == "1" {
				notice = "1 Baustein-Empfehlung übernommen."
			} else {
				notice = fmt.Sprintf("%s Baustein-Empfehlungen übernommen.", n)
			}
		}
	}
	u.render(w, r, "recommendations", webPage{
		DisplayName:     user.DisplayName,
		CanEdit:         canEdit,
		Project:         project,
		Target:          target,
		Hint:            service.RecommendationHint(target),
		Recommendations: rows,
		Error:           errMsg,
		Notice:          notice,
	})
}

func (u *webUI) recommendationsApply(w http.ResponseWriter, r *http.Request) {
	user, project, _, ok := u.projectAccess(w, r, "editor")
	if !ok {
		return
	}
	target, ok := u.loadProjectTarget(w, r, project)
	if !ok {
		return
	}
	if err := r.ParseForm(); err != nil {
		u.renderRecommendations(w, r, user, project, true, target, "Ungültige Anfrage.")
		return
	}
	bausteine, err := u.store.ListBausteine(r.Context(), webCatalogStandard, project.CatalogVersion)
	if err != nil {
		u.renderRecommendations(w, r, user, project, true, target, "Katalog konnte nicht geladen werden.")
		return
	}
	applied, err := u.store.ApplicabilityMap(r.Context(), project.ID, target.ID)
	if err != nil {
		u.renderRecommendations(w, r, user, project, true, target, "Anwendbarkeit konnte nicht geladen werden.")
		return
	}
	suggested := map[int64]string{}
	for _, rec := range service.BuildRecommendations(bausteine, target) {
		suggested[rec.BausteinID] = rec.SuggestedStatus
	}
	count := 0
	for _, raw := range r.Form["apply"] {
		bausteinID, err := strconv.ParseInt(raw, 10, 64)
		if err != nil || bausteinID <= 0 {
			continue
		}
		if applied[bausteinID] != "" {
			continue
		}
		status := suggested[bausteinID]
		if status == "" {
			continue
		}
		if _, err := u.store.SaveApplicability(r.Context(), domain.BausteinApplicability{
			ProjectID:      project.ID,
			TargetObjectID: target.ID,
			BausteinID:     bausteinID,
			Status:         status,
		}); err != nil {
			u.renderRecommendations(w, r, user, project, true, target, "Empfehlungen konnten nicht gespeichert werden.")
			return
		}
		count++
	}
	http.Redirect(w, r, u.href(fmt.Sprintf("/projects/%d/targets/%d/recommendations?saved=%d", project.ID, target.ID, count)), http.StatusSeeOther)
}
