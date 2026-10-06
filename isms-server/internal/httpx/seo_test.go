package httpx

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/Target42/BSI/isms-server/internal/auth"
)

func TestPublicPagesAreIndexable(t *testing.T) {
	t.Setenv("MAIL_PUBLIC_URL", "https://isms.example.com")
	handler := NewServer(auth.NewService("test-secret", time.Hour), nil, "").Router()

	home := httptest.NewRecorder()
	handler.ServeHTTP(home, httptest.NewRequest(http.MethodGet, "/", nil))
	if home.Code != http.StatusOK {
		t.Fatalf("home status %d", home.Code)
	}
	body := home.Body.String()
	for _, want := range []string{
		"<title>" + seoHomeTitle + "</title>",
		seoHomeDescription,
		`rel="canonical" href="https://isms.example.com/"`,
		`property="og:title"`,
		"Grundschutz-Verbund gemeinsam bearbeiten",
	} {
		if !strings.Contains(body, want) {
			t.Fatalf("home missing %q", want)
		}
	}
	if strings.Contains(body, "noindex") {
		t.Fatalf("anonymous home must be indexable: %s", body)
	}
	if home.Header().Get("X-Robots-Tag") != "" {
		t.Fatalf("anonymous home robots header %q", home.Header().Get("X-Robots-Tag"))
	}

	login := httptest.NewRecorder()
	handler.ServeHTTP(login, httptest.NewRequest(http.MethodGet, "/login", nil))
	if login.Header().Get("X-Robots-Tag") != "noindex, nofollow" {
		t.Fatalf("login robots %q", login.Header().Get("X-Robots-Tag"))
	}

	robots := httptest.NewRecorder()
	handler.ServeHTTP(robots, httptest.NewRequest(http.MethodGet, "/robots.txt", nil))
	robotsBody := robots.Body.String()
	for _, want := range []string{
		"Disallow: /projects",
		"Disallow: /api/",
		"Allow: /$",
		"Sitemap: https://isms.example.com/sitemap.xml",
	} {
		if !strings.Contains(robotsBody, want) {
			t.Fatalf("robots.txt missing %q\n%s", want, robotsBody)
		}
	}

	sitemap := httptest.NewRecorder()
	handler.ServeHTTP(sitemap, httptest.NewRequest(http.MethodGet, "/sitemap.xml", nil))
	if !strings.Contains(sitemap.Body.String(), "<loc>https://isms.example.com/</loc>") {
		t.Fatalf("sitemap %s", sitemap.Body.String())
	}
	if strings.Contains(sitemap.Body.String(), "/projects") {
		t.Fatalf("sitemap must not list projects: %s", sitemap.Body.String())
	}
}

func TestSitemapUsesPublicPrefix(t *testing.T) {
	t.Setenv("MAIL_PUBLIC_URL", "https://example.com/isms")
	handler := NewServer(auth.NewService("test-secret", time.Hour), nil, "/isms").Router()

	robots := httptest.NewRecorder()
	handler.ServeHTTP(robots, httptest.NewRequest(http.MethodGet, "/robots.txt", nil))
	if !strings.Contains(robots.Body.String(), "Disallow: /isms/projects") {
		t.Fatalf("prefixed robots:\n%s", robots.Body.String())
	}
	if !strings.Contains(robots.Body.String(), "Sitemap: https://example.com/isms/sitemap.xml") {
		t.Fatalf("prefixed sitemap line:\n%s", robots.Body.String())
	}

	sitemap := httptest.NewRecorder()
	handler.ServeHTTP(sitemap, httptest.NewRequest(http.MethodGet, "/sitemap.xml", nil))
	if !strings.Contains(sitemap.Body.String(), "<loc>https://example.com/isms/</loc>") {
		t.Fatalf("prefixed sitemap %s", sitemap.Body.String())
	}
}

func TestLoggedInHomeIsNotIndexable(t *testing.T) {
	ui := newWebUI(auth.NewService("test-secret", time.Hour), nil, nil, "", nil)
	page := webPage{LoggedIn: true}
	ui.applySEO(httptest.NewRequest(http.MethodGet, "/", nil), "home", &page)
	if page.Indexable {
		t.Fatal("task inbox must not be indexable")
	}
}
