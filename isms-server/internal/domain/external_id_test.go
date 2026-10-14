package domain

import (
	"sort"
	"testing"
)

func TestCompareExternalIDNumericSegments(t *testing.T) {
	got := []string{
		"CON.10.A11",
		"CON.1.A10",
		"con.2.A1",
		"CON.1.A1",
		"CON.1.A2",
		"CON.10.A1",
		"CON.1.A11",
		"APP.1.10",
		"APP.1.2",
		"APP.1.1",
		"OPS.1.2",
		"OPS.1.1.2",
		"OPS.1.1.1",
	}
	sort.Slice(got, func(i, j int) bool {
		return CompareExternalID(got[i], got[j]) < 0
	})
	want := []string{
		"APP.1.1",
		"APP.1.2",
		"APP.1.10",
		"CON.1.A1",
		"CON.1.A2",
		"CON.1.A10",
		"CON.1.A11",
		"con.2.A1",
		"CON.10.A1",
		"CON.10.A11",
		"OPS.1.1.1",
		"OPS.1.1.2",
		"OPS.1.2",
	}
	if len(got) != len(want) {
		t.Fatalf("len %d", len(got))
	}
	for i := range want {
		if got[i] != want[i] {
			t.Fatalf("index %d: got %q want %q\nfull %v", i, got[i], want[i], got)
		}
	}
}

func TestCompareExternalIDEqualIgnoringCase(t *testing.T) {
	if CompareExternalID("CON.1", "con.1") != 0 {
		t.Fatal("case should not change order")
	}
	if CompareExternalID("CON.1", "CON.2") >= 0 {
		t.Fatal("CON.1 should precede CON.2")
	}
	if CompareExternalID("CON.2", "CON.10") >= 0 {
		t.Fatal("CON.2 should precede CON.10")
	}
}
