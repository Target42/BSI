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

type MeasureHandler struct {
	store *repository.Store
}

func NewMeasureHandler(store *repository.Store) *MeasureHandler {
	return &MeasureHandler{store: store}
}

type createMeasureRequest struct {
	Title       string  `json:"title"`
	Description string  `json:"description"`
	Responsible string  `json:"responsible"`
	DueDate     *string `json:"dueDate"`
	Status      string  `json:"status"`
}

type updateMeasureRequest struct {
	Title       string  `json:"title"`
	Description string  `json:"description"`
	Responsible string  `json:"responsible"`
	DueDate     *string `json:"dueDate"`
	Status      string  `json:"status"`
	Version     int     `json:"version"`
}

func (h *MeasureHandler) List(w http.ResponseWriter, r *http.Request) {
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

	items, err := h.store.ListMeasures(r.Context(), projectID, targetObjectID, requirementID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "list measures failed")
		return
	}
	if items == nil {
		items = []domain.Measure{}
	}
	writeJSON(w, http.StatusOK, items)
}

func (h *MeasureHandler) Create(w http.ResponseWriter, r *http.Request) {
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

	var req createMeasureRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid json")
		return
	}
	if req.Title == "" {
		writeError(w, http.StatusBadRequest, "title required")
		return
	}

	item, err := h.store.CreateMeasure(r.Context(), domain.Measure{
		ProjectID:      projectID,
		TargetObjectID: targetObjectID,
		RequirementID:  requirementID,
		Title:          req.Title,
		Description:    req.Description,
		Responsible:    req.Responsible,
		DueDate:        req.DueDate,
		Status:         req.Status,
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, "create measure failed")
		return
	}
	writeJSON(w, http.StatusCreated, item)
}

func (h *MeasureHandler) Update(w http.ResponseWriter, r *http.Request) {
	user, ok := auth.UserFromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	measureID, err := strconv.ParseInt(chi.URLParam(r, "measureID"), 10, 64)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid measure id")
		return
	}
	projectID, err := h.store.MeasureProjectID(r.Context(), measureID)
	if err != nil {
		if mapRepoError(w, err) {
			return
		}
		writeError(w, http.StatusInternalServerError, "measure lookup failed")
		return
	}
	if _, err := h.store.RequireProjectRole(r.Context(), projectID, user, "editor"); err != nil {
		if mapRepoError(w, err) {
			return
		}
		writeError(w, http.StatusInternalServerError, "access check failed")
		return
	}

	var req updateMeasureRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid json")
		return
	}
	if req.Title == "" {
		writeError(w, http.StatusBadRequest, "title required")
		return
	}

	item, err := h.store.UpdateMeasure(r.Context(), domain.Measure{
		ID:          measureID,
		Title:       req.Title,
		Description: req.Description,
		Responsible: req.Responsible,
		DueDate:     req.DueDate,
		Status:      req.Status,
		Version:     req.Version,
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
		writeError(w, http.StatusInternalServerError, "update measure failed")
		return
	}
	writeJSON(w, http.StatusOK, item)
}

func (h *MeasureHandler) MeasureCounts(w http.ResponseWriter, r *http.Request) {
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
	counts, err := h.store.MeasureCounts(r.Context(), projectID, targetObjectID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "measure counts failed")
		return
	}
	if counts == nil {
		counts = map[int64]int{}
	}
	writeJSON(w, http.StatusOK, counts)
}

func (h *MeasureHandler) Delete(w http.ResponseWriter, r *http.Request) {
	user, ok := auth.UserFromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	measureID, err := strconv.ParseInt(chi.URLParam(r, "measureID"), 10, 64)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid measure id")
		return
	}
	projectID, err := h.store.MeasureProjectID(r.Context(), measureID)
	if err != nil {
		if mapRepoError(w, err) {
			return
		}
		writeError(w, http.StatusInternalServerError, "measure lookup failed")
		return
	}
	if _, err := h.store.RequireProjectRole(r.Context(), projectID, user, "editor"); err != nil {
		if mapRepoError(w, err) {
			return
		}
		writeError(w, http.StatusInternalServerError, "access check failed")
		return
	}
	if err := h.store.DeleteMeasure(r.Context(), measureID); err != nil {
		if mapRepoError(w, err) {
			return
		}
		writeError(w, http.StatusInternalServerError, "delete measure failed")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
