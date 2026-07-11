package repository

import (
	"context"
	"errors"

	"github.com/Target42/BSI/isms-server/internal/domain"
	"github.com/jackc/pgx/v5"
)

func (s *Store) ListMeasures(ctx context.Context, projectID, targetObjectID, requirementID int64) ([]domain.Measure, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT id, project_id, target_object_id, requirement_id, title,
		       COALESCE(description, ''), COALESCE(responsible, ''), due_date::text, status, version, updated_at
		FROM measures
		WHERE project_id = $1 AND target_object_id = $2 AND requirement_id = $3
		ORDER BY due_date IS NULL, due_date, title`,
		projectID, targetObjectID, requirementID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	return scanMeasures(rows)
}

func (s *Store) MeasureCounts(ctx context.Context, projectID, targetObjectID int64) (map[int64]int, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT requirement_id, COUNT(*)
		FROM measures
		WHERE project_id = $1 AND target_object_id = $2
		GROUP BY requirement_id`, projectID, targetObjectID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	counts := make(map[int64]int)
	for rows.Next() {
		var requirementID int64
		var count int
		if err := rows.Scan(&requirementID, &count); err != nil {
			return nil, err
		}
		counts[requirementID] = count
	}
	return counts, rows.Err()
}

func (s *Store) CreateMeasure(ctx context.Context, measure domain.Measure) (domain.Measure, error) {
	if measure.Status == "" {
		measure.Status = "Offen"
	}
	err := s.pool.QueryRow(ctx, `
		INSERT INTO measures
		(project_id, target_object_id, requirement_id, title, description, responsible, due_date, status)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
		RETURNING id, project_id, target_object_id, requirement_id, title,
		          COALESCE(description, ''), COALESCE(responsible, ''), due_date::text, status, version, updated_at`,
		measure.ProjectID, measure.TargetObjectID, measure.RequirementID,
		measure.Title, measure.Description, measure.Responsible, nullableDate(measure.DueDate), measure.Status,
	).Scan(
		&measure.ID, &measure.ProjectID, &measure.TargetObjectID, &measure.RequirementID,
		&measure.Title, &measure.Description, &measure.Responsible, &measure.DueDate,
		&measure.Status, &measure.Version, &measure.UpdatedAt,
	)
	return measure, err
}

func (s *Store) UpdateMeasure(ctx context.Context, measure domain.Measure) (domain.Measure, error) {
	err := s.pool.QueryRow(ctx, `
		UPDATE measures
		SET title = $2, description = $3, responsible = $4, due_date = $5, status = $6,
		    version = version + 1, updated_at = now()
		WHERE id = $1 AND version = $7
		RETURNING id, project_id, target_object_id, requirement_id, title,
		          COALESCE(description, ''), COALESCE(responsible, ''), due_date::text, status, version, updated_at`,
		measure.ID, measure.Title, measure.Description, measure.Responsible,
		nullableDate(measure.DueDate), measure.Status, measure.Version,
	).Scan(
		&measure.ID, &measure.ProjectID, &measure.TargetObjectID, &measure.RequirementID,
		&measure.Title, &measure.Description, &measure.Responsible, &measure.DueDate,
		&measure.Status, &measure.Version, &measure.UpdatedAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		current, lookupErr := s.GetMeasure(ctx, measure.ID)
		if lookupErr != nil {
			return domain.Measure{}, lookupErr
		}
		return current, ErrVersionConflict
	}
	return measure, err
}

func (s *Store) GetMeasure(ctx context.Context, measureID int64) (domain.Measure, error) {
	row := s.pool.QueryRow(ctx, `
		SELECT id, project_id, target_object_id, requirement_id, title,
		       COALESCE(description, ''), COALESCE(responsible, ''), due_date::text, status, version, updated_at
		FROM measures WHERE id = $1`, measureID)

	var measure domain.Measure
	err := row.Scan(
		&measure.ID, &measure.ProjectID, &measure.TargetObjectID, &measure.RequirementID,
		&measure.Title, &measure.Description, &measure.Responsible, &measure.DueDate,
		&measure.Status, &measure.Version, &measure.UpdatedAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return domain.Measure{}, ErrNotFound
	}
	return measure, err
}

func (s *Store) DeleteMeasure(ctx context.Context, measureID int64) error {
	tag, err := s.pool.Exec(ctx, `DELETE FROM measures WHERE id = $1`, measureID)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

func (s *Store) MeasureProjectID(ctx context.Context, measureID int64) (int64, error) {
	var projectID int64
	err := s.pool.QueryRow(ctx, `SELECT project_id FROM measures WHERE id = $1`, measureID).Scan(&projectID)
	if errors.Is(err, pgx.ErrNoRows) {
		return 0, ErrNotFound
	}
	return projectID, err
}

func scanMeasures(rows pgx.Rows) ([]domain.Measure, error) {
	var items []domain.Measure
	for rows.Next() {
		var m domain.Measure
		if err := rows.Scan(
			&m.ID, &m.ProjectID, &m.TargetObjectID, &m.RequirementID,
			&m.Title, &m.Description, &m.Responsible, &m.DueDate,
			&m.Status, &m.Version, &m.UpdatedAt,
		); err != nil {
			return nil, err
		}
		items = append(items, m)
	}
	return items, rows.Err()
}
