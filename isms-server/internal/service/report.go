package service

import (
	"context"
	"sort"
	"time"

	"github.com/Target42/BSI/isms-server/internal/domain"
	"github.com/Target42/BSI/isms-server/internal/repository"
)

const grundschutzStandard = "IT-Grundschutz"

type ReportService struct {
	store *repository.Store
}

func NewReportService(store *repository.Store) *ReportService {
	return &ReportService{store: store}
}

func (s *ReportService) BuildSollIstReport(ctx context.Context, projectID int64, targetObjectID int64, catalogVersion string) ([]domain.ReportRow, error) {
	project, err := s.store.GetProject(ctx, projectID)
	if err != nil {
		return nil, err
	}
	if catalogVersion == "" {
		catalogVersion = project.CatalogVersion
	}

	bausteine, err := s.store.ListBausteine(ctx, grundschutzStandard, catalogVersion)
	if err != nil {
		return nil, err
	}
	bausteinByID := make(map[int64]domain.Baustein, len(bausteine))
	for _, b := range bausteine {
		bausteinByID[b.ID] = b
	}

	targetObjects, err := s.store.ListTargetObjects(ctx, projectID)
	if err != nil {
		return nil, err
	}

	today := time.Now().Format("2006-01-02")
	var rows []domain.ReportRow

	for _, target := range targetObjects {
		if targetObjectID != 0 && target.ID != targetObjectID {
			continue
		}

		applicability, err := s.store.ApplicabilityMap(ctx, projectID, target.ID)
		if err != nil {
			return nil, err
		}
		if len(applicability) == 0 {
			continue
		}

		measureCounts, err := s.store.MeasureCounts(ctx, projectID, target.ID)
		if err != nil {
			return nil, err
		}

		assessments, err := s.store.ListAssessments(ctx, projectID, target.ID)
		if err != nil {
			return nil, err
		}
		assessmentByRequirement := make(map[int64]domain.RequirementAssessment, len(assessments))
		for _, a := range assessments {
			assessmentByRequirement[a.RequirementID] = a
		}

		for bausteinID, applicabilityStatus := range applicability {
			if !domain.ApplicabilityCountsForReport(applicabilityStatus) {
				continue
			}

			requirements, err := s.store.ListRequirements(ctx, bausteinID)
			if err != nil {
				return nil, err
			}

			baustein := bausteinByID[bausteinID]
			for _, requirement := range requirements {
				if requirement.Withdrawn {
					continue
				}
				if !domain.RequirementLevelApplies(requirement.Level, target.ProtectionNeed) {
					continue
				}

				assessment := assessmentByRequirement[requirement.ID]
				status := assessment.Status
				if status == "" {
					status = "Offen"
				}

				row := domain.ReportRow{
					TargetObjectID:        target.ID,
					TargetObjectName:      target.Name,
					BausteinExternalID:    requirement.BausteinExternalID,
					BausteinTitle:         baustein.Title,
					RequirementExternalID: requirement.ExternalID,
					RequirementTitle:      requirement.Title,
					Level:                 requirement.Level,
					Applicability:         applicabilityStatus,
					Status:                status,
					Responsible:           assessment.Responsible,
					DueDate:               assessment.DueDate,
					MeasureCount:          measureCounts[requirement.ID],
				}

				if assessment.DueDate != nil && *assessment.DueDate < today &&
					status != "Erfüllt" && status != "Entfällt" {
					row.Overdue = true
				}

				rows = append(rows, row)
			}
		}
	}

	sort.Slice(rows, func(i, j int) bool {
		if rows[i].TargetObjectName != rows[j].TargetObjectName {
			return rows[i].TargetObjectName < rows[j].TargetObjectName
		}
		if rows[i].BausteinExternalID != rows[j].BausteinExternalID {
			return rows[i].BausteinExternalID < rows[j].BausteinExternalID
		}
		return rows[i].RequirementExternalID < rows[j].RequirementExternalID
	})

	return rows, nil
}

func Summarize(rows []domain.ReportRow) domain.ReportSummary {
	summary := domain.ReportSummary{TotalRequirements: len(rows)}
	for _, row := range rows {
		switch row.Status {
		case "Offen":
			summary.OpenCount++
		case "Teilweise":
			summary.PartialCount++
		case "Erfüllt":
			summary.FulfilledCount++
		case "Entfällt":
			summary.NotApplicableCount++
		}
		if row.Overdue {
			summary.OverdueCount++
		}
		summary.MeasureCount += row.MeasureCount
	}
	summary.ProgressPercent = domain.ReportProgressPercent(summary)
	return summary
}

func (s *ReportService) ProjectProgress(ctx context.Context, projectID int64) (domain.ReportSummary, []domain.TargetProgress, error) {
	rows, err := s.BuildSollIstReport(ctx, projectID, 0, "")
	if err != nil {
		return domain.ReportSummary{}, nil, err
	}

	byTarget := make(map[int64][]domain.ReportRow)
	for _, row := range rows {
		byTarget[row.TargetObjectID] = append(byTarget[row.TargetObjectID], row)
	}

	targetProgress := make([]domain.TargetProgress, 0, len(byTarget))
	for targetID, targetRows := range byTarget {
		summary := Summarize(targetRows)
		targetProgress = append(targetProgress, domain.TargetProgress{
			TargetObjectID: targetID,
			Summary:        summary,
		})
	}

	sort.Slice(targetProgress, func(i, j int) bool {
		return targetProgress[i].TargetObjectID < targetProgress[j].TargetObjectID
	})

	return Summarize(rows), targetProgress, nil
}
