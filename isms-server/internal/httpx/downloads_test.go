package httpx

import (
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/Target42/BSI/isms-server/internal/auth"
)

func TestResolveDownloadRejectsEscapeAndForeignTypes(t *testing.T) {
	dir := t.TempDir()
	if _, _, ok := resolveDownload(dir, "../secret.exe"); ok {
		t.Fatal("parent path must be rejected")
	}
	if _, _, ok := resolveDownload(dir, `..\secret.exe`); ok {
		t.Fatal("windows parent path must be rejected")
	}
	if _, _, ok := resolveDownload(dir, ".env"); ok {
		t.Fatal("dotfile must be rejected")
	}
	if _, _, ok := resolveDownload(dir, "notes.txt"); ok {
		t.Fatal("text file must be rejected")
	}
	if _, name, ok := resolveDownload(dir, "isms-werkzeug_1.0.0_amd64.deb"); !ok || name != "isms-werkzeug_1.0.0_amd64.deb" {
		t.Fatalf("deb should be allowed, ok=%v name=%q", ok, name)
	}
}

func TestClientDownloadsLabelsAndLiveReplace(t *testing.T) {
	dir := t.TempDir()
	deb := filepath.Join(dir, "isms-werkzeug_1.2.0_amd64.deb")
	exe := filepath.Join(dir, "BSIClient-Setup.exe")
	if err := os.WriteFile(deb, []byte("deb-v1"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(exe, []byte("exe-bytes"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dir, "liesmich.txt"), []byte("nein"), 0o644); err != nil {
		t.Fatal(err)
	}

	ui := newWebUI(auth.NewService("test-secret", time.Hour), nil, nil, "/isms", nil)
	ui.downloadsDir = dir
	items := ui.clientDownloads()
	if len(items) != 2 {
		t.Fatalf("want 2 downloads, got %#v", items)
	}
	if items[0].Label != "Qt-GUI" || !strings.HasPrefix(items[0].Href, "/downloads/") {
		t.Fatalf("qt item: %#v", items[0])
	}
	if items[1].Label != "Delphi-Client" || items[1].Name != "BSIClient-Setup.exe" {
		t.Fatalf("delphi item: %#v", items[1])
	}

	server := NewServer(auth.NewService("test-secret", time.Hour), nil, "/isms")
	server.SetDownloadsDir(dir)
	handler := server.Router()

	home := httptest.NewRecorder()
	handler.ServeHTTP(home, httptest.NewRequest(http.MethodGet, "/", nil))
	if home.Code != http.StatusOK {
		t.Fatalf("home status %d", home.Code)
	}
	body := home.Body.String()
	for _, want := range []string{
		`href="/isms/downloads"`,
		`href="/isms/downloads/isms-werkzeug_1.2.0_amd64.deb"`,
		"Qt-GUI",
		"Delphi-Client",
	} {
		if !strings.Contains(body, want) {
			t.Fatalf("home missing %q\n%s", want, body)
		}
	}
	if strings.Contains(body, "liesmich") {
		t.Fatal("non-installer must not be listed")
	}

	login := httptest.NewRecorder()
	handler.ServeHTTP(login, httptest.NewRequest(http.MethodGet, "/login", nil))
	if !strings.Contains(login.Body.String(), "Delphi-Client") {
		t.Fatalf("login should offer downloads: %s", login.Body.String())
	}

	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/downloads/isms-werkzeug_1.2.0_amd64.deb", nil))
	if rec.Code != http.StatusOK || rec.Body.String() != "deb-v1" {
		t.Fatalf("download status %d body %q", rec.Code, rec.Body.String())
	}
	if disp := rec.Header().Get("Content-Disposition"); !strings.Contains(disp, `filename="isms-werkzeug_1.2.0_amd64.deb"`) {
		t.Fatalf("disposition %q", disp)
	}
	if rec.Header().Get("Content-Type") != "application/octet-stream" {
		t.Fatalf("content-type %q", rec.Header().Get("Content-Type"))
	}

	if err := os.WriteFile(deb, []byte("deb-v2"), 0o644); err != nil {
		t.Fatal(err)
	}
	rec = httptest.NewRecorder()
	handler.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/downloads/isms-werkzeug_1.2.0_amd64.deb", nil))
	if rec.Body.String() != "deb-v2" {
		t.Fatalf("replaced file not served: %q", rec.Body.String())
	}

	for _, path := range []string{
		"/downloads/liesmich.txt",
		"/downloads/..%2fisms-werkzeug_1.2.0_amd64.deb",
		"/downloads/missing.deb",
	} {
		rec = httptest.NewRecorder()
		handler.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, path, nil))
		if rec.Code != http.StatusNotFound {
			t.Fatalf("%s status %d", path, rec.Code)
		}
	}
}

func TestHomeHidesDownloadsWhenDirectoryEmpty(t *testing.T) {
	server := NewServer(auth.NewService("test-secret", time.Hour), nil, "")
	server.SetDownloadsDir(t.TempDir())
	handler := server.Router()
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/", nil))
	if strings.Contains(rec.Body.String(), "Desktop-Clients") || strings.Contains(rec.Body.String(), "Qt-GUI") {
		t.Fatalf("empty dir must not offer downloads: %s", rec.Body.String())
	}
	page := httptest.NewRecorder()
	handler.ServeHTTP(page, httptest.NewRequest(http.MethodGet, "/downloads", nil))
	if page.Code != http.StatusOK || !strings.Contains(page.Body.String(), "keine Desktop-Installer") {
		t.Fatalf("empty downloads page: %d %s", page.Code, page.Body.String())
	}
}
