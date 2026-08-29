package httpx

import (
	"fmt"
	"net/http"
	"net/url"
	"os"
	"strconv"
	"strings"
	"unicode/utf8"

	"github.com/Target42/BSI/isms-server/internal/auth"
	"github.com/Target42/BSI/isms-server/internal/catalog"
	"github.com/Target42/BSI/isms-server/internal/domain"
	"github.com/Target42/BSI/isms-server/internal/service"
	"github.com/go-chi/chi/v5"
)

func (u *webUI) catalogGet(w http.ResponseWriter, r *http.Request) {
	user, ok := auth.UserFromContext(r.Context())
	if !ok {
		http.Redirect(w, r, u.href("/login"), http.StatusSeeOther)
		return
	}
	u.renderCatalog(w, r, user, "")
}

func (u *webUI) renderCatalog(w http.ResponseWriter, r *http.Request, user *auth.Claims, errMsg string) {
	versions, err := u.store.ListCatalogVersions(r.Context())
	if err != nil {
		http.Error(w, "Katalogversionen konnten nicht geladen werden.", http.StatusInternalServerError)
		return
	}
	version := strings.TrimSpace(r.URL.Query().Get("version"))
	if version == "" && len(versions) > 0 {
		version = versions[0]
	}
	if version == "" {
		version = "2023"
	}
	if len(versions) == 0 {
		versions = []string{version}
	}
	bausteine, err := u.store.ListBausteine(r.Context(), webCatalogStandard, version)
	if err != nil {
		http.Error(w, "Katalog konnte nicht geladen werden.", http.StatusInternalServerError)
		return
	}
	query := strings.TrimSpace(r.URL.Query().Get("q"))
	page := webPage{
		DisplayName:     user.DisplayName,
		CatalogVersions: versions,
		SelectedVersion: version,
		Query:           query,
		Bausteine:       bausteine,
		BausteinCount:   len(bausteine),
		Error:           errMsg,
	}
	if n := r.URL.Query().Get("imported"); n == "1" && errMsg == "" {
		page.Notice = fmt.Sprintf("Katalog %s eingespielt (%s Bausteine, %s Anforderungen).",
			r.URL.Query().Get("version"),
			r.URL.Query().Get("bausteine"),
			r.URL.Query().Get("requirements"))
	}
	if query != "" && utf8.RuneCountInString(query) < 2 {
		page.Error = "Bitte mindestens zwei Zeichen suchen."
		page.CatalogGroups = groupBausteine(bausteine)
	} else if query != "" {
		requirements, err := u.store.ListRequirementsByCatalog(r.Context(), webCatalogStandard, version)
		if err != nil {
			http.Error(w, "Anforderungen konnten nicht geladen werden.", http.StatusInternalServerError)
			return
		}
		hits, truncated := service.SearchCatalog(bausteine, requirements, query, service.CatalogSearchLimit)
		page.CatalogHits = hits
		page.CatalogTruncated = truncated
		page.CatalogGroups = groupCatalogHits(hits)
		page.Bausteine = nil
		page.RequirementCount = len(requirements)
	} else {
		page.CatalogGroups = groupBausteine(bausteine)
	}
	u.render(w, r, "catalog", page)
}

func groupBausteine(items []domain.Baustein) []webCatalogGroup {
	order, buckets := []string{}, map[string][]domain.Baustein{}
	for _, item := range items {
		name := item.GroupName
		if name == "" {
			name = "Sonstige"
		}
		if _, seen := buckets[name]; !seen {
			order = append(order, name)
		}
		buckets[name] = append(buckets[name], item)
	}
	out := make([]webCatalogGroup, 0, len(order))
	for _, name := range order {
		out = append(out, webCatalogGroup{Name: name, Bausteine: buckets[name]})
	}
	return out
}

func groupCatalogHits(hits []service.CatalogHit) []webCatalogGroup {
	order, buckets := []string{}, map[string][]service.CatalogHit{}
	for _, hit := range hits {
		name := hit.GroupName
		if name == "" {
			name = "Sonstige"
		}
		if _, seen := buckets[name]; !seen {
			order = append(order, name)
		}
		buckets[name] = append(buckets[name], hit)
	}
	out := make([]webCatalogGroup, 0, len(order))
	for _, name := range order {
		out = append(out, webCatalogGroup{Name: name, Hits: buckets[name]})
	}
	return out
}

func (u *webUI) catalogBausteinGet(w http.ResponseWriter, r *http.Request) {
	user, ok := auth.UserFromContext(r.Context())
	if !ok {
		http.Redirect(w, r, u.href("/login"), http.StatusSeeOther)
		return
	}
	bausteinID, err := strconv.ParseInt(chi.URLParam(r, "bausteinID"), 10, 64)
	if err != nil || bausteinID <= 0 {
		http.Error(w, "Ungültiger Baustein.", http.StatusBadRequest)
		return
	}
	baustein, err := u.store.GetBaustein(r.Context(), bausteinID)
	if err != nil {
		http.Error(w, "Baustein nicht gefunden.", http.StatusNotFound)
		return
	}
	items, err := u.store.ListRequirements(r.Context(), baustein.ID)
	if err != nil {
		http.Error(w, "Anforderungen konnten nicht geladen werden.", http.StatusInternalServerError)
		return
	}
	query := strings.TrimSpace(r.URL.Query().Get("q"))
	highlight, _ := strconv.ParseInt(r.URL.Query().Get("req"), 10, 64)
	needle := strings.ToLower(query)
	visible := make([]domain.Requirement, 0, len(items))
	var selected domain.Requirement
	for _, item := range items {
		if needle != "" {
			hay := strings.ToLower(strings.Join([]string{
				item.ExternalID, item.Title, item.Text, item.ResponsibleRole, item.Level,
			}, " "))
			if !strings.Contains(hay, needle) {
				continue
			}
		}
		visible = append(visible, item)
		if item.ID == highlight {
			selected = item
		}
	}
	if selected.ID == 0 && highlight > 0 {
		for _, item := range items {
			if item.ID == highlight {
				selected = item
				break
			}
		}
	}
	if selected.ID == 0 && len(visible) > 0 {
		selected = visible[0]
		highlight = selected.ID
	}
	u.render(w, r, "baustein", webPage{
		DisplayName:     user.DisplayName,
		Baustein:        baustein,
		SelectedVersion: baustein.CatalogVersion,
		Query:           query,
		Requirements:    visible,
		Requirement:     selected,
		HighlightID:     highlight,
	})
}

func (u *webUI) catalogImport(w http.ResponseWriter, r *http.Request) {
	user, ok := u.requireAdmin(w, r)
	if !ok {
		return
	}
	r.Body = http.MaxBytesReader(w, r.Body, maxCatalogUploadBytes)
	tmpPath, _, err := saveCatalogUpload(r)
	if err != nil {
		u.renderCatalog(w, r, user, "XML-Datei konnte nicht gelesen werden.")
		return
	}
	defer os.Remove(tmpPath)

	result := catalog.ImportFromFile(tmpPath)
	if !result.Success {
		msg := "Katalog konnte nicht gelesen werden."
		if result.ErrorMessage != "" {
			msg = result.ErrorMessage
		}
		u.renderCatalog(w, r, user, msg)
		return
	}
	if err := u.store.ReplaceGrundschutzCatalog(r.Context(), result); err != nil {
		u.renderCatalog(w, r, user, "Katalog konnte nicht gespeichert werden.")
		return
	}
	http.Redirect(w, r, u.href(fmt.Sprintf(
		"/catalog?imported=1&version=%s&bausteine=%d&requirements=%d",
		url.QueryEscape(result.CatalogVersion), len(result.Bausteine), len(result.Requirements),
	)), http.StatusSeeOther)
}
