package domain

import "testing"

func TestModelAllowsEdit(t *testing.T) {
	tests := []struct {
		locked bool
		role   string
		want   bool
	}{
		{false, RoleOwner, true},
		{false, RoleEditor, true},
		{false, RoleReviewer, false},
		{false, RoleViewer, false},
		{true, RoleOwner, true},
		{true, RoleEditor, false},
		{true, RoleReviewer, false},
		{true, RoleViewer, false},
	}
	for _, tc := range tests {
		if got := ModelAllowsEdit(tc.locked, tc.role); got != tc.want {
			t.Fatalf("locked=%v role=%q: got %v want %v", tc.locked, tc.role, got, tc.want)
		}
	}
}

func TestCanToggleModelLock(t *testing.T) {
	if !CanToggleModelLock(RoleOwner) {
		t.Fatal("owner must toggle lock")
	}
	if CanToggleModelLock(RoleEditor) || CanToggleModelLock(RoleReviewer) {
		t.Fatal("only owner may toggle lock")
	}
}

func TestSubtreeHasLockedModel(t *testing.T) {
	items := []TargetObject{
		{ID: 1, Name: "Verbund"},
		{ID: 2, ParentID: 1, Name: "Netz", ModelLocked: true},
		{ID: 3, ParentID: 2, Name: "Router"},
		{ID: 4, ParentID: 1, Name: "Cluster"},
	}
	if !SubtreeHasLockedModel(items, 1) {
		t.Fatal("locked child must block parent delete")
	}
	if !SubtreeHasLockedModel(items, 2) {
		t.Fatal("locked node must block itself")
	}
	if SubtreeHasLockedModel(items, 4) {
		t.Fatal("unlocked leaf must stay writable")
	}
	if SubtreeHasLockedModel(items, 3) {
		t.Fatal("unlocked descendant of a locked parent is not itself locked")
	}
}
