package repository

import (
	"context"
	"errors"
	"time"

	"github.com/Target42/BSI/isms-server/internal/domain"
	"github.com/jackc/pgx/v5"
)

const bausteinReviewColumns = `
	project_id, target_object_id, baustein_id, state, review_note, returned_requirement_ids,
	submitted_by, submitted_at, reviewed_by, reviewed_at, updated_at`

func (s *Store) GetBausteinReview(ctx context.Context, projectID, targetObjectID, bausteinID int64) (domain.BausteinReview, error) {
	review, err := scanBausteinReview(s.pool.QueryRow(ctx, `
		SELECT `+bausteinReviewColumns+`
		FROM baustein_reviews
		WHERE project_id = $1 AND target_object_id = $2 AND baustein_id = $3`,
		projectID, targetObjectID, bausteinID))
	if errors.Is(err, pgx.ErrNoRows) {
		return domain.DefaultBausteinReview(projectID, targetObjectID, bausteinID), nil
	}
	return review, err
}

func (s *Store) ListBausteinReviews(ctx context.Context, projectID, targetObjectID int64) (map[int64]domain.BausteinReview, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT `+bausteinReviewColumns+`
		FROM baustein_reviews
		WHERE project_id = $1 AND target_object_id = $2`,
		projectID, targetObjectID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := map[int64]domain.BausteinReview{}
	for rows.Next() {
		review, err := scanBausteinReview(rows)
		if err != nil {
			return nil, err
		}
		out[review.BausteinID] = review
	}
	return out, rows.Err()
}

func (s *Store) ListProjectReviews(ctx context.Context, projectID int64) ([]domain.BausteinReview, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT `+bausteinReviewColumns+`
		FROM baustein_reviews
		WHERE project_id = $1
		ORDER BY updated_at DESC, baustein_id`,
		projectID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := make([]domain.BausteinReview, 0)
	for rows.Next() {
		review, err := scanBausteinReview(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, review)
	}
	return out, rows.Err()
}

func (s *Store) SaveBausteinReview(ctx context.Context, review domain.BausteinReview) (domain.BausteinReview, error) {
	review.State = domain.NormalizeReviewState(review.State)
	review.ReturnedRequirementIDs = domain.NormalizeReturnedRequirementIDs(review.ReturnedRequirementIDs)
	saved, err := scanBausteinReview(s.pool.QueryRow(ctx, `
		INSERT INTO baustein_reviews (
			project_id, target_object_id, baustein_id, state, review_note, returned_requirement_ids,
			submitted_by, submitted_at, reviewed_by, reviewed_at
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
		ON CONFLICT (project_id, target_object_id, baustein_id) DO UPDATE SET
			state = EXCLUDED.state,
			review_note = EXCLUDED.review_note,
			returned_requirement_ids = EXCLUDED.returned_requirement_ids,
			submitted_by = EXCLUDED.submitted_by,
			submitted_at = EXCLUDED.submitted_at,
			reviewed_by = EXCLUDED.reviewed_by,
			reviewed_at = EXCLUDED.reviewed_at,
			updated_at = now()
		RETURNING `+bausteinReviewColumns,
		review.ProjectID, review.TargetObjectID, review.BausteinID, review.State, review.ReviewNote,
		review.ReturnedRequirementIDs,
		nullableInt64(review.SubmittedBy), review.SubmittedAt,
		nullableInt64(review.ReviewedBy), review.ReviewedAt,
	))
	return saved, err
}

func (s *Store) RequireBausteinWritable(ctx context.Context, projectID, targetObjectID, bausteinID int64) error {
	project, err := s.GetProject(ctx, projectID)
	if err != nil {
		return err
	}
	review, err := s.GetBausteinReview(ctx, projectID, targetObjectID, bausteinID)
	if err != nil {
		return err
	}
	if !domain.ReviewAllowsBausteinEdit(project.WorkflowEnabled, review.State, review.ReturnedRequirementIDs) {
		return domain.ErrReviewLocked
	}
	return nil
}

func (s *Store) RequireRequirementWritable(ctx context.Context, projectID, targetObjectID, requirementID int64) error {
	requirement, err := s.GetRequirement(ctx, requirementID)
	if err != nil {
		return err
	}
	project, err := s.GetProject(ctx, projectID)
	if err != nil {
		return err
	}
	review, err := s.GetBausteinReview(ctx, projectID, targetObjectID, requirement.BausteinID)
	if err != nil {
		return err
	}
	if !domain.ReviewAllowsRequirementEdit(project.WorkflowEnabled, review.State, review.ReturnedRequirementIDs, requirementID) {
		return domain.ErrReviewLocked
	}
	return nil
}

func (s *Store) RequireMeasureWritable(ctx context.Context, measure domain.Measure) error {
	return s.RequireRequirementWritable(ctx, measure.ProjectID, measure.TargetObjectID, measure.RequirementID)
}

func scanBausteinReview(scanner interface{ Scan(dest ...any) error }) (domain.BausteinReview, error) {
	var review domain.BausteinReview
	var submittedBy, reviewedBy *int64
	var submittedAt, reviewedAt *time.Time
	err := scanner.Scan(
		&review.ProjectID, &review.TargetObjectID, &review.BausteinID, &review.State, &review.ReviewNote,
		&review.ReturnedRequirementIDs,
		&submittedBy, &submittedAt, &reviewedBy, &reviewedAt, &review.UpdatedAt,
	)
	if err != nil {
		return domain.BausteinReview{}, err
	}
	review.State = domain.NormalizeReviewState(review.State)
	review.ReturnedRequirementIDs = domain.NormalizeReturnedRequirementIDs(review.ReturnedRequirementIDs)
	if submittedBy != nil {
		review.SubmittedBy = *submittedBy
	}
	review.SubmittedAt = submittedAt
	if reviewedBy != nil {
		review.ReviewedBy = *reviewedBy
	}
	review.ReviewedAt = reviewedAt
	return review, nil
}
