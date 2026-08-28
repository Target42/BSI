package service

import (
	"strings"
	"testing"

	"github.com/Target42/BSI/isms-server/internal/domain"
)

func TestSearchCatalogRequirementBeforeBaustein(t *testing.T) {
	bausteine := []domain.Baustein{
		{ID: 1, ExternalID: "SYS.1.1", Title: "Allgemeiner Server", GroupName: "IT-Systeme"},
		{ID: 2, ExternalID: "INF.1", Title: "Allgemeines Gebäude", GroupName: "Serverräume"},
	}
	requirements := []domain.Requirement{
		{ID: 11, BausteinID: 1, ExternalID: "SYS.1.1.A1", Title: "Planung", Text: "Der Server MUSS geplant werden."},
	}
	hits, truncated := SearchCatalog(bausteine, requirements, "Server", 200)
	if truncated {
		t.Fatal("unexpected truncation")
	}
	if len(hits) != 2 {
		t.Fatalf("hits %d: %+v", len(hits), hits)
	}
	if hits[0].RequirementID != 11 || hits[0].MatchField != "Anforderungstext" {
		t.Fatalf("first hit %+v", hits[0])
	}
	if !strings.Contains(hits[0].Snippet, "Server") {
		t.Fatalf("snippet %q", hits[0].Snippet)
	}
	if hits[1].BausteinID != 2 || hits[1].RequirementID != 0 || hits[1].MatchField != "Kapitel" {
		t.Fatalf("second hit should be INF only: %+v", hits[1])
	}
}

func TestSearchCatalogSkipsBausteinWhenRequirementHits(t *testing.T) {
	bausteine := []domain.Baustein{
		{ID: 1, ExternalID: "SYS.1.1", Title: "Allgemeiner Server", GroupName: "IT-Systeme"},
	}
	requirements := []domain.Requirement{
		{ID: 11, BausteinID: 1, ExternalID: "SYS.1.1.A1", Title: "Server härten", Text: "Patches."},
	}
	hits, _ := SearchCatalog(bausteine, requirements, "Server", 200)
	if len(hits) != 1 || hits[0].RequirementID != 11 {
		t.Fatalf("expected only requirement hit, got %+v", hits)
	}
}

func TestSearchCatalogEmptyAndLimit(t *testing.T) {
	bausteine := []domain.Baustein{
		{ID: 1, ExternalID: "ORP.1", Title: "Organisation"},
		{ID: 2, ExternalID: "ORP.2", Title: "Personal"},
	}
	if hits, trunc := SearchCatalog(bausteine, nil, "  ", 10); len(hits) != 0 || trunc {
		t.Fatalf("empty needle: %+v %v", hits, trunc)
	}
	hits, trunc := SearchCatalog(bausteine, nil, "ORP", 1)
	if !trunc || len(hits) != 1 {
		t.Fatalf("limit: hits=%d trunc=%v", len(hits), trunc)
	}
}

func TestMatchSnippetUTF8(t *testing.T) {
	got := matchSnippet("Prüfung der Verschlüsselung für den Serverraum", "Prüfung")
	if !strings.Contains(got, "Prüfung") {
		t.Fatalf("snippet %q", got)
	}
}
