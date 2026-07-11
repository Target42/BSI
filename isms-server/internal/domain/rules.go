package domain

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
