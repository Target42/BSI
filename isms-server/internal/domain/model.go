package domain

import "errors"

var ErrModelLocked = errors.New("model locked")

func CanToggleModelLock(role string) bool {
	return role == RoleOwner
}

func ModelAllowsEdit(locked bool, role string) bool {
	if !CanEditContent(role) {
		return false
	}
	if locked && !CanToggleModelLock(role) {
		return false
	}
	return true
}

func ModelLockMessage() string {
	return "Das Modell dieses Zielobjekts ist festgezogen. Nur der Besitzer kann Struktur und Bausteinauswahl ändern."
}

func SubtreeHasLockedModel(items []TargetObject, rootID int64) bool {
	if rootID <= 0 {
		return false
	}
	byID := make(map[int64]TargetObject, len(items))
	children := make(map[int64][]int64, len(items))
	for _, item := range items {
		byID[item.ID] = item
		if item.ParentID > 0 {
			children[item.ParentID] = append(children[item.ParentID], item.ID)
		}
	}
	var walk func(id int64) bool
	walk = func(id int64) bool {
		if item, ok := byID[id]; ok && item.ModelLocked {
			return true
		}
		for _, childID := range children[id] {
			if walk(childID) {
				return true
			}
		}
		return false
	}
	return walk(rootID)
}
