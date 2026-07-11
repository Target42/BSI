package httpx

import (
	"net/http"
	"strconv"

	"github.com/Target42/BSI/isms-server/internal/auth"
	"github.com/Target42/BSI/isms-server/internal/domain"
	"github.com/Target42/BSI/isms-server/internal/repository"
	"github.com/Target42/BSI/isms-server/internal/service"
	"github.com/go-chi/chi/v5"
)

type ReportHandler struct {
	store   *repository.Store
	reports *service.ReportService
}

func NewReportHandler(store *repository.Store, reports *service.ReportService) *ReportHandler {
	return &ReportHandler{store: store, reports: reports}
}

type progressResponse struct {
	Project  domain.ReportSummary   `json:"project"`
	Targets  []domain.TargetProgress `json:"targets"`
}

func (h *ReportHandler) Progress(w http.ResponseWriter, r *http.Request) {
	user, ok := auth.UserFromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	projectID, err := strconv.ParseInt(chi.URLParam(r, "projectID"), 10, 64)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid project id")
		return
	}
	if _, err := h.store.RequireProjectRole(r.Context(), projectID, user, "viewer"); err != nil {
		if mapRepoError(w, err) {
			return
		}
		writeError(w, http.StatusInternalServerError, "access check failed")
		return
	}

	projectSummary, targets, err := h.reports.ProjectProgress(r.Context(), projectID)
	if err != nil {
		if mapRepoError(w, err) {
			return
		}
		writeError(w, http.StatusInternalServerError, "progress failed")
		return
	}
	if targets == nil {
		targets = []domain.TargetProgress{}
	}
	writeJSON(w, http.StatusOK, progressResponse{Project: projectSummary, Targets: targets})
}

func (h *ReportHandler) SollIst(w http.ResponseWriter, r *http.Request) {
	user, ok := auth.UserFromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	projectID, err := strconv.ParseInt(chi.URLParam(r, "projectID"), 10, 64)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid project id")
		return
	}
	if _, err := h.store.RequireProjectRole(r.Context(), projectID, user, "viewer"); err != nil {
		if mapRepoError(w, err) {
			return
		}
		writeError(w, http.StatusInternalServerError, "access check failed")
		return
	}

	var targetObjectID int64
	if raw := r.URL.Query().Get("targetObjectId"); raw != "" {
		targetObjectID, err = strconv.ParseInt(raw, 10, 64)
		if err != nil {
			writeError(w, http.StatusBadRequest, "invalid targetObjectId")
			return
		}
	}

	rows, err := h.reports.BuildSollIstReport(r.Context(), projectID, targetObjectID, r.URL.Query().Get("catalogVersion"))
	if err != nil {
		if mapRepoError(w, err) {
			return
		}
		writeError(w, http.StatusInternalServerError, "report failed")
		return
	}
	if rows == nil {
		rows = []domain.ReportRow{}
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"rows":    rows,
		"summary": service.Summarize(rows),
	})
}
