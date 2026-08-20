package httpx

import (
	"errors"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"

	"github.com/Target42/BSI/isms-server/internal/auth"
	"github.com/Target42/BSI/isms-server/internal/catalog"
	"github.com/Target42/BSI/isms-server/internal/domain"
	"github.com/Target42/BSI/isms-server/internal/repository"
	"github.com/jackc/pgx/v5/pgconn"
)

const maxCatalogUploadBytes = 100 << 20 // 100 MiB

type AdminHandler struct {
	store *repository.Store
}

func NewAdminHandler(store *repository.Store) *AdminHandler {
	return &AdminHandler{store: store}
}

func (h *AdminHandler) ImportCatalog(w http.ResponseWriter, r *http.Request) {
	user, ok := auth.UserFromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	isAdmin, err := h.store.IsAdmin(r.Context(), user.UserID)
	if err != nil || !isAdmin {
		writeError(w, http.StatusForbidden, "admin required")
		return
	}

	r.Body = http.MaxBytesReader(w, r.Body, maxCatalogUploadBytes)
	tmpPath, fileName, err := saveCatalogUpload(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	defer os.Remove(tmpPath)

	result := catalog.ImportFromFile(tmpPath)
	if !result.Success {
		writeJSON(w, http.StatusBadRequest, map[string]any{
			"error":   "import_parse_failed",
			"message": result.ErrorMessage,
		})
		return
	}

	if err := h.store.ReplaceGrundschutzCatalog(r.Context(), result); err != nil {
		writeError(w, http.StatusInternalServerError, "catalog replace failed")
		return
	}

	writeJSON(w, http.StatusOK, map[string]any{
		"catalogVersion":   result.CatalogVersion,
		"bausteinCount":    len(result.Bausteine),
		"requirementCount": len(result.Requirements),
		"fileName":         fileName,
	})
}

func saveCatalogUpload(r *http.Request) (string, string, error) {
	contentType := r.Header.Get("Content-Type")
	if strings.HasPrefix(contentType, "multipart/") {
		if err := r.ParseMultipartForm(maxCatalogUploadBytes); err != nil {
			return "", "", err
		}
		file, header, err := r.FormFile("file")
		if err != nil {
			return "", "", err
		}
		defer file.Close()
		tmpPath, err := writeCatalogTempFile(file)
		if err != nil {
			return "", "", err
		}
		name := "catalog.xml"
		if header != nil && header.Filename != "" {
			name = filepath.Base(header.Filename)
		}
		return tmpPath, name, nil
	}

	tmpPath, err := writeCatalogTempFile(r.Body)
	if err != nil {
		return "", "", err
	}
	return tmpPath, "catalog.xml", nil
}

func writeCatalogTempFile(src io.Reader) (string, error) {
	tmpFile, err := os.CreateTemp("", "isms-catalog-*.xml")
	if err != nil {
		return "", err
	}
	tmpPath := tmpFile.Name()
	if _, err := io.Copy(tmpFile, src); err != nil {
		tmpFile.Close()
		os.Remove(tmpPath)
		return "", err
	}
	if err := tmpFile.Close(); err != nil {
		os.Remove(tmpPath)
		return "", err
	}
	return tmpPath, nil
}

type createUserRequest struct {
	Email       string `json:"email"`
	DisplayName string `json:"displayName"`
	Password    string `json:"password"`
	IsAdmin     bool   `json:"isAdmin"`
}

func (h *AdminHandler) CreateUser(w http.ResponseWriter, r *http.Request) {
	user, ok := auth.UserFromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	isAdmin, err := h.store.IsAdmin(r.Context(), user.UserID)
	if err != nil || !isAdmin {
		writeError(w, http.StatusForbidden, "admin required")
		return
	}

	var req createUserRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid json")
		return
	}
	req.Email = strings.TrimSpace(strings.ToLower(req.Email))
	req.DisplayName = strings.TrimSpace(req.DisplayName)
	if req.Email == "" || req.DisplayName == "" || req.Password == "" {
		writeError(w, http.StatusBadRequest, "email, displayName and password required")
		return
	}
	if len(req.Password) < 8 {
		writeError(w, http.StatusBadRequest, "password must be at least 8 characters")
		return
	}

	hash, err := auth.HashPassword(req.Password)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "password hash failed")
		return
	}

	created, err := h.store.CreateUser(r.Context(), req.Email, req.DisplayName, hash)
	if err != nil {
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23505" {
			writeError(w, http.StatusConflict, "email already exists")
			return
		}
		writeError(w, http.StatusInternalServerError, "create user failed")
		return
	}
	if req.IsAdmin {
		if err := h.store.SetUserAdmin(r.Context(), created.ID, true); err != nil {
			writeError(w, http.StatusInternalServerError, "set admin flag failed")
			return
		}
		created.IsAdmin = true
	}
	writeJSON(w, http.StatusCreated, created)
}

func (h *AdminHandler) ListUsers(w http.ResponseWriter, r *http.Request) {
	user, ok := auth.UserFromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	isAdmin, err := h.store.IsAdmin(r.Context(), user.UserID)
	if err != nil || !isAdmin {
		writeError(w, http.StatusForbidden, "admin required")
		return
	}

	users, err := h.store.ListUsers(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, "list users failed")
		return
	}
	if users == nil {
		users = []domain.User{}
	}
	writeJSON(w, http.StatusOK, users)
}
