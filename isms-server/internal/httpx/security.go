package httpx

import (
	"context"
	"crypto/rand"
	"crypto/subtle"
	"encoding/hex"
	"net"
	"net/http"
	"strings"

	"github.com/Target42/BSI/isms-server/internal/auth"
)

type contextKey string

const (
	csrfContextKey   contextKey = "csrf"
	csrfCookieName              = "isms_csrf"
	csrfFieldName               = "csrf_token"
	csrfHeaderName              = "X-CSRF-Token"
	maxJSONBodyBytes            = 1 << 20
)

func (s *Server) SetRuntime(production bool, trustedProxies []*net.IPNet) {
	s.production = production
	s.trustedProxies = trustedProxies
}

func (s *Server) clientIP(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		peer := parseRemoteIP(r.RemoteAddr)
		https := r.TLS != nil
		if peer != nil && ipInNets(peer, s.trustedProxies) {
			if forwarded := forwardedClientIP(r); forwarded != nil {
				r.RemoteAddr = net.JoinHostPort(forwarded.String(), "0")
			}
			if strings.EqualFold(r.Header.Get("X-Forwarded-Proto"), "https") {
				https = true
			}
		}
		ctx := auth.ContextWithHTTPS(r.Context(), https)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

func requestIP(r *http.Request) string {
	ip := parseRemoteIP(r.RemoteAddr)
	if ip == nil {
		return r.RemoteAddr
	}
	return ip.String()
}

func parseRemoteIP(remoteAddr string) net.IP {
	host, _, err := net.SplitHostPort(remoteAddr)
	if err != nil {
		return net.ParseIP(remoteAddr)
	}
	return net.ParseIP(host)
}

func forwardedClientIP(r *http.Request) net.IP {
	if xff := r.Header.Get("X-Forwarded-For"); xff != "" {
		first := strings.TrimSpace(strings.Split(xff, ",")[0])
		if ip := net.ParseIP(first); ip != nil {
			return ip
		}
	}
	if xri := strings.TrimSpace(r.Header.Get("X-Real-IP")); xri != "" {
		if ip := net.ParseIP(xri); ip != nil {
			return ip
		}
	}
	return nil
}

func ipInNets(ip net.IP, nets []*net.IPNet) bool {
	if ip == nil {
		return false
	}
	for _, n := range nets {
		if n != nil && n.Contains(ip) {
			return true
		}
	}
	return false
}

func (s *Server) securityHeaders(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		h := w.Header()
		h.Set("X-Content-Type-Options", "nosniff")
		h.Set("X-Frame-Options", "DENY")
		h.Set("Referrer-Policy", "strict-origin-when-cross-origin")
		h.Set("Permissions-Policy", "camera=(), microphone=(), geolocation=()")
		h.Set("Content-Security-Policy", strings.Join([]string{
			"default-src 'self'",
			"script-src 'self'",
			"style-src 'self' 'unsafe-inline'",
			"img-src 'self' data:",
			"font-src 'self'",
			"connect-src 'self'",
			"frame-ancestors 'none'",
			"base-uri 'self'",
			"form-action 'self'",
		}, "; "))
		if s.production && auth.RequestIsHTTPS(r) {
			h.Set("Strict-Transport-Security", "max-age=31536000; includeSubDomains")
		}
		next.ServeHTTP(w, r)
	})
}

func (s *Server) csrfProtect(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		token := s.ensureCSRFToken(w, r)
		r = r.WithContext(context.WithValue(r.Context(), csrfContextKey, token))
		if csrfSafeMethod(r.Method) || strings.HasPrefix(r.URL.Path, "/api/") {
			next.ServeHTTP(w, r)
			return
		}
		if !csrfTokensMatch(token, submittedCSRFToken(r)) {
			http.Error(w, "Ungültige oder fehlende Sicherheitsprüfung.", http.StatusForbidden)
			return
		}
		next.ServeHTTP(w, r)
	})
}

func csrfSafeMethod(method string) bool {
	switch method {
	case http.MethodGet, http.MethodHead, http.MethodOptions, http.MethodTrace:
		return true
	default:
		return false
	}
}

func csrfTokenFromContext(ctx context.Context) string {
	token, _ := ctx.Value(csrfContextKey).(string)
	return token
}

func (s *Server) csrfCookiePath() string {
	if s.webUI != nil {
		return s.webUI.cookiePath()
	}
	return "/"
}

func (s *Server) ensureCSRFToken(w http.ResponseWriter, r *http.Request) string {
	if c, err := r.Cookie(csrfCookieName); err == nil && validCSRFToken(c.Value) {
		return c.Value
	}
	token := newCSRFToken()
	http.SetCookie(w, &http.Cookie{
		Name:     csrfCookieName,
		Value:    token,
		Path:     s.csrfCookiePath(),
		HttpOnly: true,
		SameSite: http.SameSiteStrictMode,
		Secure:   auth.RequestIsHTTPS(r),
	})
	return token
}

func newCSRFToken() string {
	var buf [32]byte
	if _, err := rand.Read(buf[:]); err != nil {
		panic("csrf rand: " + err.Error())
	}
	return hex.EncodeToString(buf[:])
}

func validCSRFToken(token string) bool {
	if len(token) != 64 {
		return false
	}
	_, err := hex.DecodeString(token)
	return err == nil
}

func submittedCSRFToken(r *http.Request) string {
	if h := strings.TrimSpace(r.Header.Get(csrfHeaderName)); h != "" {
		return h
	}
	limit := int64(maxJSONBodyBytes)
	if strings.HasPrefix(r.Header.Get("Content-Type"), "multipart/") {
		limit = maxCatalogUploadBytes
	}
	r.Body = http.MaxBytesReader(nil, r.Body, limit)
	if strings.HasPrefix(r.Header.Get("Content-Type"), "multipart/") {
		_ = r.ParseMultipartForm(limit)
	} else {
		_ = r.ParseForm()
	}
	return strings.TrimSpace(r.FormValue(csrfFieldName))
}

func csrfTokensMatch(cookie, submitted string) bool {
	if cookie == "" || submitted == "" || len(cookie) != len(submitted) {
		return false
	}
	return subtle.ConstantTimeCompare([]byte(cookie), []byte(submitted)) == 1
}
