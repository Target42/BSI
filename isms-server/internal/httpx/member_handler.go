package httpx

import (
	"net/http"
	"strconv"

	"github.com/Target42/BSI/isms-server/internal/auth"
	"github.com/Target42/BSI/isms-server/internal/repository"
	"github.com/go-chi/chi/v5"
)

type MemberHandler struct {
	store *repository.Store
}

func NewMemberHandler(store *repository.Store) *MemberHandler {
	return &MemberHandler{store: store}
}

type addMemberRequest struct {
	UserID int64  `json:"userId"`
	Email  string `json:"email"`
	Role   string `json:"role"`
}

type updateMemberRequest struct {
	Role string `json:"role"`
}

func (h *MemberHandler) List(w http.ResponseWriter, r *http.Request) {
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

	members, err := h.store.ListProjectMembers(r.Context(), projectID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "list members failed")
		return
	}
	if members == nil {
		members = []repository.ProjectMember{}
	}
	writeJSON(w, http.StatusOK, members)
}

func (h *MemberHandler) Add(w http.ResponseWriter, r *http.Request) {
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

	var req addMemberRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid json")
		return
	}
	if req.Role == "" {
		req.Role = "editor"
	}
	if req.Role != "owner" && req.Role != "editor" && req.Role != "viewer" {
		writeError(w, http.StatusBadRequest, "invalid role")
		return
	}

	userID := req.UserID
	if userID == 0 && req.Email != "" {
		found, _, err := h.store.FindUserByEmail(r.Context(), req.Email)
		if err != nil {
			writeError(w, http.StatusBadRequest, "user not found")
			return
		}
		userID = found.ID
	}
	if userID == 0 {
		writeError(w, http.StatusBadRequest, "userId or email required")
		return
	}

	member, err := h.store.AddProjectMember(r.Context(), projectID, userID, req.Role)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "add member failed")
		return
	}
	writeJSON(w, http.StatusCreated, member)
}

func (h *MemberHandler) Update(w http.ResponseWriter, r *http.Request) {
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
	memberUserID, err := strconv.ParseInt(chi.URLParam(r, "userID"), 10, 64)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid user id")
		return
	}
	if _, err := h.store.RequireProjectRole(r.Context(), projectID, user, "owner"); err != nil {
		if mapRepoError(w, err) {
			return
		}
		writeError(w, http.StatusInternalServerError, "access check failed")
		return
	}

	var req updateMemberRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid json")
		return
	}
	if req.Role != "owner" && req.Role != "editor" && req.Role != "viewer" {
		writeError(w, http.StatusBadRequest, "invalid role")
		return
	}

	member, err := h.store.UpdateProjectMemberRole(r.Context(), projectID, memberUserID, req.Role)
	if err != nil {
		if mapRepoError(w, err) {
			return
		}
		writeError(w, http.StatusInternalServerError, "update member failed")
		return
	}
	writeJSON(w, http.StatusOK, member)
}

func (h *MemberHandler) Remove(w http.ResponseWriter, r *http.Request) {
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
	memberUserID, err := strconv.ParseInt(chi.URLParam(r, "userID"), 10, 64)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid user id")
		return
	}
	if _, err := h.store.RequireProjectRole(r.Context(), projectID, user, "owner"); err != nil {
		if mapRepoError(w, err) {
			return
		}
		writeError(w, http.StatusInternalServerError, "access check failed")
		return
	}

	if memberUserID == user.UserID {
		writeError(w, http.StatusBadRequest, "cannot remove yourself")
		return
	}

	owners, err := h.store.CountProjectOwners(r.Context(), projectID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "owner check failed")
		return
	}
	role, _ := h.store.ProjectRole(r.Context(), projectID, memberUserID)
	if role == "owner" && owners <= 1 {
		writeError(w, http.StatusBadRequest, "cannot remove last owner")
		return
	}

	if err := h.store.RemoveProjectMember(r.Context(), projectID, memberUserID); err != nil {
		if mapRepoError(w, err) {
			return
		}
		writeError(w, http.StatusInternalServerError, "remove member failed")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
