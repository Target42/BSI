package catalog

import (
	"path/filepath"
	"testing"
)

func TestImportFromFile(t *testing.T) {
	path := filepath.Join("testdata", "minimal.xml")
	result := ImportFromFile(path)
	if !result.Success {
		t.Fatalf("import failed: %s", result.ErrorMessage)
	}
	if len(result.Bausteine) != 1 {
		t.Fatalf("bausteine: got %d want 1", len(result.Bausteine))
	}
	if result.Bausteine[0].ExternalID != "NET.1.1" {
		t.Fatalf("baustein id: %q", result.Bausteine[0].ExternalID)
	}
	if len(result.Requirements) != 1 {
		t.Fatalf("requirements: got %d want 1", len(result.Requirements))
	}
	req := result.Requirements[0]
	if req.ExternalID != "NET.1.1.A1" || req.Level != "Basis" {
		t.Fatalf("requirement: %+v", req)
	}
	if req.ResponsibleRole != "Netzadministrator" {
		t.Fatalf("role: %q", req.ResponsibleRole)
	}
}
