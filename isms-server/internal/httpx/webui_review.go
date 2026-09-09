package httpx

import (
	"net/http"
	"strconv"
	"strings"
)

func (u *webUI) reviewApply(w http.ResponseWriter, r *http.Request) {
	user, project, role, ok := u.projectMemberAccess(w, r, "viewer")
	if !ok {
		return
	}
	target, ok := u.loadProjectTarget(w, r, project)
	if !ok {
		return
	}
	if err := r.ParseForm(); err != nil {
		u.renderWorkplace(w, r, user, project, role, target, "Ungültige Anfrage.")
		return
	}
	bausteinID, err := strconv.ParseInt(r.FormValue("bausteinID"), 10, 64)
	if err != nil || bausteinID <= 0 {
		u.renderWorkplace(w, r, user, project, role, target, "Ungültiger Baustein.")
		return
	}
	action := strings.TrimSpace(r.FormValue("action"))
	note := strings.TrimSpace(r.FormValue("note"))
	requirementIDs := parseFormInt64s(r, "requirementID")
	if _, err := applyBausteinReview(r, u.store, project, role, user.UserID, target.ID, bausteinID, action, note, requirementIDs); err != nil {
		u.renderWorkplace(w, r, user, project, role, target, reviewWebError(err))
		return
	}
	query := strings.TrimSpace(r.FormValue("q"))
	filter := r.FormValue("filter")
	highlight := r.FormValue("highlight") != "0"
	path := u.workplaceURL(project.ID, target.ID, bausteinID, query, filter, highlight)
	sep := "?"
	if strings.Contains(path, "?") {
		sep = "&"
	}
	http.Redirect(w, r, path+sep+"saved="+action, http.StatusSeeOther)
}

func parseFormInt64s(r *http.Request, key string) []int64 {
	values := r.Form[key]
	out := make([]int64, 0, len(values))
	for _, raw := range values {
		id, err := strconv.ParseInt(strings.TrimSpace(raw), 10, 64)
		if err != nil || id <= 0 {
			continue
		}
		out = append(out, id)
	}
	return out
}
