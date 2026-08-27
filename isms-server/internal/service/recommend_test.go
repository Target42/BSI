package service

import (
	"strings"
	"testing"

	"github.com/Target42/BSI/isms-server/internal/domain"
)

func TestBausteinPrefix(t *testing.T) {
	if got := BausteinPrefix("SYS.1.1"); got != "SYS" {
		t.Fatalf("got %q", got)
	}
	if got := BausteinPrefix("isms"); got != "ISMS" {
		t.Fatalf("got %q", got)
	}
}

func TestBuildRecommendationsScope(t *testing.T) {
	bausteine := []domain.Baustein{
		{ID: 1, ExternalID: "ISMS.1", Title: "Sicherheitsmanagement"},
		{ID: 2, ExternalID: "ORP.1", Title: "Organisation"},
		{ID: 3, ExternalID: "APP.1.1", Title: "Office"},
		{ID: 4, ExternalID: "DER.1", Title: "Detektion"},
		{ID: 5, ExternalID: "OPS.1.1.1", Title: "Allgemeiner IT-Betrieb"},
	}
	target := domain.TargetObject{Type: domain.TargetTypeScope, ProtectionNeed: domain.NeedNormal}
	got := BuildRecommendations(bausteine, target)
	ids := map[string]Recommendation{}
	for _, rec := range got {
		ids[rec.ExternalID] = rec
	}
	if _, ok := ids["APP.1.1"]; ok {
		t.Fatal("APP should not be recommended for the scope")
	}
	if ids["ISMS.1"].Tier != TierCore || ids["ISMS.1"].SuggestedStatus != StatusRequired {
		t.Fatalf("ISMS: %+v", ids["ISMS.1"])
	}
	if ids["OPS.1.1.1"].Tier != TierSupplementary {
		t.Fatalf("OPS: %+v", ids["OPS.1.1.1"])
	}
	if _, ok := ids["DER.1"]; ok {
		t.Fatal("DER only at elevated protection need")
	}

	target.ProtectionNeed = domain.NeedElevated
	got = BuildRecommendations(bausteine, target)
	foundDER := false
	for _, rec := range got {
		if rec.ExternalID == "DER.1" {
			foundDER = true
			if rec.SuggestedStatus != StatusRequired {
				t.Fatalf("elevated DER status %q", rec.SuggestedStatus)
			}
		}
	}
	if !foundDER {
		t.Fatal("expected DER at elevated scope")
	}
}

func TestRecommendationHint(t *testing.T) {
	hint := RecommendationHint(domain.TargetObject{
		Type:           domain.TargetTypeITSystem,
		ProtectionNeed: domain.NeedElevated,
	})
	if hint == "" || !strings.Contains(hint, "SYS") || !strings.Contains(hint, "DER") ||
		!strings.Contains(hint, "erhöhtem Schutzbedarf") {
		t.Fatalf("hint %q", hint)
	}
}
