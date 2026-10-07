package httpx

import (
	"net/http"
	"net/url"
	"os"
	"strings"

	"github.com/Target42/BSI/isms-server/internal/auth"
)

const (
	seoHomeTitle            = "ISMS · IT-Grundschutz im Browser"
	seoHomeDescription      = "ISMS für den BSI IT-Grundschutz: Informationsverbund modellieren, Bausteine und Anforderungen bewerten, Maßnahmen nachverfolgen. Im Browser, ohne Desktop-Client."
	seoDownloadsTitle       = "Desktop-Clients · ISMS"
	seoDownloadsDescription = "Desktop-Clients zum ISMS: Installer für die Oberfläche neben der Web-Anwendung für den IT-Grundschutz."
)

func mailPublicURL() string {
	return strings.TrimRight(strings.TrimSpace(os.Getenv("MAIL_PUBLIC_URL")), "/")
}

func (u *webUI) publicPathPrefix() string {
	if raw := mailPublicURL(); raw != "" {
		if parsed, err := url.Parse(raw); err == nil {
			return strings.TrimRight(parsed.Path, "/")
		}
	}
	if u != nil {
		return u.base
	}
	return ""
}

func (u *webUI) absoluteURL(r *http.Request, path string) string {
	if path == "" {
		path = "/"
	}
	if !strings.HasPrefix(path, "/") {
		path = "/" + path
	}
	if raw := mailPublicURL(); raw != "" {
		if path == "/" {
			return raw + "/"
		}
		return raw + path
	}
	if r == nil || r.Host == "" {
		return ""
	}
	scheme := "http"
	if auth.RequestIsHTTPS(r) {
		scheme = "https"
	}
	prefix := ""
	if u != nil {
		prefix = u.base
	}
	return scheme + "://" + r.Host + prefix + path
}

func (u *webUI) applySEO(r *http.Request, name string, data *webPage) {
	switch name {
	case "home":
		if data.LoggedIn {
			return
		}
		data.Indexable = true
		data.Title = seoHomeTitle
		data.Description = seoHomeDescription
		data.Canonical = u.absoluteURL(r, "/")
	case "downloads":
		if len(data.Downloads) == 0 {
			return
		}
		data.Indexable = true
		data.Title = seoDownloadsTitle
		data.Description = seoDownloadsDescription
		data.Canonical = u.absoluteURL(r, "/downloads")
	case "impressum":
		if !data.Legal.Complete {
			return
		}
		data.Indexable = true
		data.Title = "Impressum · ISMS"
		data.Description = "Impressum des Betreibers dieser ISMS-Website."
		data.Canonical = u.absoluteURL(r, "/impressum")
	}
}

func (u *webUI) robotsTxt(w http.ResponseWriter, r *http.Request) {
	prefix := u.publicPathPrefix()
	var b strings.Builder
	b.WriteString("User-agent: *\n")
	b.WriteString("Allow: " + prefix + "/$\n")
	b.WriteString("Allow: " + prefix + "/downloads$\n")
	b.WriteString("Allow: " + prefix + "/impressum$\n")
	b.WriteString("Allow: " + prefix + "/ui/\n")
	b.WriteString("Allow: " + prefix + "/sitemap.xml$\n")
	for _, path := range []string{
		"/api/",
		"/login",
		"/register",
		"/account",
		"/users",
		"/notifications",
		"/join/",
		"/projects",
		"/catalog",
		"/logout",
		"/health",
	} {
		b.WriteString("Disallow: " + prefix + path + "\n")
	}
	if loc := u.absoluteURL(r, "/sitemap.xml"); loc != "" {
		b.WriteString("\nSitemap: " + loc + "\n")
	}
	w.Header().Set("Content-Type", "text/plain; charset=utf-8")
	w.Header().Set("Cache-Control", "public, max-age=3600")
	_, _ = w.Write([]byte(b.String()))
}

func (u *webUI) sitemapXML(w http.ResponseWriter, r *http.Request) {
	locs := []string{u.absoluteURL(r, "/")}
	if legalNoticeFromEnv().Complete {
		if loc := u.absoluteURL(r, "/impressum"); loc != "" {
			locs = append(locs, loc)
		}
	}
	if len(u.clientDownloads()) > 0 {
		if loc := u.absoluteURL(r, "/downloads"); loc != "" {
			locs = append(locs, loc)
		}
	}
	var b strings.Builder
	b.WriteString("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n")
	b.WriteString("<urlset xmlns=\"http://www.sitemaps.org/schemas/sitemap/0.9\">\n")
	for _, loc := range locs {
		if loc == "" {
			continue
		}
		b.WriteString("  <url><loc>")
		b.WriteString(xmlEscape(loc))
		b.WriteString("</loc></url>\n")
	}
	b.WriteString("</urlset>\n")
	w.Header().Set("Content-Type", "application/xml; charset=utf-8")
	w.Header().Set("Cache-Control", "public, max-age=3600")
	_, _ = w.Write([]byte(b.String()))
}

func xmlEscape(s string) string {
	return strings.NewReplacer(
		"&", "&amp;",
		"<", "&lt;",
		">", "&gt;",
		`"`, "&quot;",
		"'", "&apos;",
	).Replace(s)
}
