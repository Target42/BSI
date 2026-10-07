package httpx

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/Target42/BSI/isms-server/internal/auth"
)

func TestImpressumPage(t *testing.T) {
	t.Setenv("MAIL_PUBLIC_URL", "https://isms.example.com")
	t.Setenv("IMPRESSUM_NAME", "Beispiel GmbH")
	t.Setenv("IMPRESSUM_STREET", "Musterstraße 1")
	t.Setenv("IMPRESSUM_POSTAL_CODE", "10115")
	t.Setenv("IMPRESSUM_CITY", "Berlin")
	t.Setenv("IMPRESSUM_EMAIL", "kontakt@example.com")
	t.Setenv("IMPRESSUM_PHONE", "+49 30 123456")
	t.Setenv("IMPRESSUM_REPRESENTATIVE", "Ada Beispiel")
	t.Setenv("IMPRESSUM_REGISTER", "Amtsgericht Berlin, HRB 12345")
	t.Setenv("IMPRESSUM_VAT_ID", "DE123456789")
	t.Setenv("IMPRESSUM_RESPONSIBLE", "Ada Beispiel, Musterstraße 1, 10115 Berlin")

	handler := NewServer(auth.NewService("test-secret", time.Hour), nil, "").Router()
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/impressum", nil))
	if rec.Code != http.StatusOK {
		t.Fatalf("status %d", rec.Code)
	}
	body := rec.Body.String()
	for _, want := range []string{
		"Impressum",
		"Angaben gemäß § 5 DDG",
		"Beispiel GmbH",
		"Musterstraße 1",
		"10115 Berlin",
		"mailto:kontakt@example.com",
		`href="tel:&#43;4930123456"`,
		"Ada Beispiel",
		"HRB 12345",
		"DE123456789",
		"§ 18 Abs. 2 MStV",
		`rel="canonical" href="https://isms.example.com/impressum"`,
	} {
		if !strings.Contains(body, want) {
			t.Fatalf("impressum missing %q\n%s", want, body)
		}
	}
	if rec.Header().Get("X-Robots-Tag") != "" {
		t.Fatalf("complete impressum robots %q", rec.Header().Get("X-Robots-Tag"))
	}

	home := httptest.NewRecorder()
	handler.ServeHTTP(home, httptest.NewRequest(http.MethodGet, "/", nil))
	if !strings.Contains(home.Body.String(), `href="/impressum"`) {
		t.Fatal("home missing impressum link")
	}
	if !strings.Contains(home.Body.String(), `href="https://github.com/Target42/BSI"`) {
		t.Fatal("home missing GitHub link")
	}
	login := httptest.NewRecorder()
	handler.ServeHTTP(login, httptest.NewRequest(http.MethodGet, "/login", nil))
	if !strings.Contains(login.Body.String(), `href="/impressum"`) {
		t.Fatal("login missing impressum link")
	}
	if !strings.Contains(login.Body.String(), `href="https://github.com/Target42/BSI"`) {
		t.Fatal("login missing GitHub link")
	}

	sitemap := httptest.NewRecorder()
	handler.ServeHTTP(sitemap, httptest.NewRequest(http.MethodGet, "/sitemap.xml", nil))
	if !strings.Contains(sitemap.Body.String(), "<loc>https://isms.example.com/impressum</loc>") {
		t.Fatalf("sitemap %s", sitemap.Body.String())
	}
	robots := httptest.NewRecorder()
	handler.ServeHTTP(robots, httptest.NewRequest(http.MethodGet, "/robots.txt", nil))
	if !strings.Contains(robots.Body.String(), "Allow: /impressum$") {
		t.Fatalf("robots %s", robots.Body.String())
	}
}

func TestImpressumIncompleteIsNotIndexable(t *testing.T) {
	t.Setenv("IMPRESSUM_NAME", "")
	t.Setenv("IMPRESSUM_STREET", "")
	t.Setenv("IMPRESSUM_POSTAL_CODE", "")
	t.Setenv("IMPRESSUM_CITY", "")
	t.Setenv("IMPRESSUM_EMAIL", "")

	handler := NewServer(auth.NewService("test-secret", time.Hour), nil, "").Router()
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/impressum", nil))
	if rec.Code != http.StatusOK {
		t.Fatalf("status %d", rec.Code)
	}
	if !strings.Contains(rec.Body.String(), "noch nicht hinterlegt") {
		t.Fatalf("body %s", rec.Body.String())
	}
	if rec.Header().Get("X-Robots-Tag") != "noindex, nofollow" {
		t.Fatalf("robots %q", rec.Header().Get("X-Robots-Tag"))
	}
}
