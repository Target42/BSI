package httpx

import (
	"net/http"
	"strconv"
	"strings"
	"sync"
	"time"
)

const (
	loginMaxAttempts = 20
	loginWindow      = 15 * time.Minute
)

type loginLimiter struct {
	mu       sync.Mutex
	max      int
	window   time.Duration
	attempts map[string][]time.Time
}

func newLoginLimiter() *loginLimiter {
	return newLoginLimiterN(loginMaxAttempts, loginWindow)
}

func newLoginLimiterN(max int, window time.Duration) *loginLimiter {
	if max < 1 {
		max = loginMaxAttempts
	}
	if window <= 0 {
		window = loginWindow
	}
	return &loginLimiter{max: max, window: window, attempts: map[string][]time.Time{}}
}

func (l *loginLimiter) allow(key string) bool {
	now := time.Now()
	cutoff := now.Add(-l.window)
	l.mu.Lock()
	defer l.mu.Unlock()
	hits := l.attempts[key]
	kept := hits[:0]
	for _, t := range hits {
		if t.After(cutoff) {
			kept = append(kept, t)
		}
	}
	if cap(kept) == 0 {
		kept = nil
	}
	if len(kept) >= l.max {
		l.attempts[key] = kept
		return false
	}
	l.attempts[key] = append(kept, now)
	return true
}

func (l *loginLimiter) Middleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if l == nil {
			next.ServeHTTP(w, r)
			return
		}
		if !l.allow(requestIP(r)) {
			retry := int(l.window.Seconds())
			w.Header().Set("Retry-After", strconv.Itoa(retry))
			if strings.HasPrefix(r.URL.Path, "/api/") {
				writeError(w, http.StatusTooManyRequests, "too many login attempts")
				return
			}
			http.Error(w, "Zu viele Anmeldeversuche. Bitte später erneut versuchen.", http.StatusTooManyRequests)
			return
		}
		next.ServeHTTP(w, r)
	})
}

func (s *Server) limitLogin(next http.Handler) http.Handler {
	if s.limiter == nil {
		s.limiter = newLoginLimiter()
	}
	return s.limiter.Middleware(next)
}
