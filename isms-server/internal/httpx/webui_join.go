package httpx

import (
	"encoding/hex"
	"errors"
	"fmt"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"unicode/utf8"

	"github.com/Target42/BSI/isms-server/internal/auth"
	"github.com/Target42/BSI/isms-server/internal/repository"
	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgconn"
)

func (u *webUI) finishSession(w http.ResponseWriter, r *http.Request, userID int64, token auth.TokenPair, next string) {
	u.auth.SetSessionCookie(w, r, token.AccessToken, token.ExpiresAt, u.cookiePath())
	next = safeNextPath(next)
	if inviteToken, ok := joinTokenFromPath(next); ok && u.store != nil {
		projectID, already, err := u.store.AcceptProjectInvite(r.Context(), inviteToken, userID)
		if err == nil {
			flag := "1"
			if already {
				flag = "member"
			}
			http.Redirect(w, r, u.href(fmt.Sprintf("/projects/%d?joined=%s", projectID, flag)), http.StatusSeeOther)
			return
		}
		http.Redirect(w, r, u.href("/join/"+inviteToken+"?error=1"), http.StatusSeeOther)
		return
	}
	if next == "" {
		next = "/"
	}
	http.Redirect(w, r, u.href(next), http.StatusSeeOther)
}

func (u *webUI) registerGet(w http.ResponseWriter, r *http.Request) {
	next := safeNextPath(r.URL.Query().Get("next"))
	if _, ok := auth.UserFromContext(r.Context()); ok {
		if next == "" {
			next = "/"
		}
		http.Redirect(w, r, u.href(next), http.StatusSeeOther)
		return
	}
	u.renderRegister(w, r, "", "", next, "")
}

func (u *webUI) registerPost(w http.ResponseWriter, r *http.Request) {
	if err := r.ParseForm(); err != nil {
		u.renderRegister(w, r, "", "", "", "Ungültige Anfrage.")
		return
	}
	next := safeNextPath(r.FormValue("next"))
	if _, ok := auth.UserFromContext(r.Context()); ok {
		if next == "" {
			next = "/"
		}
		http.Redirect(w, r, u.href(next), http.StatusSeeOther)
		return
	}
	rawEmail := strings.TrimSpace(r.FormValue("email"))
	rawName := strings.TrimSpace(r.FormValue("displayName"))
	password := r.FormValue("password")
	email, emailOK := normalizeSignupEmail(rawEmail)
	name, nameOK := normalizeSignupName(rawName)
	if !emailOK || !nameOK || password == "" {
		u.renderRegister(w, r, rawEmail, rawName, next, "E-Mail, Name und Passwort sind erforderlich.")
		return
	}
	if len(password) < 8 {
		u.renderRegister(w, r, email, name, next, "Das Passwort muss mindestens 8 Zeichen haben.")
		return
	}
	if len(password) > 72 {
		u.renderRegister(w, r, email, name, next, "Das Passwort darf höchstens 72 Zeichen haben.")
		return
	}
	if u.store == nil {
		u.renderRegister(w, r, email, name, next, "Registrierung ist derzeit nicht möglich.")
		return
	}
	if _, _, err := u.store.FindUserByEmail(r.Context(), email); err == nil {
		u.renderRegister(w, r, email, name, next, "Diese E-Mail ist bereits registriert. Melden Sie sich an.")
		return
	} else if !errors.Is(err, repository.ErrNotFound) {
		u.renderRegister(w, r, email, name, next, "Konto konnte nicht angelegt werden.")
		return
	}
	hash, err := auth.HashPassword(password)
	if err != nil {
		u.renderRegister(w, r, email, name, next, "Konto konnte nicht angelegt werden.")
		return
	}
	created, err := u.store.CreateUser(r.Context(), email, name, hash)
	if err != nil {
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23505" {
			u.renderRegister(w, r, email, name, next, "Diese E-Mail ist bereits registriert. Melden Sie sich an.")
			return
		}
		u.renderRegister(w, r, email, name, next, "Konto konnte nicht angelegt werden.")
		return
	}
	token, err := u.auth.CreateToken(created.ID, created.Email, created.DisplayName, created.TokenVersion)
	if err != nil {
		u.renderRegister(w, r, email, name, next, "Konto angelegt, Anmeldung fehlgeschlagen.")
		return
	}
	u.finishSession(w, r, created.ID, token, next)
}

func (u *webUI) renderRegister(w http.ResponseWriter, r *http.Request, email, name, next, errMsg string) {
	u.render(w, r, "register", webPage{
		Title:       "Registrieren",
		Email:       email,
		DisplayName: name,
		NextPath:    next,
		Error:       errMsg,
	})
}

func (u *webUI) joinGet(w http.ResponseWriter, r *http.Request) {
	token, ok := normalizeInviteToken(chi.URLParam(r, "token"))
	page := webPage{Title: "Einladung"}
	if !ok {
		page.Error = "Dieser Einladungslink ist ungültig."
		u.render(w, r, "join", page)
		return
	}
	page.InviteToken = token
	page.NextPath = "/join/" + token
	if r.URL.Query().Get("error") == "1" {
		page.Error = "Die Einladung konnte nicht angenommen werden."
	}
	if u.store == nil {
		page.Error = "Dieser Einladungslink ist ungültig oder wurde widerrufen."
		u.render(w, r, "join", page)
		return
	}
	invite, project, err := u.store.FindActiveProjectInvite(r.Context(), token)
	if err != nil {
		page.Error = "Dieser Einladungslink ist ungültig oder wurde widerrufen."
		page.Project.Name = ""
		u.render(w, r, "join", page)
		return
	}
	page.InviteRole = invite.Role
	page.Project = project
	u.render(w, r, "join", page)
}

func (u *webUI) joinPost(w http.ResponseWriter, r *http.Request) {
	token, ok := normalizeInviteToken(chi.URLParam(r, "token"))
	if !ok {
		http.NotFound(w, r)
		return
	}
	user, loggedIn := auth.UserFromContext(r.Context())
	if !loggedIn {
		http.Redirect(w, r, u.href("/login?next="+url.QueryEscape("/join/"+token)), http.StatusSeeOther)
		return
	}
	if u.store == nil {
		http.NotFound(w, r)
		return
	}
	projectID, already, err := u.store.AcceptProjectInvite(r.Context(), token, user.UserID)
	if err != nil {
		http.Redirect(w, r, u.href("/join/"+token+"?error=1"), http.StatusSeeOther)
		return
	}
	flag := "1"
	if already {
		flag = "member"
	}
	http.Redirect(w, r, u.href(fmt.Sprintf("/projects/%d?joined=%s", projectID, flag)), http.StatusSeeOther)
}

func (u *webUI) inviteCreate(w http.ResponseWriter, r *http.Request) {
	user, project, role, ok := u.projectAccess(w, r, "owner")
	if !ok {
		return
	}
	if err := r.ParseForm(); err != nil {
		u.renderMembers(w, r, user, project, role, "Ungültige Anfrage.", "")
		return
	}
	memberRole := strings.TrimSpace(r.FormValue("role"))
	if memberRole == "" {
		memberRole = "editor"
	}
	if !validInviteRole(memberRole) {
		u.renderMembers(w, r, user, project, role, "Eine Einladung kann Bearbeiter, Prüfer oder Leser sein.", "")
		return
	}
	if _, err := u.store.CreateProjectInvite(r.Context(), project.ID, user.UserID, memberRole); err != nil {
		u.renderMembers(w, r, user, project, role, "Einladungslink konnte nicht erzeugt werden.", "")
		return
	}
	http.Redirect(w, r, u.href(fmt.Sprintf("/projects/%d/members?saved=invite", project.ID)), http.StatusSeeOther)
}

func (u *webUI) inviteRevoke(w http.ResponseWriter, r *http.Request) {
	user, project, role, ok := u.projectAccess(w, r, "owner")
	if !ok {
		return
	}
	inviteID, err := strconv.ParseInt(chi.URLParam(r, "inviteID"), 10, 64)
	if err != nil || inviteID <= 0 {
		http.NotFound(w, r)
		return
	}
	if err := u.store.RevokeProjectInvite(r.Context(), project.ID, inviteID); err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			u.renderMembers(w, r, user, project, role, "Einladungslink nicht gefunden.", "")
			return
		}
		u.renderMembers(w, r, user, project, role, "Einladungslink konnte nicht widerrufen werden.", "")
		return
	}
	http.Redirect(w, r, u.href(fmt.Sprintf("/projects/%d/members?saved=revoked", project.ID)), http.StatusSeeOther)
}

func (u *webUI) projectInvites(r *http.Request, projectID int64, role string) ([]webInvite, error) {
	if !roleCanOwn(role) || u.store == nil {
		return nil, nil
	}
	rows, err := u.store.ListActiveProjectInvites(r.Context(), projectID)
	if err != nil {
		return nil, err
	}
	out := make([]webInvite, 0, len(rows))
	for _, row := range rows {
		out = append(out, webInvite{
			ProjectInvite: row,
			URL:           externalURL(r, u.href("/join/"+row.Token)),
		})
	}
	return out, nil
}

func externalURL(r *http.Request, path string) string {
	if r == nil || r.Host == "" {
		return path
	}
	scheme := "http"
	if auth.RequestIsHTTPS(r) {
		scheme = "https"
	}
	return scheme + "://" + r.Host + path
}

func validInviteRole(role string) bool {
	switch role {
	case "editor", "reviewer", "viewer":
		return true
	default:
		return false
	}
}

func normalizeSignupEmail(raw string) (string, bool) {
	email := strings.TrimSpace(strings.ToLower(raw))
	if len(email) < 3 || len(email) > 254 || strings.ContainsAny(email, " \t\r\n") {
		return "", false
	}
	at := strings.Index(email, "@")
	if at <= 0 || at != strings.LastIndex(email, "@") || at == len(email)-1 {
		return "", false
	}
	return email, true
}

func normalizeSignupName(raw string) (string, bool) {
	name := strings.TrimSpace(raw)
	if name == "" || utf8.RuneCountInString(name) > 200 || strings.ContainsAny(name, "\r\n\x00") {
		return "", false
	}
	return name, true
}

func normalizeInviteToken(raw string) (string, bool) {
	token := strings.TrimSpace(raw)
	if len(token) != 64 {
		return "", false
	}
	if _, err := hex.DecodeString(token); err != nil {
		return "", false
	}
	return strings.ToLower(token), true
}

func joinTokenFromPath(raw string) (string, bool) {
	path := strings.TrimSpace(raw)
	if i := strings.IndexAny(path, "?#"); i >= 0 {
		path = path[:i]
	}
	const prefix = "/join/"
	if !strings.HasPrefix(path, prefix) {
		return "", false
	}
	token := path[len(prefix):]
	if strings.Contains(token, "/") {
		return "", false
	}
	return normalizeInviteToken(token)
}
