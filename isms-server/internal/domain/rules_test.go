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

func TestIsAllowedChildTargetType(t *testing.T) {
	tests := []struct {
		parent string
		child  string
		ok     bool
	}{
		{TargetTypeScope, TargetTypeProcess, true},
		{TargetTypeScope, TargetTypeITSystem, true},
		{TargetTypeScope, TargetTypeApplication, true},
		{TargetTypeITSystem, TargetTypeApplication, true},
		{TargetTypeITSystem, TargetTypeITSystem, true},
		{TargetTypeProcess, TargetTypeApplication, true},
		{TargetTypeProcess, TargetTypeITSystem, false},
		{TargetTypeApplication, TargetTypeITSystem, false},
		{TargetTypeNetwork, TargetTypeApplication, false},
		{TargetTypeScope, TargetTypeNetwork, true},
		{TargetTypeScope, "Kommunikationsverbindung", true},
		{TargetTypeScope, TargetTypeScope, false},
		{"Geltungsbereich", TargetTypeProcess, true},
	}
	for _, tc := range tests {
		got := IsAllowedChildTargetType(tc.parent, tc.child)
		if got != tc.ok {
			t.Fatalf("parent=%q child=%q: got %v want %v", tc.parent, tc.child, got, tc.ok)
		}
	}
}

func TestWouldCreateParentCycle(t *testing.T) {
	items := []TargetObject{
		{ID: 1, ParentID: 0, Type: TargetTypeScope},
		{ID: 2, ParentID: 1, Type: TargetTypeITSystem},
		{ID: 3, ParentID: 2, Type: TargetTypeApplication},
		{ID: 4, ParentID: 1, Type: TargetTypeProcess},
	}
	if !WouldCreateParentCycle(items, 2, 3) {
		t.Fatal("moving a system under its own application should cycle")
	}
	if WouldCreateParentCycle(items, 3, 1) {
		t.Fatal("moving an application under the scope should not cycle")
	}
	if WouldCreateParentCycle(items, 3, 4) {
		t.Fatal("moving an application under a sibling process should not cycle")
	}
	if !WouldCreateParentCycle(items, 3, 3) {
		t.Fatal("moving an object under itself should cycle")
	}
}

func TestIsRootScopeTarget(t *testing.T) {
	if !IsRootScopeTarget(0, "Geltungsbereich") {
		t.Fatal("Geltungsbereich at root should be treated as Informationsverbund")
	}
	if IsRootScopeTarget(1, TargetTypeScope) {
		t.Fatal("nested Informationsverbund is not the project root")
	}
	if IsRootScopeTarget(0, TargetTypeProcess) {
		t.Fatal("process at parent 0 is not the root scope")
	}
}

func TestProtectionNeedFromCia(t *testing.T) {
	if got := ProtectionNeedFromCia(CiaNormal, CiaNormal, CiaNormal); got != NeedNormal {
		t.Fatalf("all normal: got %q want %q", got, NeedNormal)
	}
	if got := ProtectionNeedFromCia(CiaHigh, CiaNormal, CiaNormal); got != NeedElevated {
		t.Fatalf("one high: got %q want %q", got, NeedElevated)
	}
	if got := ProtectionNeedFromCia(CiaNormal, CiaVeryHigh, CiaNormal); got != NeedElevated {
		t.Fatalf("one very high: got %q want %q", got, NeedElevated)
	}
}

func TestResolveInheritedProtectionNeeds(t *testing.T) {
	items := []TargetObject{
		{ID: 1, ParentID: 0, Confidentiality: CiaHigh, Integrity: CiaNormal, Availability: CiaNormal},
		{ID: 2, ParentID: 1, InheritProtectionNeed: true, Confidentiality: CiaNormal, Integrity: CiaNormal, Availability: CiaNormal},
		{ID: 3, ParentID: 2, InheritProtectionNeed: true, Confidentiality: CiaNormal, Integrity: CiaNormal, Availability: CiaVeryHigh},
		{ID: 4, ParentID: 1, InheritProtectionNeed: false, Confidentiality: CiaNormal, Integrity: CiaHigh, Availability: CiaNormal},
	}
	ResolveInheritedProtectionNeeds(items)
	if items[1].Confidentiality != CiaHigh || items[1].ProtectionNeed != NeedElevated {
		t.Fatalf("child did not inherit parent CIA: %+v", items[1])
	}
	if items[2].Confidentiality != CiaHigh || items[2].Availability != CiaNormal {
		t.Fatalf("grandchild did not inherit source CIA: %+v", items[2])
	}
	if items[3].Integrity != CiaHigh || items[3].Confidentiality != CiaNormal {
		t.Fatalf("override was changed: %+v", items[3])
	}
}

func TestCanInheritAssessments(t *testing.T) {
	tests := []struct {
		parent string
		child  string
		ok     bool
	}{
		{TargetTypeITSystem, TargetTypeApplication, true},
		{TargetTypeITSystem, TargetTypeITSystem, true},
		{TargetTypeProcess, TargetTypeApplication, true},
		{TargetTypeInfrastructure, TargetTypeITSystem, true},
		{TargetTypeScope, TargetTypeITSystem, false},
		{TargetTypeApplication, TargetTypeITSystem, false},
		{TargetTypeITSystem, TargetTypeProcess, false},
	}
	for _, tc := range tests {
		got := CanInheritAssessments(tc.parent, tc.child)
		if got != tc.ok {
			t.Fatalf("parent=%q child=%q: got %v want %v", tc.parent, tc.child, got, tc.ok)
		}
	}
}

func TestResolveProjectRole(t *testing.T) {
	tests := []struct {
		member     string
		visibility string
		minRole    string
		wantRole   string
		ok         bool
	}{
		{"owner", VisibilityPrivate, RoleViewer, "owner", true},
		{"editor", VisibilityPrivate, RoleEditor, "editor", true},
		{"viewer", VisibilityPrivate, RoleEditor, "viewer", false},
		{"", VisibilityPrivate, RoleViewer, "", false},
		{"", VisibilityPublic, RoleViewer, RoleViewer, true},
		{"", VisibilityPublic, RoleEditor, "", false},
		{"viewer", VisibilityPublic, RoleViewer, "viewer", true},
		{"viewer", VisibilityPublic, RoleEditor, "viewer", false},
		{"", "PUBLIC", RoleViewer, RoleViewer, true},
		{"", "", RoleViewer, "", false},
	}
	for _, tc := range tests {
		got, ok := ResolveProjectRole(tc.member, tc.visibility, tc.minRole)
		if ok != tc.ok || got != tc.wantRole {
			t.Fatalf("member=%q vis=%q min=%q: got (%q, %v) want (%q, %v)",
				tc.member, tc.visibility, tc.minRole, got, ok, tc.wantRole, tc.ok)
		}
	}
}

func TestNormalizeVisibility(t *testing.T) {
	if got := NormalizeVisibility("public"); got != VisibilityPublic {
		t.Fatalf("got %q", got)
	}
	if got := NormalizeVisibility("Privat"); got != VisibilityPrivate {
		t.Fatalf("got %q", got)
	}
	if got := VisibilityLabel("public"); got != "Öffentlich" {
		t.Fatalf("label %q", got)
	}
}
