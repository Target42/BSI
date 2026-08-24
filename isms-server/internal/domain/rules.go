package domain

import "strings"

const (
	TargetTypeScope          = "Informationsverbund"
	TargetTypeProcess        = "Geschäftsprozess"
	TargetTypeApplication    = "Anwendung"
	TargetTypeITSystem       = "IT-System"
	TargetTypeNetwork        = "Netz"
	TargetTypeInfrastructure = "Infrastruktur"

	CiaNormal    = "normal"
	CiaHigh      = "hoch"
	CiaVeryHigh  = "sehr hoch"
	NeedNormal   = "Normal (Basis + Standard)"
	NeedElevated = "Erhöht (Basis + Standard + Erhöht)"
	NeedBasis    = "Basis-Anforderungen"
)

// RequirementLevelApplies mirrors ProtectionNeed logic from the Qt client.
func RequirementLevelApplies(level, protectionNeed string) bool {
	switch level {
	case "Unbekannt", "":
		return true
	}

	switch protectionNeed {
	case NeedBasis:
		return level == "Basis"
	case NeedElevated:
		return level == "Basis" || level == "Standard" || level == "Erhöht"
	default: // Normal (Basis + Standard)
		return level == "Basis" || level == "Standard"
	}
}

func ApplicabilityCountsForReport(status string) bool {
	return status == "Benötigt" || status == "Möglicherweise"
}

func ReportProgressPercent(summary ReportSummary) int {
	if summary.TotalRequirements <= 0 {
		return 0
	}
	completed := summary.FulfilledCount + summary.NotApplicableCount
	return (completed*100 + summary.TotalRequirements/2) / summary.TotalRequirements
}

func NormalizeTargetObjectType(value string) string {
	switch strings.TrimSpace(value) {
	case TargetTypeScope, "Geltungsbereich":
		return TargetTypeScope
	case TargetTypeProcess:
		return TargetTypeProcess
	case TargetTypeApplication:
		return TargetTypeApplication
	case TargetTypeITSystem:
		return TargetTypeITSystem
	case TargetTypeNetwork, "Kommunikationsverbindung", "Netze":
		return TargetTypeNetwork
	case TargetTypeInfrastructure:
		return TargetTypeInfrastructure
	default:
		return strings.TrimSpace(value)
	}
}

func AllowedChildTargetTypes(parentType string) []string {
	switch NormalizeTargetObjectType(parentType) {
	case TargetTypeScope:
		return []string{TargetTypeProcess, TargetTypeApplication, TargetTypeITSystem, TargetTypeNetwork, TargetTypeInfrastructure}
	case TargetTypeProcess:
		return []string{TargetTypeProcess, TargetTypeApplication}
	case TargetTypeITSystem:
		return []string{TargetTypeApplication, TargetTypeITSystem, TargetTypeNetwork}
	case TargetTypeInfrastructure:
		return []string{TargetTypeITSystem, TargetTypeInfrastructure, TargetTypeNetwork}
	default:
		return nil
	}
}

func IsAllowedChildTargetType(parentType, childType string) bool {
	child := NormalizeTargetObjectType(childType)
	for _, allowed := range AllowedChildTargetTypes(parentType) {
		if allowed == child {
			return true
		}
	}
	return false
}

func IsRootScopeTarget(parentID int64, objectType string) bool {
	return parentID == 0 && NormalizeTargetObjectType(objectType) == TargetTypeScope
}

func FindTargetByID(items []TargetObject, id int64) (TargetObject, bool) {
	if id <= 0 {
		return TargetObject{}, false
	}
	for _, item := range items {
		if item.ID == id {
			return item, true
		}
	}
	return TargetObject{}, false
}

func WouldCreateParentCycle(items []TargetObject, objectID, newParentID int64) bool {
	if objectID <= 0 || newParentID <= 0 {
		return false
	}
	byID := make(map[int64]TargetObject, len(items))
	for _, item := range items {
		if item.ID > 0 {
			byID[item.ID] = item
		}
	}
	current := newParentID
	for guard := 0; current > 0 && guard < 64; guard++ {
		if current == objectID {
			return true
		}
		item, ok := byID[current]
		if !ok {
			return false
		}
		current = item.ParentID
	}
	return false
}

func CanInheritAssessments(parentType, childType string) bool {
	parent := NormalizeTargetObjectType(parentType)
	child := NormalizeTargetObjectType(childType)
	switch parent {
	case TargetTypeITSystem:
		return child == TargetTypeITSystem || child == TargetTypeApplication || child == TargetTypeNetwork
	case TargetTypeProcess:
		return child == TargetTypeProcess || child == TargetTypeApplication
	case TargetTypeInfrastructure:
		return child == TargetTypeInfrastructure || child == TargetTypeITSystem || child == TargetTypeNetwork
	default:
		return false
	}
}

func NormalizeCiaLevel(value string) string {
	switch strings.ToLower(strings.TrimSpace(value)) {
	case CiaHigh, "high":
		return CiaHigh
	case CiaVeryHigh, "sehrhoch", "very high":
		return CiaVeryHigh
	default:
		return CiaNormal
	}
}

func ciaRank(value string) int {
	switch NormalizeCiaLevel(value) {
	case CiaVeryHigh:
		return 2
	case CiaHigh:
		return 1
	default:
		return 0
	}
}

func MaxCiaLevel(values ...string) string {
	max := CiaNormal
	for _, value := range values {
		if ciaRank(value) > ciaRank(max) {
			max = NormalizeCiaLevel(value)
		}
	}
	return max
}

func ProtectionNeedFromCia(confidentiality, integrity, availability string) string {
	if ciaRank(MaxCiaLevel(confidentiality, integrity, availability)) > 0 {
		return NeedElevated
	}
	return NeedNormal
}

func ApplyTargetObjectProtectionNeed(target *TargetObject, parent *TargetObject) {
	keepBasis := target.ProtectionNeed == NeedBasis
	if target.ParentID <= 0 {
		target.InheritProtectionNeed = false
	} else if target.InheritProtectionNeed && parent != nil && parent.ID > 0 {
		keepBasis = false
		target.Confidentiality = parent.Confidentiality
		target.Integrity = parent.Integrity
		target.Availability = parent.Availability
	}
	target.Confidentiality = NormalizeCiaLevel(target.Confidentiality)
	target.Integrity = NormalizeCiaLevel(target.Integrity)
	target.Availability = NormalizeCiaLevel(target.Availability)
	derived := ProtectionNeedFromCia(target.Confidentiality, target.Integrity, target.Availability)
	if keepBasis && derived == NeedNormal {
		target.ProtectionNeed = NeedBasis
	} else {
		target.ProtectionNeed = derived
	}
}

func ResolveInheritedProtectionNeeds(items []TargetObject) {
	byID := make(map[int64]int, len(items))
	for i := range items {
		if items[i].ID > 0 {
			byID[items[i].ID] = i
		}
	}
	for i := range items {
		current := items[i]
		if !current.InheritProtectionNeed || current.ParentID <= 0 {
			ApplyTargetObjectProtectionNeed(&items[i], nil)
			continue
		}
		parent := current
		for guard := 0; parent.InheritProtectionNeed && parent.ParentID > 0 && guard < 64; guard++ {
			idx, ok := byID[parent.ParentID]
			if !ok {
				break
			}
			parent = items[idx]
		}
		ApplyTargetObjectProtectionNeed(&items[i], &parent)
	}
}
