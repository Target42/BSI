package httpx

import (
	"crypto/tls"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"net/url"
	"regexp"
	"strings"
	"testing"
	"time"

	"github.com/Target42/BSI/isms-server/internal/auth"
)

var csrfInputPattern = regexp.MustCompile(`name="csrf_token" value="([a-f0-9]{64})"`)

func csrfFromLogin(t *testing.T, handler http.Handler) (string, *http.Cookie) {
	t.Helper()
	req := httptest.NewRequest(http.MethodGet, "/login", nil)
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("GET /login: %d", rec.Code)
	}
	match := csrfInputPattern.FindStringSubmatch(rec.Body.String())
	if len(match) != 2 {
		t.Fatalf("login page missing csrf field: %s", rec.Body.String())
	}
	var cookie *http.Cookie
	for _, c := range rec.Result().Cookies() {
		if c.Name == csrfCookieName {
			cookie = c
			break
		}
	}
	if cookie == nil {
		t.Fatal("missing csrf cookie")
	}
	if cookie.Value != match[1] {
		t.Fatalf("csrf cookie %q != field %q", cookie.Value, match[1])
	}
	return match[1], cookie
}

func TestSecurityHeadersOnWebAndAPI(t *testing.T) {
	handler := NewServer(auth.NewService("test-secret", time.Hour), nil, "").Router()
	req := httptest.NewRequest(http.MethodGet, "/", nil)
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("status %d", rec.Code)
	}
	h := rec.Header()
	if h.Get("X-Content-Type-Options") != "nosniff" {
		t.Fatalf("nosniff: %q", h.Get("X-Content-Type-Options"))
	}
	if h.Get("X-Frame-Options") != "DENY" {
		t.Fatalf("frame: %q", h.Get("X-Frame-Options"))
	}
	if !strings.Contains(h.Get("Content-Security-Policy"), "frame-ancestors 'none'") {
		t.Fatalf("csp: %q", h.Get("Content-Security-Policy"))
	}
	if h.Get("Referrer-Policy") != "strict-origin-when-cross-origin" {
		t.Fatalf("referrer: %q", h.Get("Referrer-Policy"))
	}
	if h.Get("Strict-Transport-Security") != "" {
		t.Fatal("HSTS must not be set without production HTTPS")
	}

	api := httptest.NewRequest(http.MethodGet, "/api/v1/projects", nil)
	apiRec := httptest.NewRecorder()
	handler.ServeHTTP(apiRec, api)
	if apiRec.Header().Get("X-Content-Type-Options") != "nosniff" {
		t.Fatal("API should also get security headers")
	}
}

func TestHSTSInProductionHTTPS(t *testing.T) {
	server := NewServer(auth.NewService("test-secret", time.Hour), nil, "")
	server.SetRuntime(true, nil)
	handler := server.Router()
	req := httptest.NewRequest(http.MethodGet, "/health", nil)
	req.TLS = &tls.ConnectionState{}
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)
	if rec.Header().Get("Strict-Transport-Security") == "" {
		t.Fatal("expected HSTS in production TLS")
	}
}

func TestCSRFRejectsWebPOSTWithoutToken(t *testing.T) {
	handler := NewServer(auth.NewService("test-secret", time.Hour), nil, "").Router()
	req := httptest.NewRequest(http.MethodPost, "/login", strings.NewReader("email=a@b.c&password=x"))
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)
	if rec.Code != http.StatusForbidden {
		t.Fatalf("status %d want 403", rec.Code)
	}
}

func TestCSRFAllowsLoginPOSTWithToken(t *testing.T) {
	handler := NewServer(auth.NewService("test-secret", time.Hour), nil, "").Router()
	token, cookie := csrfFromLogin(t, handler)
	form := url.Values{}
	form.Set("csrf_token", token)
	form.Set("email", "nobody@example.com")
	form.Set("password", "wrong")
	req := httptest.NewRequest(http.MethodPost, "/login", strings.NewReader(form.Encode()))
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	req.AddCookie(cookie)
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("status %d body %q", rec.Code, rec.Body.String())
	}
	if !strings.Contains(rec.Body.String(), "E-Mail oder Passwort ist falsch") {
		t.Fatalf("expected login error, body %q", rec.Body.String())
	}
}

func TestAPILoginSkipsCSRF(t *testing.T) {
	handler := NewServer(auth.NewService("test-secret", time.Hour), nil, "").Router()
	req := httptest.NewRequest(http.MethodPost, "/api/v1/auth/login", strings.NewReader(`{"email":"a@b.c","password":"x"}`))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)
	if rec.Code == http.StatusForbidden {
		t.Fatal("API login must not require CSRF")
	}
	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("status %d body %q", rec.Code, rec.Body.String())
	}
}

func TestLoginRateLimit(t *testing.T) {
	server := NewServer(auth.NewService("test-secret", time.Hour), nil, "")
	server.limiter = newLoginLimiterN(3, time.Minute)
	handler := server.Router()
	body := `{"email":"a@b.c","password":"x"}`
	for i := 0; i < 3; i++ {
		req := httptest.NewRequest(http.MethodPost, "/api/v1/auth/login", strings.NewReader(body))
		req.Header.Set("Content-Type", "application/json")
		rec := httptest.NewRecorder()
		handler.ServeHTTP(rec, req)
		if rec.Code == http.StatusTooManyRequests {
			t.Fatalf("attempt %d already limited", i+1)
		}
	}
	req := httptest.NewRequest(http.MethodPost, "/api/v1/auth/login", strings.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)
	if rec.Code != http.StatusTooManyRequests {
		t.Fatalf("status %d want 429 body %q", rec.Code, rec.Body.String())
	}
	if rec.Header().Get("Retry-After") == "" {
		t.Fatal("missing Retry-After")
	}
}

func TestTrustedProxySetsClientIPAndHSTS(t *testing.T) {
	_, network, err := net.ParseCIDR("192.0.2.1/32")
	if err != nil {
		t.Fatal(err)
	}
	server := NewServer(auth.NewService("test-secret", time.Hour), nil, "")
	server.SetRuntime(true, []*net.IPNet{network})
	handler := server.Router()
	req := httptest.NewRequest(http.MethodGet, "/health", nil)
	req.Header.Set("X-Forwarded-For", "203.0.113.50")
	req.Header.Set("X-Forwarded-Proto", "https")
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)
	if rec.Header().Get("Strict-Transport-Security") == "" {
		t.Fatal("expected HSTS from trusted X-Forwarded-Proto")
	}
}

func TestUntrustedForwardedProtoDoesNotEnableHSTS(t *testing.T) {
	server := NewServer(auth.NewService("test-secret", time.Hour), nil, "")
	server.SetRuntime(true, nil)
	handler := server.Router()
	req := httptest.NewRequest(http.MethodGet, "/health", nil)
	req.Header.Set("X-Forwarded-Proto", "https")
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)
	if rec.Header().Get("Strict-Transport-Security") != "" {
		t.Fatal("untrusted X-Forwarded-Proto must not trigger HSTS")
	}
}

func TestJSONBodyLimit(t *testing.T) {
	handler := NewServer(auth.NewService("test-secret", time.Hour), nil, "").Router()
	huge := strings.Repeat("a", maxJSONBodyBytes+8)
	req := httptest.NewRequest(http.MethodPost, "/api/v1/auth/login", strings.NewReader(`{"email":"`+huge+`","password":"x"}`))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)
	if rec.Code == http.StatusOK {
		t.Fatal("oversized JSON must fail")
	}
	_, _ = io.Copy(io.Discard, rec.Result().Body)
}

func TestAppJSServed(t *testing.T) {
	handler := NewServer(auth.NewService("test-secret", time.Hour), nil, "").Router()
	req := httptest.NewRequest(http.MethodGet, "/ui/app.js", nil)
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK || !strings.Contains(rec.Body.String(), "data-print") {
		t.Fatalf("app.js status %d body %q", rec.Code, rec.Body.String())
	}
}
