package repository

import (
	"context"
	"sort"
	"strings"

	"github.com/Target42/BSI/isms-server/internal/domain"
)

func (s *Store) ListAssignedTasks(ctx context.Context, userID int64) ([]domain.AssignedTask, error) {
	measures, err := s.listAssignedMeasures(ctx, userID)
	if err != nil {
		return nil, err
	}
	assessments, err := s.listAssignedAssessments(ctx, userID)
	if err != nil {
		return nil, err
	}
	items := append(measures, assessments...)
	sortAssignedTasks(items)
	return items, nil
}

func (s *Store) listAssignedMeasures(ctx context.Context, userID int64) ([]domain.AssignedTask, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT m.id, m.project_id, p.name, m.target_object_id, t.name,
		       m.requirement_id, r.external_id, r.title, m.title, m.status, m.due_date::text
		FROM measures m
		JOIN projects p ON p.id = m.project_id
		JOIN project_members pm ON pm.project_id = m.project_id AND pm.user_id = $1
		JOIN target_objects t ON t.id = m.target_object_id
		JOIN requirements r ON r.id = m.requirement_id
		JOIN users u ON u.id = $1
		WHERE m.status <> 'Erledigt'
		  AND (
		    m.responsible_user_id = $1
		    OR (
		      m.responsible_user_id IS NULL
		      AND m.responsible IS NOT NULL
		      AND btrim(m.responsible) <> ''
		      AND lower(btrim(m.responsible)) IN (lower(u.email), lower(u.display_name))
		    )
		  )
		ORDER BY m.due_date IS NULL, m.due_date, p.name, m.title`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var items []domain.AssignedTask
	for rows.Next() {
		var item domain.AssignedTask
		var reqID, reqTitle string
		if err := rows.Scan(
			&item.MeasureID, &item.ProjectID, &item.ProjectName, &item.TargetObjectID, &item.TargetName,
			&item.RequirementID, &reqID, &reqTitle, &item.Title, &item.Status, &item.DueDate,
		); err != nil {
			return nil, err
		}
		item.Kind = "Maßnahme"
		item.RequirementLabel = strings.TrimSpace(reqID + " " + reqTitle)
		items = append(items, item)
	}
	return items, rows.Err()
}

func (s *Store) listAssignedAssessments(ctx context.Context, userID int64) ([]domain.AssignedTask, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT a.project_id, p.name, a.target_object_id, t.name,
		       a.requirement_id, r.external_id, r.title, a.status, a.due_date::text
		FROM requirement_assessments a
		JOIN projects p ON p.id = a.project_id
		JOIN project_members pm ON pm.project_id = a.project_id AND pm.user_id = $1
		JOIN target_objects t ON t.id = a.target_object_id
		JOIN requirements r ON r.id = a.requirement_id
		JOIN users u ON u.id = $1
		WHERE a.status IN ('Offen', 'Teilweise')
		  AND (
		    a.responsible_user_id = $1
		    OR (
		      a.responsible_user_id IS NULL
		      AND a.responsible IS NOT NULL
		      AND btrim(a.responsible) <> ''
		      AND lower(btrim(a.responsible)) IN (lower(u.email), lower(u.display_name))
		    )
		  )
		ORDER BY a.due_date IS NULL, a.due_date, p.name, r.external_id`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var items []domain.AssignedTask
	for rows.Next() {
		var item domain.AssignedTask
		var reqID, reqTitle string
		if err := rows.Scan(
			&item.ProjectID, &item.ProjectName, &item.TargetObjectID, &item.TargetName,
			&item.RequirementID, &reqID, &reqTitle, &item.Status, &item.DueDate,
		); err != nil {
			return nil, err
		}
		item.Kind = "Bewertung"
		item.RequirementLabel = strings.TrimSpace(reqID + " " + reqTitle)
		item.Title = item.RequirementLabel
		items = append(items, item)
	}
	return items, rows.Err()
}

func sortAssignedTasks(items []domain.AssignedTask) {
	sort.SliceStable(items, func(i, j int) bool {
		left, right := items[i], items[j]
		leftDue := dueSortKey(left.DueDate)
		rightDue := dueSortKey(right.DueDate)
		if leftDue != rightDue {
			return leftDue < rightDue
		}
		if left.ProjectName != right.ProjectName {
			return left.ProjectName < right.ProjectName
		}
		return left.Title < right.Title
	})
}

func dueSortKey(value *string) string {
	if value == nil || *value == "" {
		return "9999-99-99"
	}
	return *value
}
