package domain

import "testing"

func TestRequirementLevelApplies(t *testing.T) {
	tests := []struct {
		level   string
		need    string
		applies bool
	}{
		{"Basis", "Basis-Anforderungen", true},
		{"Standard", "Basis-Anforderungen", false},
		{"Basis", "Normal (Basis + Standard)", true},
		{"Standard", "Normal (Basis + Standard)", true},
		{"Erhöht", "Normal (Basis + Standard)", false},
		{"Erhöht", "Erhöht (Basis + Standard + Erhöht)", true},
	}

	for _, tc := range tests {
		got := RequirementLevelApplies(tc.level, tc.need)
		if got != tc.applies {
			t.Fatalf("level=%q need=%q: got %v want %v", tc.level, tc.need, got, tc.applies)
		}
	}
}

func TestReportProgressPercent(t *testing.T) {
	summary := ReportSummary{
		TotalRequirements:  4,
		FulfilledCount:     2,
		NotApplicableCount: 1,
	}
	if got := ReportProgressPercent(summary); got != 75 {
		t.Fatalf("got %d want 75", got)
	}
}
