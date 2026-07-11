package httpx

import (
	"errors"
	"net/http"
	"strconv"

	"github.com/Target42/BSI/isms-server/internal/auth"
	"github.com/Target42/BSI/isms-server/internal/domain"
	"github.com/Target42/BSI/isms-server/internal/repository"
	"github.com/go-chi/chi/v5"
)

type AssessmentHandler struct {
	store *repository.Store
}

func NewAssessmentHandler(store *repository.Store) *AssessmentHandler {
	return &AssessmentHandler{store: store}
}

type saveAssessmentRequest struct {
	Status      string  `json:"status"`
	Note        string  `json:"note"`
	Responsible string  `json:"responsible"`
	DueDate     *string `json:"dueDate"`
	Version     int     `json:"version"`
}

type saveApplicabilityRequest struct {
	Status string `json:"status"`
}

func (h *AssessmentHandler) ListAssessments(w http.ResponseWriter, r *http.Request) {
	user, ok := auth.UserFromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	projectID, targetObjectID, err := parseProjectTarget(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	if _, err := h.store.RequireProjectRole(r.Context(), projectID, user, "viewer"); err != nil {
		if mapRepoError(w, err) {
			return
		}
		writeError(w, http.StatusInternalServerError, "access check failed")
		return
	}
	items, err := h.store.ListAssessments(r.Context(), projectID, targetObjectID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "list assessments failed")
		return
	}
	if items == nil {
		items = []domain.RequirementAssessment{}
	}
	writeJSON(w, http.StatusOK, items)
}

func (h *AssessmentHandler) GetAssessment(w http.ResponseWriter, r *http.Request) {
	user, ok := auth.UserFromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	projectID, targetObjectID, requirementID, err := parseProjectTargetRequirement(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	if _, err := h.store.RequireProjectRole(r.Context(), projectID, user, "viewer"); err != nil {
		if mapRepoError(w, err) {
			return
		}
		writeError(w, http.StatusInternalServerError, "access check failed")
		return
	}
	item, err := h.store.GetAssessment(r.Context(), projectID, targetObjectID, requirementID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "get assessment failed")
		return
	}
	writeJSON(w, http.StatusOK, item)
}

func (h *AssessmentHandler) SaveAssessment(w http.ResponseWriter, r *http.Request) {
	user, ok := auth.UserFromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	projectID, targetObjectID, requirementID, err := parseProjectTargetRequirement(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	if _, err := h.store.RequireProjectRole(r.Context(), projectID, user, "editor"); err != nil {
		if mapRepoError(w, err) {
			return
		}
		writeError(w, http.StatusInternalServerError, "access check failed")
		return
	}
	var req saveAssessmentRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid json")
		return
	}
	if req.Status == "" {
		req.Status = "Offen"
	}
	item, err := h.store.SaveAssessment(r.Context(), domain.RequirementAssessment{
		ProjectID:      projectID,
		TargetObjectID: targetObjectID,
		RequirementID:  requirementID,
		Status:         req.Status,
		Note:           req.Note,
		Responsible:    req.Responsible,
		DueDate:        req.DueDate,
		Version:        req.Version,
	})
	if err != nil {
		if errors.Is(err, repository.ErrVersionConflict) {
			writeJSON(w, http.StatusConflict, map[string]any{
				"error":   "version_conflict",
				"current": item,
			})
			return
		}
		if mapRepoError(w, err) {
			return
		}
		writeError(w, http.StatusInternalServerError, "save assessment failed")
		return
	}
	writeJSON(w, http.StatusOK, item)
}

func (h *AssessmentHandler) ListApplicability(w http.ResponseWriter, r *http.Request) {
	user, ok := auth.UserFromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	projectID, targetObjectID, err := parseProjectTarget(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	if _, err := h.store.RequireProjectRole(r.Context(), projectID, user, "viewer"); err != nil {
		if mapRepoError(w, err) {
			return
		}
		writeError(w, http.StatusInternalServerError, "access check failed")
		return
	}
	items, err := h.store.ApplicabilityMap(r.Context(), projectID, targetObjectID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "list applicability failed")
		return
	}
	if items == nil {
		items = map[int64]string{}
	}
	writeJSON(w, http.StatusOK, items)
}

func (h *AssessmentHandler) SaveApplicability(w http.ResponseWriter, r *http.Request) {
	user, ok := auth.UserFromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	projectID, targetObjectID, err := parseProjectTarget(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	bausteinID, err := strconv.ParseInt(chi.URLParam(r, "bausteinID"), 10, 64)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid baustein id")
		return
	}
	if _, err := h.store.RequireProjectRole(r.Context(), projectID, user, "editor"); err != nil {
		if mapRepoError(w, err) {
			return
		}
		writeError(w, http.StatusInternalServerError, "access check failed")
		return
	}
	var req saveApplicabilityRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid json")
		return
	}
	if req.Status == "" {
		writeError(w, http.StatusBadRequest, "status required")
		return
	}
	item, err := h.store.SaveApplicability(r.Context(), domain.BausteinApplicability{
		ProjectID:      projectID,
		TargetObjectID: targetObjectID,
		BausteinID:     bausteinID,
		Status:         req.Status,
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, "save applicability failed")
		return
	}
	writeJSON(w, http.StatusOK, item)
}

func parseProjectTarget(r *http.Request) (int64, int64, error) {
	projectID, err := strconv.ParseInt(chi.URLParam(r, "projectID"), 10, 64)
	if err != nil {
		return 0, 0, errors.New("invalid project id")
	}
	targetObjectID, err := strconv.ParseInt(chi.URLParam(r, "targetObjectID"), 10, 64)
	if err != nil {
		return 0, 0, errors.New("invalid target object id")
	}
	return projectID, targetObjectID, nil
}

func parseProjectTargetRequirement(r *http.Request) (int64, int64, int64, error) {
	projectID, targetObjectID, err := parseProjectTarget(r)
	if err != nil {
		return 0, 0, 0, err
	}
	requirementID, err := strconv.ParseInt(chi.URLParam(r, "requirementID"), 10, 64)
	if err != nil {
		return 0, 0, 0, errors.New("invalid requirement id")
	}
	return projectID, targetObjectID, requirementID, nil
}
