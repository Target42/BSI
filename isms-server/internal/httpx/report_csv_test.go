package httpx

import (
	"strings"
	"testing"

	"github.com/Target42/BSI/isms-server/internal/domain"
)

func TestWriteSollIstCSV(t *testing.T) {
	due := "2026-03-01"
	var buf strings.Builder
	err := writeSollIstCSV(&buf, []domain.ReportRow{{
		TargetObjectName:      "Server",
		BausteinExternalID:    "SYS.1.1",
		BausteinTitle:         "Allgemeiner Server",
		RequirementExternalID: "SYS.1.1.A1",
		RequirementTitle:      "Planung",
		Level:                 "Basis",
		Applicability:         "Benötigt",
		Status:                "Offen",
		Responsible:           "IT",
		DueDate:               &due,
		MeasureCount:          2,
		Overdue:               true,
	}})
	if err != nil {
		t.Fatal(err)
	}
	out := buf.String()
	if !strings.HasPrefix(out, "\ufeff") {
		t.Fatal("expected UTF-8 BOM")
	}
	if !strings.Contains(out, "Zielobjekt;Baustein;") {
		t.Fatalf("header: %q", out)
	}
	if !strings.Contains(out, "Server;SYS.1.1;") || !strings.Contains(out, ";Ja") {
		t.Fatalf("row: %q", out)
	}
	if !strings.Contains(out, "01.03.2026") {
		t.Fatalf("due date: %q", out)
	}
}

func TestCSVFileName(t *testing.T) {
	if got := csvFileName("LKA Test / 2026"); got != "soll-ist-LKA-Test-2026.csv" {
		t.Fatalf("got %q", got)
	}
	if got := csvFileName("???"); got != "soll-ist-projekt.csv" {
		t.Fatalf("got %q", got)
	}
}
