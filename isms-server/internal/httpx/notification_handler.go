package httpx

import (
	"net/http"
	"strconv"

	"github.com/Target42/BSI/isms-server/internal/auth"
	"github.com/Target42/BSI/isms-server/internal/domain"
	"github.com/Target42/BSI/isms-server/internal/repository"
	"github.com/go-chi/chi/v5"
)

type NotificationHandler struct {
	store *repository.Store
}

func NewNotificationHandler(store *repository.Store) *NotificationHandler {
	return &NotificationHandler{store: store}
}

func (h *NotificationHandler) List(w http.ResponseWriter, r *http.Request) {
	user, ok := auth.UserFromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	if h == nil || h.store == nil {
		writeJSON(w, http.StatusOK, []domain.Notification{})
		return
	}
	items, err := h.store.ListNotifications(r.Context(), user.UserID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "list notifications failed")
		return
	}
	if items == nil {
		items = []domain.Notification{}
	}
	writeJSON(w, http.StatusOK, items)
}

func (h *NotificationHandler) MarkRead(w http.ResponseWriter, r *http.Request) {
	user, ok := auth.UserFromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	if h == nil || h.store == nil {
		writeError(w, http.StatusInternalServerError, "unavailable")
		return
	}
	notificationID, err := strconv.ParseInt(chi.URLParam(r, "notificationID"), 10, 64)
	if err != nil || notificationID <= 0 {
		writeError(w, http.StatusBadRequest, "invalid notification id")
		return
	}
	if err := h.store.MarkNotificationRead(r.Context(), user.UserID, notificationID); err != nil {
		if mapRepoError(w, err) {
			return
		}
		writeError(w, http.StatusInternalServerError, "mark notification read failed")
		return
	}
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

func (h *NotificationHandler) MarkAllRead(w http.ResponseWriter, r *http.Request) {
	user, ok := auth.UserFromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	if h == nil || h.store == nil {
		writeError(w, http.StatusInternalServerError, "unavailable")
		return
	}
	if err := h.store.MarkAllNotificationsRead(r.Context(), user.UserID); err != nil {
		writeError(w, http.StatusInternalServerError, "mark notifications read failed")
		return
	}
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}
