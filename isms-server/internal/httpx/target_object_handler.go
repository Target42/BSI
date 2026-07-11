package httpx

import (
	"net/http"
	"strconv"

	"github.com/Target42/BSI/isms-server/internal/auth"
	"github.com/Target42/BSI/isms-server/internal/domain"
	"github.com/Target42/BSI/isms-server/internal/repository"
	"github.com/go-chi/chi/v5"
)

type TargetObjectHandler struct {
	store *repository.Store
}

func NewTargetObjectHandler(store *repository.Store) *TargetObjectHandler {
	return &TargetObjectHandler{store: store}
}

type createTargetObjectRequest struct {
	ParentID       int64  `json:"parentId"`
	Type           string `json:"type"`
	ProtectionNeed string `json:"protectionNeed"`
	Name           string `json:"name"`
	Description    string `json:"description"`
}

type updateTargetObjectRequest struct {
	ParentID       int64  `json:"parentId"`
	Type           string `json:"type"`
	ProtectionNeed string `json:"protectionNeed"`
	Name           string `json:"name"`
	Description    string `json:"description"`
}

func (h *TargetObjectHandler) List(w http.ResponseWriter, r *http.Request) {
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
	items, err := h.store.ListTargetObjects(r.Context(), projectID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "list target objects failed")
		return
	}
	if items == nil {
		items = []domain.TargetObject{}
	}
	writeJSON(w, http.StatusOK, items)
}

func (h *TargetObjectHandler) Create(w http.ResponseWriter, r *http.Request) {
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
	if _, err := h.store.RequireProjectRole(r.Context(), projectID, user, "editor"); err != nil {
		if mapRepoError(w, err) {
			return
		}
		writeError(w, http.StatusInternalServerError, "access check failed")
		return
	}
	var req createTargetObjectRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid json")
		return
	}
	if req.Name == "" || req.Type == "" {
		writeError(w, http.StatusBadRequest, "name and type required")
		return
	}
	if req.ProtectionNeed == "" {
		req.ProtectionNeed = "Normal (Basis + Standard)"
	}
	item, err := h.store.CreateTargetObject(r.Context(), domain.TargetObject{
		ProjectID:      projectID,
		ParentID:       req.ParentID,
		Type:           req.Type,
		ProtectionNeed: req.ProtectionNeed,
		Name:           req.Name,
		Description:    req.Description,
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, "create target object failed")
		return
	}
	writeJSON(w, http.StatusCreated, item)
}

func (h *TargetObjectHandler) Update(w http.ResponseWriter, r *http.Request) {
	user, ok := auth.UserFromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	targetID, err := strconv.ParseInt(chi.URLParam(r, "targetObjectID"), 10, 64)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid target object id")
		return
	}
	projectID, err := h.store.TargetObjectProjectID(r.Context(), targetID)
	if err != nil {
		if mapRepoError(w, err) {
			return
		}
		writeError(w, http.StatusInternalServerError, "target lookup failed")
		return
	}
	if _, err := h.store.RequireProjectRole(r.Context(), projectID, user, "editor"); err != nil {
		if mapRepoError(w, err) {
			return
		}
		writeError(w, http.StatusInternalServerError, "access check failed")
		return
	}
	var req updateTargetObjectRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid json")
		return
	}
	item, err := h.store.UpdateTargetObject(r.Context(), domain.TargetObject{
		ID:             targetID,
		ProjectID:      projectID,
		ParentID:       req.ParentID,
		Type:           req.Type,
		ProtectionNeed: req.ProtectionNeed,
		Name:           req.Name,
		Description:    req.Description,
	})
	if err != nil {
		if mapRepoError(w, err) {
			return
		}
		writeError(w, http.StatusInternalServerError, "update target object failed")
		return
	}
	writeJSON(w, http.StatusOK, item)
}

func (h *TargetObjectHandler) Delete(w http.ResponseWriter, r *http.Request) {
	user, ok := auth.UserFromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	targetID, err := strconv.ParseInt(chi.URLParam(r, "targetObjectID"), 10, 64)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid target object id")
		return
	}
	projectID, err := h.store.TargetObjectProjectID(r.Context(), targetID)
	if err != nil {
		if mapRepoError(w, err) {
			return
		}
		writeError(w, http.StatusInternalServerError, "target lookup failed")
		return
	}
	if _, err := h.store.RequireProjectRole(r.Context(), projectID, user, "editor"); err != nil {
		if mapRepoError(w, err) {
			return
		}
		writeError(w, http.StatusInternalServerError, "access check failed")
		return
	}
	if err := h.store.DeleteTargetObject(r.Context(), targetID); err != nil {
		if mapRepoError(w, err) {
			return
		}
		writeError(w, http.StatusInternalServerError, "delete target object failed")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
