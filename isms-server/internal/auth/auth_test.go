package auth

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

type stubVersions struct {
	version int
	err     error
}

func (s stubVersions) TokenVersion(context.Context, int64) (int, error) {
	return s.version, s.err
}

func TestCreateTokenStoresVersion(t *testing.T) {
	svc := NewService("test-secret-at-least-32-chars!!", time.Hour)
	pair, err := svc.CreateToken(7, "a@b.c", "Ada", 3)
	if err != nil {
		t.Fatal(err)
	}
	claims, err := svc.ParseToken(pair.AccessToken)
	if err != nil {
		t.Fatal(err)
	}
	if claims.UserID != 7 || claims.TokenVersion != 3 {
		t.Fatalf("%+v", claims)
	}
}

func TestAuthenticateRejectsStaleVersion(t *testing.T) {
	svc := NewService("test-secret-at-least-32-chars!!", time.Hour)
	svc.SetTokenVersions(stubVersions{version: 2})
	pair, err := svc.CreateToken(1, "a@b.c", "Ada", 1)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := svc.Authenticate(context.Background(), pair.AccessToken); !errors.Is(err, ErrSessionRevoked) {
		t.Fatalf("err=%v", err)
	}
}

func TestAuthenticateAcceptsCurrentVersion(t *testing.T) {
	svc := NewService("test-secret-at-least-32-chars!!", time.Hour)
	svc.SetTokenVersions(stubVersions{version: 4})
	pair, err := svc.CreateToken(1, "a@b.c", "Ada", 4)
	if err != nil {
		t.Fatal(err)
	}
	claims, err := svc.Authenticate(context.Background(), pair.AccessToken)
	if err != nil || claims.TokenVersion != 4 {
		t.Fatalf("claims=%+v err=%v", claims, err)
	}
}

func TestMiddlewareRejectsRevokedSession(t *testing.T) {
	svc := NewService("test-secret-at-least-32-chars!!", time.Hour)
	pair, err := svc.CreateToken(1, "a@b.c", "Ada", 1)
	if err != nil {
		t.Fatal(err)
	}
	svc.SetTokenVersions(stubVersions{version: 2})
	handler := svc.Middleware(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusNoContent)
	}))
	req := httptest.NewRequest(http.MethodGet, "/api/v1/auth/me", nil)
	req.Header.Set("Authorization", "Bearer "+pair.AccessToken)
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)
	if rec.Code != http.StatusUnauthorized || !strings.Contains(rec.Body.String(), "session_revoked") {
		t.Fatalf("status %d body %q", rec.Code, rec.Body.String())
	}
}

func TestNewServiceDefaultTTL(t *testing.T) {
	svc := NewService("secret", 0)
	if svc.TokenTTL() != 8*time.Hour {
		t.Fatalf("ttl %s", svc.TokenTTL())
	}
}
