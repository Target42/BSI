package httpx

import (
	"bytes"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/Target42/BSI/isms-server/internal/auth"
	"github.com/Target42/BSI/isms-server/internal/domain"
)

func TestEmbeddedWebUIServesPagesAndLeavesAPI(t *testing.T) {
	handler := NewServer(auth.NewService("test-secret", time.Hour), nil, "").Router()

	assert := func(method, path string, wantStatus int, wantContains string) *httptest.ResponseRecorder {
		t.Helper()
		req := httptest.NewRequest(method, path, nil)
		rec := httptest.NewRecorder()
		handler.ServeHTTP(rec, req)
		if rec.Code != wantStatus {
			t.Fatalf("%s %s: status %d want %d body %q", method, path, rec.Code, wantStatus, rec.Body.String())
		}
		if wantContains != "" && !strings.Contains(rec.Body.String(), wantContains) {
			t.Fatalf("%s %s: body %q missing %q", method, path, rec.Body.String(), wantContains)
		}
		return rec
	}

	rec := assert(http.MethodGet, "/", http.StatusOK, "Zu den Projekten")
	if !strings.Contains(rec.Body.String(), "Anmelden") {
		t.Fatalf("GET / must offer login, body %q", rec.Body.String())
	}
	assert(http.MethodGet, "/login", http.StatusOK, "brand-mark")
	assert(http.MethodGet, "/ui/app.css", http.StatusOK, "@media print")
	assert(http.MethodGet, "/health", http.StatusOK, `"status":"ok"`)
	assert(http.MethodGet, "/api/v1/projects", http.StatusUnauthorized, "")
	assert(http.MethodGet, "/projects", http.StatusOK, "Projekte")

	for _, path := range []string{
		"/projects/1/members",
		"/account",
		"/users",
		"/projects/new",
		"/catalog",
		"/catalog/bausteine/1",
	} {
		rec := assert(http.MethodGet, path, http.StatusSeeOther, "")
		if loc := rec.Header().Get("Location"); !strings.HasPrefix(loc, "/login") {
			t.Fatalf("GET %s Location %q", path, loc)
		}
	}

	for _, path := range []string{
		"/projects/1/cockpit",
		"/projects/1/targets/1/requirements/1",
		"/projects/1/measures/1",
		"/projects/1/targets/1/edit",
		"/projects/1/targets/1/applicability",
		"/projects/1/targets/1/recommendations",
		"/projects/1/targets/1",
		"/projects/1/report.csv",
		"/projects/1/edit",
		"/projects/1/settings",
		"/projects/1",
	} {
		assert(http.MethodGet, path, http.StatusNotFound, "")
	}

	req := httptest.NewRequest(http.MethodGet, "/api/v1/does-not-exist", nil)
	rec = httptest.NewRecorder()
	handler.ServeHTTP(rec, req)
	if rec.Code != http.StatusNotFound {
		t.Fatalf("unknown API path: status %d", rec.Code)
	}
	if strings.Contains(rec.Body.String(), "Anmelden") {
		t.Fatalf("API 404 must not serve HTML login")
	}
}

func TestEmbeddedWebUIPublicBase(t *testing.T) {
	handler := NewServer(auth.NewService("test-secret", time.Hour), nil, "/isms").Router()
	req := httptest.NewRequest(http.MethodGet, "/login", nil)
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("status %d", rec.Code)
	}
	if !strings.Contains(rec.Body.String(), `href="/isms/ui/app.css"`) {
		t.Fatalf("expected prefixed asset href, body %s", rec.Body.String())
	}
	if !strings.Contains(rec.Body.String(), `action="/isms/login"`) {
		t.Fatalf("expected prefixed login action, body %s", rec.Body.String())
	}
}

func TestHomeAndProjectPages(t *testing.T) {
	ui := newWebUI(auth.NewService("test-secret", time.Hour), nil, nil, "", nil)
	var buf bytes.Buffer
	if err := ui.tmpl.ExecuteTemplate(&buf, "home", webPage{}); err != nil {
		t.Fatal(err)
	}
	home := buf.String()
	for _, want := range []string{`class="brand-mark"`, `width="160"`, "Zu den Projekten", "IT-Grundschutz im Browser"} {
		if !strings.Contains(home, want) {
			t.Fatalf("home missing %q", want)
		}
	}
	buf.Reset()
	if err := ui.tmpl.ExecuteTemplate(&buf, "projects", webPage{LoggedIn: true}); err != nil {
		t.Fatal(err)
	}
	list := buf.String()
	if !strings.Contains(list, "/projects/new") {
		t.Fatal("project list must link to create page")
	}
	if strings.Contains(list, `action="/projects"`) {
		t.Fatal("create form must not sit on the project list")
	}
	buf.Reset()
	if err := ui.tmpl.ExecuteTemplate(&buf, "project_new", webPage{
		CatalogVersions: []string{"2023"},
	}); err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(buf.String(), `action="/projects/new"`) {
		t.Fatal("create page must post to /projects/new")
	}
	buf.Reset()
	if err := ui.tmpl.ExecuteTemplate(&buf, "header", webPage{}); err != nil {
		t.Fatal(err)
	}
	head := buf.String()
	if !strings.Contains(head, `href="/"`) || !strings.Contains(head, `href="/projects"`) {
		t.Fatalf("header must split ISMS and Projekte: %s", head)
	}
	if !strings.Contains(head, "Anmelden") {
		t.Fatalf("anonymous header must offer login: %s", head)
	}
	if strings.Contains(head, "Abmelden") {
		t.Fatalf("anonymous header must not offer logout: %s", head)
	}
}

func TestFilterMeasures(t *testing.T) {
	done := "2020-01-01"
	open := "2099-01-01"
	items := []domain.Measure{
		{ID: 1, Title: "Patchen", Status: "Offen", Responsible: "IT", DueDate: &open},
		{ID: 2, Title: "Schulung", Status: "Erledigt", Responsible: "ISB", DueDate: &done},
		{ID: 3, Title: "Firewall", Status: "In Bearbeitung", Responsible: "Netz"},
	}
	got := filterMeasures(items, "patch", "Alle", false)
	if len(got) != 1 || got[0].ID != 1 {
		t.Fatalf("search: %+v", got)
	}
	got = filterMeasures(items, "", "Alle", true)
	if len(got) != 2 {
		t.Fatalf("hide done: %d", len(got))
	}
	got = filterMeasures(items, "", "Erledigt", false)
	if len(got) != 1 || got[0].ID != 2 {
		t.Fatalf("status filter: %+v", got)
	}
}

func TestFlattenTargetsKeepsTreeOrder(t *testing.T) {
	items := []domain.TargetObject{
		{ID: 2, ParentID: 1, Name: "Prozess", Type: domain.TargetTypeProcess},
		{ID: 1, ParentID: 0, Name: "Verbund", Type: domain.TargetTypeScope},
		{ID: 3, ParentID: 2, Name: "App", Type: domain.TargetTypeApplication},
	}
	got := flattenTargets(items, map[int64]domain.ReportSummary{2: {OpenCount: 4}})
	if len(got) != 3 || got[0].Name != "Verbund" || got[1].Name != "Prozess" || got[2].Name != "App" {
		t.Fatalf("order: %+v", got)
	}
	if got[0].Depth != 0 || got[1].Depth != 1 || got[2].Depth != 2 {
		t.Fatalf("depth: %+v", got)
	}
	if got[1].Summary.OpenCount != 4 {
		t.Fatalf("progress: %+v", got[1].Summary)
	}
}

func TestSafeNextPath(t *testing.T) {
	tests := []struct {
		in, want string
	}{
		{"", ""},
		{"/projects/3", "/projects/3"},
		{"//evil.example", ""},
		{"https://evil.example", ""},
		{"projects", ""},
	}
	for _, tc := range tests {
		if got := safeNextPath(tc.in); got != tc.want {
			t.Fatalf("safeNextPath(%q)=%q want %q", tc.in, got, tc.want)
		}
	}
}
