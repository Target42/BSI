package httpx

import (
	"net/http"
	"strconv"

	"github.com/Target42/BSI/isms-server/internal/auth"
	"github.com/Target42/BSI/isms-server/internal/domain"
	"github.com/Target42/BSI/isms-server/internal/repository"
	"github.com/go-chi/chi/v5"
)

type ProjectHandler struct {
	store *repository.Store
}

func NewProjectHandler(store *repository.Store) *ProjectHandler {
	return &ProjectHandler{store: store}
}

type createProjectRequest struct {
	Name           string `json:"name"`
	Description    string `json:"description"`
	CatalogVersion string `json:"catalogVersion"`
}

type updateProjectRequest struct {
	Name        string `json:"name"`
	Description string `json:"description"`
}

func (h *ProjectHandler) List(w http.ResponseWriter, r *http.Request) {
	user, ok := auth.UserFromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	projects, err := h.store.ListProjects(r.Context(), user.UserID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "list projects failed")
		return
	}
	if projects == nil {
		projects = []domain.Project{}
	}
	writeJSON(w, http.StatusOK, projects)
}

func (h *ProjectHandler) Create(w http.ResponseWriter, r *http.Request) {
	user, ok := auth.UserFromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	var req createProjectRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid json")
		return
	}
	if req.Name == "" {
		writeError(w, http.StatusBadRequest, "name required")
		return
	}
	if req.CatalogVersion == "" {
		req.CatalogVersion = "2023"
	}
	project, err := h.store.CreateProject(r.Context(), user.UserID, req.Name, req.Description, req.CatalogVersion)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "create project failed")
		return
	}
	writeJSON(w, http.StatusCreated, project)
}

func (h *ProjectHandler) Get(w http.ResponseWriter, r *http.Request) {
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
	project, err := h.store.GetProject(r.Context(), projectID)
	if err != nil {
		if mapRepoError(w, err) {
			return
		}
		writeError(w, http.StatusInternalServerError, "get project failed")
		return
	}
	writeJSON(w, http.StatusOK, project)
}

func (h *ProjectHandler) Update(w http.ResponseWriter, r *http.Request) {
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
	var req updateProjectRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid json")
		return
	}
	project, err := h.store.UpdateProject(r.Context(), domain.Project{
		ID:          projectID,
		Name:        req.Name,
		Description: req.Description,
	})
	if err != nil {
		if mapRepoError(w, err) {
			return
		}
		writeError(w, http.StatusInternalServerError, "update project failed")
		return
	}
	writeJSON(w, http.StatusOK, project)
}

func (h *ProjectHandler) Delete(w http.ResponseWriter, r *http.Request) {
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
	if _, err := h.store.RequireProjectRole(r.Context(), projectID, user, "owner"); err != nil {
		if mapRepoError(w, err) {
			return
		}
		writeError(w, http.StatusInternalServerError, "access check failed")
		return
	}
	if err := h.store.DeleteProject(r.Context(), projectID); err != nil {
		if mapRepoError(w, err) {
			return
		}
		writeError(w, http.StatusInternalServerError, "delete project failed")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
