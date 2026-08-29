package auth

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"golang.org/x/crypto/bcrypt"
)

type TokenPair struct {
	AccessToken string
	ExpiresAt   time.Time
}

var ErrSessionRevoked = errors.New("session revoked")

type Claims struct {
	UserID       int64  `json:"uid"`
	Email        string `json:"email"`
	DisplayName  string `json:"displayName"`
	TokenVersion int    `json:"tv"`
	jwt.RegisteredClaims
}

type contextKey string

const userContextKey contextKey = "user"
const httpsContextKey contextKey = "forwardedHTTPS"

type TokenVersionLookup interface {
	TokenVersion(ctx context.Context, userID int64) (int, error)
}

type Service struct {
	secret   []byte
	ttl      time.Duration
	versions TokenVersionLookup
}

func NewService(secret string, ttl time.Duration) *Service {
	if ttl <= 0 {
		ttl = 8 * time.Hour
	}
	return &Service{secret: []byte(secret), ttl: ttl}
}

func (s *Service) SetTokenVersions(lookup TokenVersionLookup) {
	s.versions = lookup
}

func (s *Service) TokenTTL() time.Duration {
	return s.ttl
}

func HashPassword(password string) (string, error) {
	hash, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		return "", err
	}
	return string(hash), nil
}

func CheckPassword(hash, password string) bool {
	return bcrypt.CompareHashAndPassword([]byte(hash), []byte(password)) == nil
}

func (s *Service) CreateToken(userID int64, email, displayName string, tokenVersion int) (TokenPair, error) {
	now := time.Now()
	expiresAt := now.Add(s.ttl)
	claims := Claims{
		UserID:       userID,
		Email:        email,
		DisplayName:  displayName,
		TokenVersion: tokenVersion,
		RegisteredClaims: jwt.RegisteredClaims{
			Subject:   fmt.Sprintf("%d", userID),
			IssuedAt:  jwt.NewNumericDate(now),
			ExpiresAt: jwt.NewNumericDate(expiresAt),
		},
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	signed, err := token.SignedString(s.secret)
	if err != nil {
		return TokenPair{}, err
	}
	return TokenPair{AccessToken: signed, ExpiresAt: expiresAt}, nil
}

func (s *Service) ParseToken(tokenString string) (*Claims, error) {
	token, err := jwt.ParseWithClaims(tokenString, &Claims{}, func(token *jwt.Token) (any, error) {
		if token.Method != jwt.SigningMethodHS256 {
			return nil, fmt.Errorf("unexpected signing method")
		}
		return s.secret, nil
	})
	if err != nil {
		return nil, err
	}
	claims, ok := token.Claims.(*Claims)
	if !ok || !token.Valid {
		return nil, errors.New("invalid token")
	}
	return claims, nil
}

func (s *Service) Authenticate(ctx context.Context, tokenString string) (*Claims, error) {
	claims, err := s.ParseToken(tokenString)
	if err != nil {
		return nil, err
	}
	if s.versions == nil {
		return claims, nil
	}
	version, err := s.versions.TokenVersion(ctx, claims.UserID)
	if err != nil || version != claims.TokenVersion {
		return nil, ErrSessionRevoked
	}
	return claims, nil
}

func (s *Service) Middleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		header := r.Header.Get("Authorization")
		if !strings.HasPrefix(header, "Bearer ") {
			http.Error(w, `{"error":"missing bearer token"}`, http.StatusUnauthorized)
			return
		}
		claims, err := s.Authenticate(r.Context(), strings.TrimPrefix(header, "Bearer "))
		if err != nil {
			if errors.Is(err, jwt.ErrTokenExpired) {
				http.Error(w, `{"error":"token_expired"}`, http.StatusUnauthorized)
				return
			}
			if errors.Is(err, ErrSessionRevoked) {
				http.Error(w, `{"error":"session_revoked"}`, http.StatusUnauthorized)
				return
			}
			http.Error(w, `{"error":"invalid token"}`, http.StatusUnauthorized)
			return
		}
		ctx := context.WithValue(r.Context(), userContextKey, claims)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

const SessionCookieName = "isms_session"

func cookieSecure(r *http.Request) bool {
	return RequestIsHTTPS(r)
}

func RequestIsHTTPS(r *http.Request) bool {
	if r.TLS != nil {
		return true
	}
	v, _ := r.Context().Value(httpsContextKey).(bool)
	return v
}

func ContextWithHTTPS(ctx context.Context, https bool) context.Context {
	return context.WithValue(ctx, httpsContextKey, https)
}

func (s *Service) SetSessionCookie(w http.ResponseWriter, r *http.Request, token string, expires time.Time, path string) {
	if path == "" {
		path = "/"
	}
	maxAge := int(time.Until(expires).Seconds())
	if maxAge < 1 {
		maxAge = 1
	}
	http.SetCookie(w, &http.Cookie{
		Name:     SessionCookieName,
		Value:    token,
		Path:     path,
		Expires:  expires,
		MaxAge:   maxAge,
		HttpOnly: true,
		SameSite: http.SameSiteLaxMode,
		Secure:   cookieSecure(r),
	})
}

func ClearSessionCookie(w http.ResponseWriter, path string) {
	if path == "" {
		path = "/"
	}
	http.SetCookie(w, &http.Cookie{
		Name:     SessionCookieName,
		Value:    "",
		Path:     path,
		MaxAge:   -1,
		HttpOnly: true,
		SameSite: http.SameSiteLaxMode,
	})
}

func (s *Service) ClaimsFromCookie(r *http.Request) (*Claims, error) {
	c, err := r.Cookie(SessionCookieName)
	if err != nil {
		return nil, err
	}
	if c.Value == "" {
		return nil, http.ErrNoCookie
	}
	return s.Authenticate(r.Context(), c.Value)
}

func ContextWithUser(ctx context.Context, claims *Claims) context.Context {
	return context.WithValue(ctx, userContextKey, claims)
}

func UserFromContext(ctx context.Context) (*Claims, bool) {
	claims, ok := ctx.Value(userContextKey).(*Claims)
	return claims, ok
}
