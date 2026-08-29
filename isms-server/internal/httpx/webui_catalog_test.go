package httpx

import (
	"bytes"
	"strings"
	"testing"
	"time"

	"github.com/Target42/BSI/isms-server/internal/auth"
	"github.com/Target42/BSI/isms-server/internal/domain"
	"github.com/Target42/BSI/isms-server/internal/service"
)

func TestGroupBausteineKeepsChapterOrder(t *testing.T) {
	got := groupBausteine([]domain.Baustein{
		{ID: 1, ExternalID: "ISMS.1", GroupName: "ISMS"},
		{ID: 2, ExternalID: "APP.1.1", GroupName: "APP Anwendungen"},
		{ID: 3, ExternalID: "ISMS.2", GroupName: "ISMS"},
		{ID: 4, ExternalID: "SYS.1.1", GroupName: ""},
	})
	if len(got) != 3 || got[0].Name != "ISMS" || got[1].Name != "APP Anwendungen" || got[2].Name != "Sonstige" {
		t.Fatalf("groups: %+v", got)
	}
	if len(got[0].Bausteine) != 2 || got[0].Bausteine[1].ExternalID != "ISMS.2" {
		t.Fatalf("isms members: %+v", got[0].Bausteine)
	}
}

func TestCatalogTemplateRendersTree(t *testing.T) {
	ui := newWebUI(auth.NewService("test-secret", time.Hour), nil, nil, "", nil)
	var buf bytes.Buffer
	err := ui.tmpl.ExecuteTemplate(&buf, "catalog", webPage{
		CatalogGroups: []webCatalogGroup{
			{Name: "ISMS", Bausteine: []domain.Baustein{{ID: 1, ExternalID: "ISMS.1", Title: "Sicherheitsmanagement"}}},
		},
		BausteinCount: 1,
	})
	if err != nil {
		t.Fatal(err)
	}
	body := buf.String()
	for _, want := range []string{`class="tree"`, "<details>", "<summary>ISMS", "ISMS.1 Sicherheitsmanagement"} {
		if !strings.Contains(body, want) {
			t.Fatalf("catalog tree missing %q in %s", want, body)
		}
	}
	if strings.Contains(body, "<th>Kapitel</th>") {
		t.Fatal("flat chapter table should be gone")
	}
	if strings.Contains(body, "<details open") {
		t.Fatal("chapters must start collapsed")
	}
}

func TestGroupCatalogHits(t *testing.T) {
	got := groupCatalogHits([]service.CatalogHit{
		{GroupName: "APP", BausteinLabel: "APP.1"},
		{GroupName: "ISMS", BausteinLabel: "ISMS.1"},
		{GroupName: "APP", BausteinLabel: "APP.2"},
	})
	if len(got) != 2 || got[0].Name != "APP" || len(got[0].Hits) != 2 || got[1].Name != "ISMS" {
		t.Fatalf("%+v", got)
	}
}
