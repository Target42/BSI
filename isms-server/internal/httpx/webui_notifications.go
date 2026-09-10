package httpx

import (
	"net/http"
	"strconv"
	"strings"

	"github.com/Target42/BSI/isms-server/internal/auth"
	"github.com/go-chi/chi/v5"
)

func (u *webUI) notificationsGet(w http.ResponseWriter, r *http.Request) {
	user, ok := auth.UserFromContext(r.Context())
	if !ok {
		u.redirectLogin(w, r)
		return
	}
	if u.store == nil {
		u.render(w, r, "notifications", webPage{Title: "Mitteilungen", DisplayName: user.DisplayName})
		return
	}
	items, err := u.store.ListNotifications(r.Context(), user.UserID)
	if err != nil {
		u.render(w, r, "notifications", webPage{
			Title: "Mitteilungen",
			Error: "Mitteilungen konnten nicht geladen werden.",
		})
		return
	}
	notice := ""
	if r.URL.Query().Get("read") == "all" {
		notice = "Alle Mitteilungen als gelesen markiert."
	}
	u.render(w, r, "notifications", webPage{
		Title:         "Mitteilungen",
		DisplayName:   user.DisplayName,
		Email:         user.Email,
		Notice:        notice,
		Notifications: items,
	})
}

func (u *webUI) notificationRead(w http.ResponseWriter, r *http.Request) {
	user, ok := auth.UserFromContext(r.Context())
	if !ok {
		u.redirectLogin(w, r)
		return
	}
	if u.store == nil {
		http.Redirect(w, r, u.href("/notifications"), http.StatusSeeOther)
		return
	}
	notificationID, err := strconv.ParseInt(chi.URLParam(r, "notificationID"), 10, 64)
	if err != nil || notificationID <= 0 {
		http.Redirect(w, r, u.href("/notifications"), http.StatusSeeOther)
		return
	}
	item, err := u.store.GetNotification(r.Context(), user.UserID, notificationID)
	if err != nil {
		http.Redirect(w, r, u.href("/notifications"), http.StatusSeeOther)
		return
	}
	_ = u.store.MarkNotificationRead(r.Context(), user.UserID, notificationID)
	target := u.href("/notifications")
	if path := strings.TrimSpace(item.LinkPath); path != "" {
		target = u.href(path)
	}
	http.Redirect(w, r, target, http.StatusSeeOther)
}

func (u *webUI) notificationsReadAll(w http.ResponseWriter, r *http.Request) {
	user, ok := auth.UserFromContext(r.Context())
	if !ok {
		u.redirectLogin(w, r)
		return
	}
	if u.store == nil {
		http.Redirect(w, r, u.href("/notifications"), http.StatusSeeOther)
		return
	}
	_ = u.store.MarkAllNotificationsRead(r.Context(), user.UserID)
	http.Redirect(w, r, u.href("/notifications?read=all"), http.StatusSeeOther)
}

func (u *webUI) fillUnreadCount(r *http.Request, data *webPage) {
	if u == nil || u.store == nil || r == nil || data == nil || !data.LoggedIn {
		return
	}
	user, ok := auth.UserFromContext(r.Context())
	if !ok {
		return
	}
	count, err := u.store.UnreadNotificationCount(r.Context(), user.UserID)
	if err == nil {
		data.UnreadCount = count
	}
}
