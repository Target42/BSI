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

type ReviewHandler struct {
	store *repository.Store
}

func NewReviewHandler(store *repository.Store) *ReviewHandler {
	return &ReviewHandler{store: store}
}

func (h *ReviewHandler) ListProject(w http.ResponseWriter, r *http.Request) {
	user, ok := auth.UserFromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	projectID, err := strconv.ParseInt(chi.URLParam(r, "projectID"), 10, 64)
	if err != nil || projectID <= 0 {
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
	items, err := h.store.ListProjectReviews(r.Context(), projectID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "list reviews failed")
		return
	}
	if items == nil {
		items = []domain.BausteinReview{}
	}
	writeJSON(w, http.StatusOK, items)
}

func (h *ReviewHandler) List(w http.ResponseWriter, r *http.Request) {
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
	items, err := h.store.ListBausteinReviews(r.Context(), projectID, targetObjectID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "list reviews failed")
		return
	}
	list := make([]domain.BausteinReview, 0, len(items))
	for _, item := range items {
		list = append(list, item)
	}
	writeJSON(w, http.StatusOK, list)
}

func (h *ReviewHandler) Get(w http.ResponseWriter, r *http.Request) {
	user, ok := auth.UserFromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	projectID, targetObjectID, bausteinID, err := parseProjectTargetBaustein(r)
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
	item, err := h.store.GetBausteinReview(r.Context(), projectID, targetObjectID, bausteinID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "get review failed")
		return
	}
	writeJSON(w, http.StatusOK, item)
}

func (h *ReviewHandler) Apply(w http.ResponseWriter, r *http.Request) {
	user, ok := auth.UserFromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	projectID, targetObjectID, bausteinID, err := parseProjectTargetBaustein(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	project, role, err := h.store.LoadAccessibleProject(r.Context(), projectID, user, "viewer", true)
	if err != nil {
		if mapRepoError(w, err) {
			return
		}
		writeError(w, http.StatusInternalServerError, "access check failed")
		return
	}
	var req reviewActionRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid json")
		return
	}
	item, err := applyBausteinReview(r, h.store, project, role, user.UserID, targetObjectID, bausteinID, req.Action, req.Note, req.RequirementIDs)
	if err != nil {
		if mapReviewError(w, err) {
			return
		}
		writeError(w, http.StatusInternalServerError, "save review failed")
		return
	}
	writeJSON(w, http.StatusOK, item)
}

func (h *ReviewHandler) History(w http.ResponseWriter, r *http.Request) {
	user, ok := auth.UserFromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	projectID, targetObjectID, bausteinID, err := parseProjectTargetBaustein(r)
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
	items, err := h.store.ListBausteinReviewEvents(r.Context(), projectID, targetObjectID, bausteinID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "list review history failed")
		return
	}
	if items == nil {
		items = []domain.BausteinReviewEvent{}
	}
	writeJSON(w, http.StatusOK, items)
}

type assignReviewerRequest struct {
	AssignedReviewerID int64 `json:"assignedReviewerId"`
}

func (h *ReviewHandler) Assign(w http.ResponseWriter, r *http.Request) {
	user, ok := auth.UserFromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	projectID, targetObjectID, bausteinID, err := parseProjectTargetBaustein(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	project, role, err := h.store.LoadAccessibleProject(r.Context(), projectID, user, "editor", true)
	if err != nil {
		if mapRepoError(w, err) {
			return
		}
		writeError(w, http.StatusInternalServerError, "access check failed")
		return
	}
	if !domain.CanAssignReviewer(role) {
		writeError(w, http.StatusForbidden, "forbidden")
		return
	}
	var req assignReviewerRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid json")
		return
	}
	item, err := assignBausteinReviewer(r, h.store, project, targetObjectID, bausteinID, req.AssignedReviewerID)
	if err != nil {
		if mapReviewError(w, err) {
			return
		}
		writeError(w, http.StatusInternalServerError, "assign reviewer failed")
		return
	}
	writeJSON(w, http.StatusOK, item)
}

func parseProjectTargetBaustein(r *http.Request) (int64, int64, int64, error) {
	projectID, targetObjectID, err := parseProjectTarget(r)
	if err != nil {
		return 0, 0, 0, err
	}
	bausteinID, err := strconv.ParseInt(chi.URLParam(r, "bausteinID"), 10, 64)
	if err != nil || bausteinID <= 0 {
		return 0, 0, 0, errors.New("invalid baustein id")
	}
	return projectID, targetObjectID, bausteinID, nil
}
