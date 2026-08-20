package httpx

import (
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/Target42/BSI/isms-server/internal/auth"
	"github.com/go-chi/chi/v5"
)

func TestCatalogAndImportRoutesMatch(t *testing.T) {
	r := chi.NewRouter()
	r.Route("/api/v1", func(api chi.Router) {
		api.Get("/catalog/versions", func(w http.ResponseWriter, _ *http.Request) {
			_, _ = w.Write([]byte("[]"))
		})
		api.Get("/catalog/bausteine/{bausteinID}/requirements", func(w http.ResponseWriter, _ *http.Request) {
			_, _ = w.Write([]byte("reqs"))
		})
		api.Get("/catalog/{version}/bausteine", func(w http.ResponseWriter, r *http.Request) {
			_, _ = w.Write([]byte(chi.URLParam(r, "version")))
		})
		api.Post("/admin/catalog/import", func(w http.ResponseWriter, _ *http.Request) {
			_, _ = w.Write([]byte("ok"))
		})
	})

	get := func(path string) *httptest.ResponseRecorder {
		req := httptest.NewRequest(http.MethodGet, path, nil)
		rec := httptest.NewRecorder()
		r.ServeHTTP(rec, req)
		return rec
	}

	if rec := get("/api/v1/catalog/versions"); rec.Code != http.StatusOK || rec.Body.String() != "[]" {
		t.Fatalf("versions: status %d body %q", rec.Code, rec.Body.String())
	}
	if rec := get("/api/v1/catalog/2023/bausteine"); rec.Code != http.StatusOK || rec.Body.String() != "2023" {
		t.Fatalf("bausteine: status %d body %q", rec.Code, rec.Body.String())
	}
	if rec := get("/api/v1/catalog/bausteine/12/requirements"); rec.Code != http.StatusOK {
		t.Fatalf("requirements: status %d body %q", rec.Code, rec.Body.String())
	}

	req := httptest.NewRequest(http.MethodPost, "/api/v1/admin/catalog/import", nil)
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK || rec.Body.String() != "ok" {
		t.Fatalf("import: status %d body %q", rec.Code, rec.Body.String())
	}
}

func TestRouterRegistersCatalogAndImport(t *testing.T) {
	server := &Server{
		authService:       auth.NewService("test-secret", time.Hour),
		authHandler:       &AuthHandler{},
		projectHandler:    &ProjectHandler{},
		targetHandler:     &TargetObjectHandler{},
		assessmentHandler: &AssessmentHandler{},
		measureHandler:    &MeasureHandler{},
		catalogHandler:    &CatalogHandler{},
		reportHandler:     &ReportHandler{},
		adminHandler:      &AdminHandler{},
		memberHandler:     &MemberHandler{},
	}
	handler := server.Router()

	assertNot404 := func(method, path string) {
		t.Helper()
		req := httptest.NewRequest(method, path, nil)
		rec := httptest.NewRecorder()
		handler.ServeHTTP(rec, req)
		if rec.Code == http.StatusNotFound {
			t.Fatalf("%s %s was not registered (404 %q)", method, path, rec.Body.String())
		}
		if rec.Code != http.StatusUnauthorized {
			t.Fatalf("%s %s: got %d want 401, body %q", method, path, rec.Code, rec.Body.String())
		}
	}

	assertNot404(http.MethodGet, "/api/v1/catalog/versions")
	assertNot404(http.MethodGet, "/api/v1/catalog/2023/bausteine")
	assertNot404(http.MethodPost, "/api/v1/admin/catalog/import")
	assertNot404(http.MethodGet, "/api/v1/admin/users")
}
