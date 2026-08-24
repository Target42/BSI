package httpx

import (
	"fmt"
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
	ParentID              int64  `json:"parentId"`
	Type                  string `json:"type"`
	ProtectionNeed        string `json:"protectionNeed"`
	Confidentiality       string `json:"confidentiality"`
	Integrity             string `json:"integrity"`
	Availability          string `json:"availability"`
	InheritProtectionNeed *bool  `json:"inheritProtectionNeed"`
	ProtectionNeedNote    string `json:"protectionNeedNote"`
	Name                  string `json:"name"`
	Description           string `json:"description"`
}

type updateTargetObjectRequest struct {
	ParentID              int64  `json:"parentId"`
	Type                  string `json:"type"`
	ProtectionNeed        string `json:"protectionNeed"`
	Confidentiality       string `json:"confidentiality"`
	Integrity             string `json:"integrity"`
	Availability          string `json:"availability"`
	InheritProtectionNeed *bool  `json:"inheritProtectionNeed"`
	ProtectionNeedNote    string `json:"protectionNeedNote"`
	Name                  string `json:"name"`
	Description           string `json:"description"`
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
	req.Type = domain.NormalizeTargetObjectType(req.Type)
	if err := h.validatePlacement(r, projectID, req.ParentID, req.Type, 0); err != nil {
		if mapRepoError(w, err) {
			return
		}
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	item := domain.TargetObject{
		ProjectID:          projectID,
		ParentID:           req.ParentID,
		Type:               req.Type,
		ProtectionNeed:     req.ProtectionNeed,
		Confidentiality:    req.Confidentiality,
		Integrity:          req.Integrity,
		Availability:       req.Availability,
		ProtectionNeedNote: req.ProtectionNeedNote,
		Name:               req.Name,
		Description:        req.Description,
	}
	if req.InheritProtectionNeed != nil {
		item.InheritProtectionNeed = *req.InheritProtectionNeed
	} else {
		item.InheritProtectionNeed = req.ParentID > 0
	}
	var parent *domain.TargetObject
	if req.ParentID > 0 {
		p, err := h.store.GetTargetObject(r.Context(), req.ParentID)
		if err != nil {
			if mapRepoError(w, err) {
				return
			}
			writeError(w, http.StatusInternalServerError, "parent lookup failed")
			return
		}
		parent = &p
	}
	domain.ApplyTargetObjectProtectionNeed(&item, parent)
	created, err := h.store.CreateTargetObject(r.Context(), item)
	if err != nil {
		if mapRepoError(w, err) {
			return
		}
		writeError(w, http.StatusInternalServerError, "create target object failed")
		return
	}
	writeJSON(w, http.StatusCreated, created)
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
	req.Type = domain.NormalizeTargetObjectType(req.Type)
	current, err := h.store.GetTargetObject(r.Context(), targetID)
	if err != nil {
		if mapRepoError(w, err) {
			return
		}
		writeError(w, http.StatusInternalServerError, "target lookup failed")
		return
	}
	if domain.IsRootScopeTarget(current.ParentID, current.Type) && req.ParentID != current.ParentID {
		writeError(w, http.StatusBadRequest, "Der Informationsverbund kann nicht verschoben werden")
		return
	}
	if err := h.validatePlacement(r, projectID, req.ParentID, req.Type, targetID); err != nil {
		if mapRepoError(w, err) {
			return
		}
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	item := domain.TargetObject{
		ID:                    targetID,
		ProjectID:             projectID,
		ParentID:              req.ParentID,
		Type:                  req.Type,
		ProtectionNeed:        current.ProtectionNeed,
		Confidentiality:       req.Confidentiality,
		Integrity:             req.Integrity,
		Availability:          req.Availability,
		InheritProtectionNeed: current.InheritProtectionNeed,
		ProtectionNeedNote:    req.ProtectionNeedNote,
		Name:                  req.Name,
		Description:           req.Description,
	}
	if req.InheritProtectionNeed != nil {
		item.InheritProtectionNeed = *req.InheritProtectionNeed
	}
	if req.Confidentiality == "" {
		item.Confidentiality = current.Confidentiality
	}
	if req.Integrity == "" {
		item.Integrity = current.Integrity
	}
	if req.Availability == "" {
		item.Availability = current.Availability
	}
	var parent *domain.TargetObject
	if req.ParentID > 0 {
		p, err := h.store.GetTargetObject(r.Context(), req.ParentID)
		if err != nil {
			if mapRepoError(w, err) {
				return
			}
			writeError(w, http.StatusInternalServerError, "parent lookup failed")
			return
		}
		parent = &p
	}
	domain.ApplyTargetObjectProtectionNeed(&item, parent)
	updated, err := h.store.UpdateTargetObject(r.Context(), item)
	if err != nil {
		if mapRepoError(w, err) {
			return
		}
		writeError(w, http.StatusInternalServerError, "update target object failed")
		return
	}
	writeJSON(w, http.StatusOK, updated)
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
	current, err := h.store.GetTargetObject(r.Context(), targetID)
	if err != nil {
		if mapRepoError(w, err) {
			return
		}
		writeError(w, http.StatusInternalServerError, "target lookup failed")
		return
	}
	if domain.IsRootScopeTarget(current.ParentID, current.Type) {
		writeError(w, http.StatusConflict, "Der Informationsverbund kann nicht gelöscht werden")
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

func (h *TargetObjectHandler) validatePlacement(r *http.Request, projectID, parentID int64, childType string, objectID int64) error {
	if parentID == 0 {
		if domain.NormalizeTargetObjectType(childType) != domain.TargetTypeScope {
			return fmt.Errorf("ein Objekt ohne übergeordnetes Zielobjekt muss ein Informationsverbund sein")
		}
		return nil
	}
	if objectID > 0 && parentID == objectID {
		return fmt.Errorf("ein Zielobjekt kann nicht unter sich selbst eingehängt werden")
	}
	parent, err := h.store.GetTargetObject(r.Context(), parentID)
	if err != nil {
		return err
	}
	if parent.ProjectID != projectID {
		return fmt.Errorf("übergeordnetes Zielobjekt gehört nicht zu diesem Projekt")
	}
	if !domain.IsAllowedChildTargetType(parent.Type, childType) {
		return fmt.Errorf("dieser Zielobjekt-Typ ist unter %s nicht zulässig", parent.Type)
	}
	if objectID > 0 {
		items, listErr := h.store.ListTargetObjects(r.Context(), projectID)
		if listErr != nil {
			return listErr
		}
		if domain.WouldCreateParentCycle(items, objectID, parentID) {
			return fmt.Errorf("ein Zielobjekt kann nicht unter ein eigenes Unterobjekt verschoben werden")
		}
	}
	return nil
}
