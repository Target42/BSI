package service

import (
	"github.com/Target42/BSI/isms-server/internal/domain"
)

type InheritedBaustein struct {
	BausteinID     int64
	Status         string
	SourceTargetID int64
	SourceCaption  string
}

func TargetCaption(target domain.TargetObject) string {
	need := target.ProtectionNeed
	if need == "" {
		need = "—"
	}
	name := target.Name
	if name == "" {
		name = target.Type
	}
	return target.Type + " – " + name + " [" + need + "]"
}

func AncestorChain(objects []domain.TargetObject, target domain.TargetObject) []domain.TargetObject {
	var out []domain.TargetObject
	current := target
	for guard := 0; current.ParentID > 0 && guard < 64; guard++ {
		parent, ok := domain.FindTargetByID(objects, current.ParentID)
		if !ok || parent.ID == 0 {
			break
		}
		if !domain.CanInheritAssessments(parent.Type, current.Type) {
			break
		}
		out = append(out, parent)
		current = parent
	}
	return out
}

func CollectInherited(
	objects []domain.TargetObject,
	target domain.TargetObject,
	own map[int64]string,
	parentMaps map[int64]map[int64]string,
) map[int64]InheritedBaustein {
	out := map[int64]InheritedBaustein{}
	for _, parent := range AncestorChain(objects, target) {
		applied := parentMaps[parent.ID]
		for bausteinID, status := range applied {
			if !domain.ApplicabilityCountsForReport(status) {
				continue
			}
			if own[bausteinID] != "" {
				continue
			}
			if _, exists := out[bausteinID]; exists {
				continue
			}
			out[bausteinID] = InheritedBaustein{
				BausteinID:     bausteinID,
				Status:         status,
				SourceTargetID: parent.ID,
				SourceCaption:  TargetCaption(parent),
			}
		}
	}
	return out
}

func MergeApplicability(own map[int64]string, inherited map[int64]InheritedBaustein) map[int64]string {
	out := make(map[int64]string, len(own)+len(inherited))
	for id, status := range own {
		out[id] = status
	}
	for id, item := range inherited {
		if out[id] == "" {
			out[id] = item.Status
		}
	}
	return out
}
