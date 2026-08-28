package service

import (
	"testing"

	"github.com/Target42/BSI/isms-server/internal/domain"
)

func TestCollectInheritedITSystemToApplication(t *testing.T) {
	parent := domain.TargetObject{ID: 1, Type: domain.TargetTypeITSystem, Name: "Server", ProtectionNeed: domain.NeedNormal}
	child := domain.TargetObject{ID: 2, ParentID: 1, Type: domain.TargetTypeApplication, Name: "App"}
	objects := []domain.TargetObject{parent, child}
	own := map[int64]string{3: "Nicht relevant"}
	parentMaps := map[int64]map[int64]string{
		1: {3: "Benötigt", 4: "Möglicherweise", 5: "Nicht relevant"},
	}
	got := CollectInherited(objects, child, own, parentMaps)
	if _, ok := got[3]; ok {
		t.Fatal("own assignment must shadow parent")
	}
	if got[4].Status != "Möglicherweise" || got[4].SourceTargetID != 1 {
		t.Fatalf("expected inherited 4: %+v", got[4])
	}
	if _, ok := got[5]; ok {
		t.Fatal("Nicht relevant must not inherit")
	}
	if got[4].SourceCaption == "" || got[4].SourceCaption == "—" {
		t.Fatalf("caption %q", got[4].SourceCaption)
	}
}

func TestCollectInheritedStopsAtScope(t *testing.T) {
	scope := domain.TargetObject{ID: 1, Type: domain.TargetTypeScope, Name: "Verbund"}
	sys := domain.TargetObject{ID: 2, ParentID: 1, Type: domain.TargetTypeITSystem, Name: "Host"}
	got := CollectInherited([]domain.TargetObject{scope, sys}, sys, nil, map[int64]map[int64]string{
		1: {9: "Benötigt"},
	})
	if len(got) != 0 {
		t.Fatalf("scope must not inherit onto IT-System: %+v", got)
	}
}

func TestMergeApplicability(t *testing.T) {
	merged := MergeApplicability(
		map[int64]string{1: "Benötigt"},
		map[int64]InheritedBaustein{1: {Status: "Möglicherweise"}, 2: {Status: "Benötigt"}},
	)
	if merged[1] != "Benötigt" || merged[2] != "Benötigt" {
		t.Fatalf("%+v", merged)
	}
}

func TestAncestorChainCloserParentFirst(t *testing.T) {
	a := domain.TargetObject{ID: 1, Type: domain.TargetTypeITSystem, Name: "A"}
	b := domain.TargetObject{ID: 2, ParentID: 1, Type: domain.TargetTypeITSystem, Name: "B"}
	c := domain.TargetObject{ID: 3, ParentID: 2, Type: domain.TargetTypeApplication, Name: "C"}
	chain := AncestorChain([]domain.TargetObject{a, b, c}, c)
	if len(chain) != 2 || chain[0].ID != 2 || chain[1].ID != 1 {
		t.Fatalf("%+v", chain)
	}
}
