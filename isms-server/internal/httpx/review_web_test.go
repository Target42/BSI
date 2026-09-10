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
	"github.com/Target42/BSI/isms-server/internal/repository"
)

func TestWorkplaceReviewActions(t *testing.T) {
	ui := newWebUI(auth.NewService("test-secret", time.Hour), nil, nil, "", nil)
	page := webPage{
		CanEdit:            true,
		CanOwn:             true,
		CanSubmit:          true,
		Project:            domain.Project{ID: 1, WorkflowEnabled: true},
		Target:             domain.TargetObject{ID: 2, Name: "Cluster"},
		Baustein:           domain.Baustein{ID: 9, ExternalID: "APP.1", Title: "Office"},
		WorkReqs:           []webWorkReq{{Requirement: domain.Requirement{ID: 3, ExternalID: "APP.1.A1", Title: "A"}}},
		AssessmentStatuses: webAssessmentStatuses,
		StatusFilters:      []string{"Anwendbar"},
		StatusFilter:       "Anwendbar",
		HighlightID:        9,
		Review:             domain.BausteinReview{State: domain.ReviewInProgress},
		WorkBausteine: []webWorkBaustein{{
			Baustein:    domain.Baustein{ID: 9, ExternalID: "APP.1", Title: "Office"},
			ReviewLabel: "In Bearbeitung",
		}},
	}
	var buf bytes.Buffer
	if err := ui.tmpl.ExecuteTemplate(&buf, "workplace", page); err != nil {
		t.Fatal(err)
	}
	body := buf.String()
	if !strings.Contains(body, "Zur Prüfung einreichen") || !strings.Contains(body, "Laufzettel") {
		t.Fatalf("submit action missing: %s", body)
	}
	if !strings.Contains(body, "assessments/bulk") {
		t.Fatal("editable baustein must still offer bulk status")
	}

	page.CanSubmit = false
	page.CanOwn = false
	page.CanReview = true
	page.ReviewLocked = true
	page.Review.State = domain.ReviewSubmitted
	buf.Reset()
	if err := ui.tmpl.ExecuteTemplate(&buf, "workplace", page); err != nil {
		t.Fatal(err)
	}
	locked := buf.String()
	if !strings.Contains(locked, "Abnehmen") || !strings.Contains(locked, "Zurückgeben") {
		t.Fatalf("reviewer actions missing: %s", locked)
	}
	if !strings.Contains(locked, `name="requirementID"`) || !strings.Contains(locked, "ganzen Baustein") {
		t.Fatalf("partial return checkboxes missing: %s", locked)
	}
	if strings.Contains(locked, "assessments/bulk") {
		t.Fatal("submitted baustein must not offer bulk status")
	}
}

func TestProjectSettingsWorkflowToggle(t *testing.T) {
	ui := newWebUI(auth.NewService("test-secret", time.Hour), nil, nil, "", nil)
	var buf bytes.Buffer
	err := ui.tmpl.ExecuteTemplate(&buf, "project_settings", webPage{
		CanEdit: true,
		CanOwn:  true,
		Project: domain.Project{ID: 1, Name: "Cloud", WorkflowEnabled: true},
	})
	if err != nil {
		t.Fatal(err)
	}
	body := buf.String()
	if !strings.Contains(body, `name="workflowEnabled"`) || !strings.Contains(body, "Prüfkreislauf") {
		t.Fatalf("workflow toggle missing: %s", body)
	}
}

func TestRouterRegistersReview(t *testing.T) {
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
		reviewHandler:     &ReviewHandler{},
	}
	handler := server.Router()
	req := httptest.NewRequest(http.MethodGet, "/api/v1/projects/1/target-objects/2/bausteine/3/review", nil)
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)
	if rec.Code == http.StatusNotFound {
		t.Fatalf("review route not registered: %d %s", rec.Code, rec.Body.String())
	}
	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("review route: got %d want 401, body %q", rec.Code, rec.Body.String())
	}

	req = httptest.NewRequest(http.MethodGet, "/api/v1/projects/1/reviews", nil)
	rec = httptest.NewRecorder()
	handler.ServeHTTP(rec, req)
	if rec.Code == http.StatusNotFound {
		t.Fatalf("project reviews route not registered: %d %s", rec.Code, rec.Body.String())
	}
	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("project reviews route: got %d want 401, body %q", rec.Code, rec.Body.String())
	}
}

func TestCockpitReviewQueueTemplate(t *testing.T) {
	ui := newWebUI(auth.NewService("test-secret", time.Hour), nil, nil, "", nil)
	var buf bytes.Buffer
	err := ui.tmpl.ExecuteTemplate(&buf, "cockpit", webPage{
		Project:       domain.Project{ID: 1, Name: "Cloud", WorkflowEnabled: true},
		StatusFilters: webMeasureStatusFilters,
		ReviewFilters: webReviewFilters,
		ReviewFilter:  domain.ReviewSubmitted,
		ReviewSummary: "1 Baustein zur Prüfung",
		ReviewQueue: []webReviewQueueItem{{
			BausteinReview:     domain.BausteinReview{TargetObjectID: 2, BausteinID: 9, State: domain.ReviewSubmitted},
			TargetObjectName:   "Cluster",
			BausteinExternalID: "APP.1",
			BausteinTitle:      "Office",
		}},
	})
	if err != nil {
		t.Fatal(err)
	}
	body := buf.String()
	if !strings.Contains(body, "Laufzettel") || !strings.Contains(body, "APP.1") || !strings.Contains(body, "zur Prüfung") {
		t.Fatalf("review queue missing: %s", body)
	}
}

func TestWorkplaceReviewerAssignForm(t *testing.T) {
	ui := newWebUI(auth.NewService("test-secret", time.Hour), nil, nil, "", nil)
	var buf bytes.Buffer
	err := ui.tmpl.ExecuteTemplate(&buf, "workplace", webPage{
		CanAssign:     true,
		CanSubmit:     true,
		Project:       domain.Project{ID: 1, WorkflowEnabled: true},
		Target:        domain.TargetObject{ID: 2},
		Baustein:      domain.Baustein{ID: 9, ExternalID: "APP.1", Title: "Office"},
		StatusFilters: []string{"Anwendbar"},
		StatusFilter:  "Anwendbar",
		Reviewers: []repository.ProjectMember{{
			UserID: 4, DisplayName: "Anna Prüfer", Role: domain.RoleReviewer,
		}},
	})
	if err != nil {
		t.Fatal(err)
	}
	body := buf.String()
	if !strings.Contains(body, "Prüfer zuweisen") || !strings.Contains(body, "Anna Prüfer") {
		t.Fatalf("assign form missing: %s", body)
	}
}

func TestWorkplaceReviewHistory(t *testing.T) {
	ui := newWebUI(auth.NewService("test-secret", time.Hour), nil, nil, "", nil)
	created := time.Date(2026, 9, 10, 16, 5, 0, 0, time.UTC)
	var buf bytes.Buffer
	err := ui.tmpl.ExecuteTemplate(&buf, "workplace", webPage{
		Project:       domain.Project{ID: 1, WorkflowEnabled: true},
		Target:        domain.TargetObject{ID: 2},
		Baustein:      domain.Baustein{ID: 9, ExternalID: "APP.1", Title: "Office"},
		StatusFilters: []string{"Anwendbar"},
		StatusFilter:  "Anwendbar",
		ReviewHistory: []webReviewEvent{{
			BausteinReviewEvent: domain.BausteinReviewEvent{
				Action:    domain.ReviewActionReturn,
				Note:      "Logging fehlt",
				ActorName: "Anna Prüfer",
				CreatedAt: created,
			},
			RequirementLabels: []string{"APP.1.A3"},
		}},
	})
	if err != nil {
		t.Fatal(err)
	}
	body := buf.String()
	if !strings.Contains(body, "Historie") || !strings.Contains(body, "Zurückgegeben") ||
		!strings.Contains(body, "Logging fehlt") || !strings.Contains(body, "Anna Prüfer") ||
		!strings.Contains(body, "APP.1.A3") {
		t.Fatalf("history missing: %s", body)
	}
}

func TestWorkplaceModelLockActions(t *testing.T) {
	ui := newWebUI(auth.NewService("test-secret", time.Hour), nil, nil, "", nil)
	page := webPage{
		CanEdit:       true,
		CanEditModel:  false,
		CanOwn:        false,
		Project:       domain.Project{ID: 1},
		Target:        domain.TargetObject{ID: 2, Name: "Cluster", Type: "IT-System", ModelLocked: true},
		CanSubmit:     true,
		StatusFilters: []string{"Anwendbar"},
		StatusFilter:  "Anwendbar",
	}
	var buf bytes.Buffer
	if err := ui.tmpl.ExecuteTemplate(&buf, "workplace", page); err != nil {
		t.Fatal(err)
	}
	body := buf.String()
	if !strings.Contains(body, "Modell festgezogen") {
		t.Fatalf("locked badge missing: %s", body)
	}
	if strings.Contains(body, "Modell festziehen") || strings.Contains(body, "Modell lösen") {
		t.Fatalf("editor must not toggle lock: %s", body)
	}
	if !strings.Contains(body, "Anzeigen") {
		t.Fatalf("editor should see read-only target link: %s", body)
	}

	page.CanOwn = true
	page.CanEditModel = true
	buf.Reset()
	if err := ui.tmpl.ExecuteTemplate(&buf, "workplace", page); err != nil {
		t.Fatal(err)
	}
	owner := buf.String()
	if !strings.Contains(owner, "Modell lösen") || !strings.Contains(owner, `name="locked"`) {
		t.Fatalf("owner unlock missing: %s", owner)
	}
}

func TestFilterMeasureRowsByReview(t *testing.T) {
	items := []webMeasureRow{
		{Measure: domain.Measure{Title: "Patch", Status: "Offen"}, ReviewState: domain.ReviewSubmitted, ReviewLabel: "Zur Prüfung"},
		{Measure: domain.Measure{Title: "Backup", Status: "Erledigt"}, ReviewState: domain.ReviewReturned, ReviewLabel: "Zurückgegeben"},
	}
	got := filterMeasureRows(items, "", "Alle", true, domain.ReviewReturned, 0)
	if len(got) != 1 || got[0].Title != "Backup" {
		t.Fatalf("review filter should keep returned even if done: %+v", got)
	}
}
