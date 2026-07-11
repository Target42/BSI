package domain

type ReportRow struct {
	TargetObjectID        int64  `json:"targetObjectId"`
	TargetObjectName      string `json:"targetObjectName"`
	BausteinExternalID    string `json:"bausteinExternalId"`
	BausteinTitle         string `json:"bausteinTitle"`
	RequirementExternalID string `json:"requirementExternalId"`
	RequirementTitle      string `json:"requirementTitle"`
	Level                 string `json:"level"`
	Applicability         string `json:"applicability"`
	Status                string `json:"status"`
	Responsible           string `json:"responsible"`
	DueDate               *string `json:"dueDate,omitempty"`
	MeasureCount          int    `json:"measureCount"`
	Overdue               bool   `json:"overdue"`
}

type ReportSummary struct {
	TotalRequirements  int `json:"totalRequirements"`
	OpenCount          int `json:"openCount"`
	PartialCount       int `json:"partialCount"`
	FulfilledCount     int `json:"fulfilledCount"`
	NotApplicableCount int `json:"notApplicableCount"`
	OverdueCount       int `json:"overdueCount"`
	MeasureCount       int `json:"measureCount"`
	ProgressPercent    int `json:"progressPercent"`
}

type TargetProgress struct {
	TargetObjectID int64         `json:"targetObjectId"`
	Summary        ReportSummary `json:"summary"`
}
