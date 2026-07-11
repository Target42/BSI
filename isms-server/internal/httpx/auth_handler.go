package httpx

import (
	"net/http"
	"time"

	"github.com/Target42/BSI/isms-server/internal/auth"
	"github.com/Target42/BSI/isms-server/internal/domain"
	"github.com/Target42/BSI/isms-server/internal/repository"
)

type AuthHandler struct {
	store *repository.Store
	auth  *auth.Service
}

func NewAuthHandler(store *repository.Store, authService *auth.Service) *AuthHandler {
	return &AuthHandler{store: store, auth: authService}
}

type loginRequest struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

type loginResponse struct {
	AccessToken string      `json:"accessToken"`
	ExpiresAt   string      `json:"expiresAt"`
	User        domain.User `json:"user"`
}

func (h *AuthHandler) Login(w http.ResponseWriter, r *http.Request) {
	var req loginRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid json")
		return
	}
	if req.Email == "" || req.Password == "" {
		writeError(w, http.StatusBadRequest, "email and password required")
		return
	}

	user, passwordHash, err := h.store.FindUserByEmail(r.Context(), req.Email)
	if err != nil {
		writeError(w, http.StatusUnauthorized, "invalid credentials")
		return
	}
	if !auth.CheckPassword(passwordHash, req.Password) {
		writeError(w, http.StatusUnauthorized, "invalid credentials")
		return
	}

	token, err := h.auth.CreateToken(user.ID, user.Email, user.DisplayName)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "token creation failed")
		return
	}
	writeJSON(w, http.StatusOK, loginResponse{
		AccessToken: token.AccessToken,
		ExpiresAt:   token.ExpiresAt.UTC().Format(time.RFC3339),
		User:        user,
	})
}

func (h *AuthHandler) Me(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.UserFromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	user, err := h.store.UserByID(r.Context(), claims.UserID)
	if err != nil {
		if mapRepoError(w, err) {
			return
		}
		writeError(w, http.StatusInternalServerError, "user lookup failed")
		return
	}
	writeJSON(w, http.StatusOK, user)
}
