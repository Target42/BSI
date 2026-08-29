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

func TestMatchApplicabilityFilter(t *testing.T) {
	if !matchApplicabilityFilter("Alle", "", false) {
		t.Fatal("Alle includes unset")
	}
	if matchApplicabilityFilter("Gesetzt", "", false) {
		t.Fatal("Gesetzt excludes empty")
	}
	if !matchApplicabilityFilter("Ungesetzt", "", false) {
		t.Fatal("Ungesetzt includes empty")
	}
	if !matchApplicabilityFilter("Geerbt", "Benötigt", true) {
		t.Fatal("Geerbt includes inherited")
	}
	if matchApplicabilityFilter("Geerbt", "Benötigt", false) {
		t.Fatal("Geerbt excludes own")
	}
	if !matchApplicabilityFilter("Benötigt", "Benötigt", false) {
		t.Fatal("exact status")
	}
	if matchApplicabilityFilter("Benötigt", "Möglicherweise", false) {
		t.Fatal("other status")
	}
}

func TestBulkRequirementIDs(t *testing.T) {
	items := []domain.Requirement{
		{ID: 1, Level: "Basis"},
		{ID: 2, Level: "Erhöht"},
		{ID: 3, Level: "Basis", Withdrawn: true},
		{ID: 4, Level: "Standard"},
	}
	assessments := map[int64]domain.RequirementAssessment{
		2: {Status: "Erfüllt"},
		4: {Status: "Teilweise"},
	}
	got := bulkRequirementIDs(items, domain.NeedNormal, assessments, true, "Erfüllt")
	if len(got) != 1 || got[0] != 1 {
		t.Fatalf("only open Basis/Standard for normal: %v", got)
	}
	got = bulkRequirementIDs(items, domain.NeedElevated, assessments, false, "")
	if len(got) != 3 {
		t.Fatalf("elevated includes Erhöht, skips withdrawn: %v", got)
	}
}

func TestGermanCount(t *testing.T) {
	if germanCount(1, "Baustein", "Bausteine") != "1 Baustein" {
		t.Fatal(germanCount(1, "Baustein", "Bausteine"))
	}
	if germanCount(12, "Baustein", "Bausteine") != "12 Bausteine" {
		t.Fatal(germanCount(12, "Baustein", "Bausteine"))
	}
}

func TestReportTemplatePrintControls(t *testing.T) {
	ui := newWebUI(auth.NewService("test-secret", time.Hour), nil, nil, "")
	var buf bytes.Buffer
	err := ui.tmpl.ExecuteTemplate(&buf, "report", webPage{
		Project:       domain.Project{Name: "Testverbund", CatalogVersion: "2023"},
		PrintDate:     "28.08.2026, 16:40",
		StatusFilter:  "Offen",
		StatusFilters: webStatusFilters,
		CSVHref:       "/projects/1/report.csv",
	})
	if err != nil {
		t.Fatal(err)
	}
	body := buf.String()
	for _, want := range []string{
		"Drucken",
		"window.print()",
		"print-only",
		"gedruckt 28.08.2026, 16:40",
		"CSV herunterladen",
		"page-report",
	} {
		if !strings.Contains(body, want) {
			t.Fatalf("report template missing %q in %s", want, body)
		}
	}
}

func TestBulkFormsRender(t *testing.T) {
	ui := newWebUI(auth.NewService("test-secret", time.Hour), nil, nil, "")
	var buf bytes.Buffer
	if err := ui.tmpl.ExecuteTemplate(&buf, "applicability", webPage{
		CanEdit:               true,
		Project:               domain.Project{ID: 1},
		Target:                domain.TargetObject{ID: 2, Name: "Server"},
		ApplicabilityStatuses: webApplicabilityStatuses,
		ApplicabilityRows:     []webApplicabilityRow{{Baustein: domain.Baustein{ID: 9, ExternalID: "APP.1", Title: "Test"}}},
		StatusFilters:         []string{"Alle"},
		StatusFilter:          "Alle",
	}); err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(buf.String(), "applicability/bulk") || !strings.Contains(buf.String(), "Massenstatus") {
		t.Fatalf("applicability bulk form missing: %s", buf.String())
	}
	buf.Reset()
	if err := ui.tmpl.ExecuteTemplate(&buf, "workplace", webPage{
		CanEdit:            true,
		Project:            domain.Project{ID: 1},
		Target:             domain.TargetObject{ID: 2, Name: "Server"},
		Baustein:           domain.Baustein{ID: 9, ExternalID: "APP.1", Title: "Test"},
		WorkReqs:           []webWorkReq{{Requirement: domain.Requirement{ID: 3, ExternalID: "APP.1.A1", Title: "A"}}},
		AssessmentStatuses: webAssessmentStatuses,
		StatusFilters:      []string{"Anwendbar"},
		StatusFilter:       "Anwendbar",
		HighlightID:        9,
	}); err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(buf.String(), "assessments/bulk") || !strings.Contains(buf.String(), "Nur offene") {
		t.Fatalf("workplace bulk form missing: %s", buf.String())
	}
}

func TestBulkPostsRedirectToLogin(t *testing.T) {
	handler := NewServer(auth.NewService("test-secret", time.Hour), nil, "").Router()
	for _, path := range []string{
		"/projects/1/targets/1/applicability/bulk",
		"/projects/1/targets/1/assessments/bulk",
	} {
		req := httptest.NewRequest(http.MethodPost, path, nil)
		rec := httptest.NewRecorder()
		handler.ServeHTTP(rec, req)
		if rec.Code != http.StatusSeeOther {
			t.Fatalf("%s status %d", path, rec.Code)
		}
		if loc := rec.Header().Get("Location"); !strings.HasPrefix(loc, "/login") {
			t.Fatalf("%s Location %q", path, loc)
		}
	}
}
