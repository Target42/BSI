package httpx

import (
	"net/http"
	"strconv"

	"github.com/Target42/BSI/isms-server/internal/domain"
	"github.com/Target42/BSI/isms-server/internal/repository"
	"github.com/go-chi/chi/v5"
)

type CatalogHandler struct {
	store *repository.Store
}

func NewCatalogHandler(store *repository.Store) *CatalogHandler {
	return &CatalogHandler{store: store}
}

func (h *CatalogHandler) ListVersions(w http.ResponseWriter, r *http.Request) {
	versions, err := h.store.ListCatalogVersions(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, "list catalog versions failed")
		return
	}
	if versions == nil {
		versions = []string{}
	}
	writeJSON(w, http.StatusOK, versions)
}

func (h *CatalogHandler) ListBausteine(w http.ResponseWriter, r *http.Request) {
	version := chi.URLParam(r, "version")
	if version == "" {
		writeError(w, http.StatusBadRequest, "catalog version required")
		return
	}
	standard := r.URL.Query().Get("standard")
	if standard == "" {
		standard = "IT-Grundschutz"
	}

	items, err := h.store.ListBausteine(r.Context(), standard, version)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "list bausteine failed")
		return
	}
	if items == nil {
		items = []domain.Baustein{}
	}
	writeJSON(w, http.StatusOK, items)
}

func (h *CatalogHandler) ListRequirements(w http.ResponseWriter, r *http.Request) {
	bausteinID, err := strconv.ParseInt(chi.URLParam(r, "bausteinID"), 10, 64)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid baustein id")
		return
	}

	items, err := h.store.ListRequirements(r.Context(), bausteinID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "list requirements failed")
		return
	}
	if items == nil {
		items = []domain.Requirement{}
	}
	writeJSON(w, http.StatusOK, items)
}
