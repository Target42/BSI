package httpx

import (
	"fmt"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"

	"github.com/go-chi/chi/v5"
)

type webDownload struct {
	Label     string
	Name      string
	Size      string
	Href      string
	sortOrder int
}

func (u *webUI) clientDownloads() []webDownload {
	dir := strings.TrimSpace(u.downloadsDir)
	if dir == "" {
		return nil
	}
	entries, err := os.ReadDir(dir)
	if err != nil {
		return nil
	}
	out := make([]webDownload, 0, len(entries))
	for _, entry := range entries {
		name := entry.Name()
		path, _, ok := resolveDownload(dir, name)
		if !ok {
			continue
		}
		info, err := os.Stat(path)
		if err != nil || !info.Mode().IsRegular() {
			continue
		}
		label, order := downloadLabel(name)
		out = append(out, webDownload{
			Label:     label,
			Name:      name,
			Size:      formatByteSize(info.Size()),
			Href:      "/downloads/" + url.PathEscape(name),
			sortOrder: order,
		})
	}
	sort.Slice(out, func(i, j int) bool {
		if out[i].sortOrder != out[j].sortOrder {
			return out[i].sortOrder < out[j].sortOrder
		}
		return out[i].Name < out[j].Name
	})
	return out
}

func (u *webUI) downloadsPage(w http.ResponseWriter, r *http.Request) {
	u.render(w, r, "downloads", webPage{Title: "Desktop-Clients"})
}

func (u *webUI) serveDownload(w http.ResponseWriter, r *http.Request) {
	path, name, ok := resolveDownload(u.downloadsDir, chi.URLParam(r, "name"))
	if !ok {
		http.NotFound(w, r)
		return
	}
	f, err := os.Open(path)
	if err != nil {
		http.NotFound(w, r)
		return
	}
	defer f.Close()
	info, err := f.Stat()
	if err != nil || !info.Mode().IsRegular() {
		http.NotFound(w, r)
		return
	}
	w.Header().Set("Content-Type", "application/octet-stream")
	w.Header().Set("Content-Disposition", contentDispositionAttachment(name))
	w.Header().Set("X-Content-Type-Options", "nosniff")
	w.Header().Set("Cache-Control", "private, no-cache")
	http.ServeContent(w, r, name, info.ModTime(), f)
}

// resolveDownload accepts only a single file name inside dir.
// The caller decides whether that directory exists; an empty dir offers nothing.
func resolveDownload(dir, name string) (string, string, bool) {
	dir = strings.TrimSpace(dir)
	name = strings.TrimSpace(name)
	if dir == "" || name == "" || name != filepath.Base(name) {
		return "", "", false
	}
	if strings.HasPrefix(name, ".") || strings.ContainsAny(name, `/\`) {
		return "", "", false
	}
	if !allowedDownloadName(name) {
		return "", "", false
	}
	root, err := filepath.Abs(dir)
	if err != nil {
		return "", "", false
	}
	full := filepath.Join(root, name)
	rel, err := filepath.Rel(root, full)
	if err != nil || rel == ".." || strings.HasPrefix(rel, ".."+string(filepath.Separator)) {
		return "", "", false
	}
	return full, name, true
}

func allowedDownloadName(name string) bool {
	lower := strings.ToLower(name)
	if strings.HasSuffix(lower, ".tar.gz") {
		return true
	}
	switch strings.ToLower(filepath.Ext(name)) {
	case ".exe", ".msi", ".msix", ".deb", ".rpm", ".appimage", ".zip", ".dmg", ".tgz":
		return true
	default:
		return false
	}
}

func downloadLabel(name string) (string, int) {
	n := strings.ToLower(name)
	switch {
	case strings.Contains(n, "werkzeug") || strings.Contains(n, "qt-gui") || strings.Contains(n, "qt_gui"):
		return "Qt-GUI", 0
	case strings.Contains(n, "delphi") || strings.Contains(n, "bsiclient") || strings.Contains(n, "bsi-client") || strings.Contains(n, "bsi_client"):
		return "Delphi-Client", 1
	default:
		return name, 2
	}
}

func contentDispositionAttachment(name string) string {
	safe := strings.Map(func(r rune) rune {
		if r < 32 || r == '"' || r == '\\' {
			return '_'
		}
		return r
	}, name)
	return `attachment; filename="` + safe + `"`
}

func formatByteSize(n int64) string {
	if n < 0 {
		n = 0
	}
	const unit = 1024
	if n < unit {
		return fmt.Sprintf("%d B", n)
	}
	div := int64(unit)
	exp := 0
	for v := n / unit; v >= unit && exp < 3; v /= unit {
		div *= unit
		exp++
	}
	value := strconv.FormatFloat(float64(n)/float64(div), 'f', 1, 64)
	value = strings.TrimSuffix(value, ".0")
	value = strings.ReplaceAll(value, ".", ",")
	return value + " " + []string{"KB", "MB", "GB", "TB"}[exp]
}
