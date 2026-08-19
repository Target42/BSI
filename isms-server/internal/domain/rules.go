package domain

import "strings"

const (
	TargetTypeScope          = "Informationsverbund"
	TargetTypeProcess        = "Geschäftsprozess"
	TargetTypeApplication    = "Anwendung"
	TargetTypeITSystem       = "IT-System"
	TargetTypeNetwork        = "Netz"
	TargetTypeInfrastructure = "Infrastruktur"
)

// RequirementLevelApplies mirrors ProtectionNeed logic from the Qt client.
func RequirementLevelApplies(level, protectionNeed string) bool {
	switch level {
	case "Unbekannt", "":
		return true
	}

	switch protectionNeed {
	case "Basis-Anforderungen":
		return level == "Basis"
	case "Erhöht (Basis + Standard + Erhöht)":
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
