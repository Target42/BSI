package httpx

import (
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
	"testing"
	"time"

	"github.com/Target42/BSI/isms-server/internal/auth"
	"github.com/Target42/BSI/isms-server/internal/domain"
	"github.com/Target42/BSI/isms-server/internal/repository"
)

func TestRegisterPageAndShortPassword(t *testing.T) {
	handler := NewServer(auth.NewService("test-secret", time.Hour), nil, "").Router()

	req := httptest.NewRequest(http.MethodGet, "/register", nil)
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("GET /register status %d", rec.Code)
	}
	body := rec.Body.String()
	for _, want := range []string{"Konto anlegen", "Registrieren", `action="/register"`, "csrf_token"} {
		if !strings.Contains(body, want) {
			t.Fatalf("register page missing %q", want)
		}
	}

	login := httptest.NewRequest(http.MethodGet, "/login", nil)
	loginRec := httptest.NewRecorder()
	handler.ServeHTTP(loginRec, login)
	if !strings.Contains(loginRec.Body.String(), "Noch kein Konto? Registrieren") {
		t.Fatal("login page missing register link")
	}

	token, cookie := csrfFromLogin(t, handler)
	form := url.Values{}
	form.Set("csrf_token", token)
	form.Set("email", "ada@example.com")
	form.Set("displayName", "Ada")
	form.Set("password", "short")
	post := httptest.NewRequest(http.MethodPost, "/register", strings.NewReader(form.Encode()))
	post.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	post.AddCookie(cookie)
	postRec := httptest.NewRecorder()
	handler.ServeHTTP(postRec, post)
	if postRec.Code != http.StatusOK {
		t.Fatalf("short password status %d body %s", postRec.Code, postRec.Body.String())
	}
	if !strings.Contains(postRec.Body.String(), "mindestens 8 Zeichen") {
		t.Fatalf("expected password hint, body %s", postRec.Body.String())
	}
}

func TestJoinPageRejectsBadToken(t *testing.T) {
	handler := NewServer(auth.NewService("test-secret", time.Hour), nil, "/isms").Router()
	req := httptest.NewRequest(http.MethodGet, "/join/not-a-token", nil)
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("status %d", rec.Code)
	}
	if !strings.Contains(rec.Body.String(), "ungültig") {
		t.Fatalf("body %s", rec.Body.String())
	}
	if !strings.Contains(rec.Body.String(), `href="/isms/ui/app.css"`) {
		t.Fatal("join page should use the public base")
	}
}

func TestJoinTokenFromPath(t *testing.T) {
	token := strings.Repeat("ab", 32)
	got, ok := joinTokenFromPath("/join/" + token + "?error=1")
	if !ok || got != token {
		t.Fatalf("token %q ok %v", got, ok)
	}
	if _, ok := joinTokenFromPath("/join/" + token + "/extra"); ok {
		t.Fatal("extra path segment must not be an invite")
	}
	if _, ok := joinTokenFromPath("/projects/1"); ok {
		t.Fatal("project path must not be an invite")
	}
	upper, ok := normalizeInviteToken(strings.ToUpper(token))
	if !ok || upper != token {
		t.Fatalf("normalize %q ok %v", upper, ok)
	}
}

func TestSignupValidation(t *testing.T) {
	if _, ok := normalizeSignupEmail("Ada@Example.com"); !ok {
		t.Fatal("email")
	}
	email, ok := normalizeSignupEmail("  Ada@Example.com ")
	if !ok || email != "ada@example.com" {
		t.Fatalf("normalized %q ok %v", email, ok)
	}
	if _, ok := normalizeSignupEmail("not-an-email"); ok {
		t.Fatal("missing @")
	}
	name, ok := normalizeSignupName("  Ada Lovelace  ")
	if !ok || name != "Ada Lovelace" {
		t.Fatalf("name %q", name)
	}
	if _, ok := normalizeSignupName("Zeile\nZwei"); ok {
		t.Fatal("newline in name")
	}
	if validInviteRole("owner") || !validInviteRole("viewer") {
		t.Fatal("invite roles")
	}
}

func TestMembersPageShowsInviteFormForOwner(t *testing.T) {
	ui := newWebUI(auth.NewService("test-secret", time.Hour), nil, nil, "", nil)
	token := strings.Repeat("cd", 32)
	page := webPage{
		CanOwn:      true,
		Project:     domain.Project{ID: 7, Name: "Probe"},
		MemberRoles: webMemberRoles,
		InviteRoles: webInviteRoles,
		Invites: []webInvite{{
			ProjectInvite: repository.ProjectInvite{ID: 3, Role: "editor", Token: token},
			URL:           "https://isms.example/join/" + token,
		}},
	}
	body := executeTemplate(t, ui, "members", page)
	for _, want := range []string{"Einladungslink", "Link erzeugen", "https://isms.example/join/" + token, "/projects/7/invites/3/revoke"} {
		if !strings.Contains(body, want) {
			t.Fatalf("members missing %q", want)
		}
	}
	ownerOnly := executeTemplate(t, ui, "members", webPage{Project: domain.Project{ID: 7, Name: "Probe"}})
	if strings.Contains(ownerOnly, "Link erzeugen") {
		t.Fatal("readers must not create invite links")
	}
}

func executeTemplate(t *testing.T, ui *webUI, name string, page webPage) string {
	t.Helper()
	var buf strings.Builder
	if err := ui.tmpl.ExecuteTemplate(&buf, name, page); err != nil {
		t.Fatal(err)
	}
	return buf.String()
}
