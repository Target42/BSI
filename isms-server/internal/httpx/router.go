package httpx

import (
	"net/http"
	"time"

	"github.com/Target42/BSI/isms-server/internal/auth"
	"github.com/Target42/BSI/isms-server/internal/repository"
	"github.com/Target42/BSI/isms-server/internal/service"
	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
)

type Server struct {
	authService       *auth.Service
	authHandler       *AuthHandler
	projectHandler    *ProjectHandler
	targetHandler     *TargetObjectHandler
	assessmentHandler *AssessmentHandler
	measureHandler    *MeasureHandler
	catalogHandler    *CatalogHandler
	reportHandler     *ReportHandler
	adminHandler      *AdminHandler
	memberHandler     *MemberHandler
}

func NewServer(
	authService *auth.Service,
	store *repository.Store,
) *Server {
	reportService := service.NewReportService(store)
	return &Server{
		authService:       authService,
		authHandler:       NewAuthHandler(store, authService),
		projectHandler:    NewProjectHandler(store),
		targetHandler:     NewTargetObjectHandler(store),
		assessmentHandler: NewAssessmentHandler(store),
		measureHandler:    NewMeasureHandler(store),
		catalogHandler:    NewCatalogHandler(store),
		reportHandler:     NewReportHandler(store, reportService),
		adminHandler:      NewAdminHandler(store),
		memberHandler:     NewMemberHandler(store),
	}
}

func (s *Server) Router() http.Handler {
	r := chi.NewRouter()
	r.Use(middleware.RequestID)
	r.Use(middleware.RealIP)
	r.Use(middleware.Logger)
	r.Use(middleware.Recoverer)
	r.Use(middleware.Timeout(60 * time.Second))

	r.Get("/health", func(w http.ResponseWriter, _ *http.Request) {
		writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
	})

	r.Route("/api/v1", func(api chi.Router) {
		api.Post("/auth/login", s.authHandler.Login)

		api.Group(func(protected chi.Router) {
			protected.Use(s.authService.Middleware)
			protected.Get("/auth/me", s.authHandler.Me)

			protected.Get("/catalog/versions", s.catalogHandler.ListVersions)
			protected.Get("/catalog/{version}/bausteine", s.catalogHandler.ListBausteine)
			protected.Get("/catalog/bausteine/{bausteinID}/requirements", s.catalogHandler.ListRequirements)
			protected.Post("/admin/catalog/import", s.adminHandler.ImportCatalog)
			protected.Get("/admin/users", s.adminHandler.ListUsers)
			protected.Post("/admin/users", s.adminHandler.CreateUser)

			protected.Get("/projects", s.projectHandler.List)
			protected.Post("/projects", s.projectHandler.Create)
			protected.Get("/projects/{projectID}", s.projectHandler.Get)
			protected.Patch("/projects/{projectID}", s.projectHandler.Update)
			protected.Delete("/projects/{projectID}", s.projectHandler.Delete)

			protected.Get("/projects/{projectID}/members", s.memberHandler.List)
			protected.Post("/projects/{projectID}/members", s.memberHandler.Add)
			protected.Patch("/projects/{projectID}/members/{userID}", s.memberHandler.Update)
			protected.Delete("/projects/{projectID}/members/{userID}", s.memberHandler.Remove)

			protected.Get("/projects/{projectID}/progress", s.reportHandler.Progress)
			protected.Get("/projects/{projectID}/report/soll-ist", s.reportHandler.SollIst)

			protected.Get("/projects/{projectID}/target-objects", s.targetHandler.List)
			protected.Post("/projects/{projectID}/target-objects", s.targetHandler.Create)
			protected.Patch("/target-objects/{targetObjectID}", s.targetHandler.Update)
			protected.Delete("/target-objects/{targetObjectID}", s.targetHandler.Delete)

			protected.Get("/projects/{projectID}/target-objects/{targetObjectID}/assessments", s.assessmentHandler.ListAssessments)
			protected.Get("/projects/{projectID}/target-objects/{targetObjectID}/requirements/{requirementID}/assessment", s.assessmentHandler.GetAssessment)
			protected.Put("/projects/{projectID}/target-objects/{targetObjectID}/requirements/{requirementID}/assessment", s.assessmentHandler.SaveAssessment)

			protected.Get("/projects/{projectID}/target-objects/{targetObjectID}/applicability", s.assessmentHandler.ListApplicability)
			protected.Put("/projects/{projectID}/target-objects/{targetObjectID}/bausteine/{bausteinID}/applicability", s.assessmentHandler.SaveApplicability)
			protected.Delete("/projects/{projectID}/target-objects/{targetObjectID}/bausteine/{bausteinID}/applicability", s.assessmentHandler.DeleteApplicability)

			protected.Get("/projects/{projectID}/target-objects/{targetObjectID}/measure-counts", s.measureHandler.MeasureCounts)
			protected.Get("/projects/{projectID}/target-objects/{targetObjectID}/requirements/{requirementID}/measures", s.measureHandler.List)
			protected.Post("/projects/{projectID}/target-objects/{targetObjectID}/requirements/{requirementID}/measures", s.measureHandler.Create)
			protected.Patch("/measures/{measureID}", s.measureHandler.Update)
			protected.Delete("/measures/{measureID}", s.measureHandler.Delete)
		})
	})

	return r
}
