package repository

import (
	"context"
	"errors"
	"strings"
	"time"

	"github.com/Target42/BSI/isms-server/internal/domain"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
)

type execer interface {
	Exec(ctx context.Context, sql string, arguments ...any) (pgconn.CommandTag, error)
}

const bausteinReviewSelect = `
	r.project_id, r.target_object_id, r.baustein_id, r.state, r.review_note, r.returned_requirement_ids,
	r.submitted_by, r.submitted_at, r.reviewed_by, r.reviewed_at, r.assigned_reviewer_id,
	COALESCE(NULLIF(u.display_name, ''), u.email, ''), r.updated_at`

const bausteinReviewFrom = `
	baustein_reviews r
	LEFT JOIN users u ON u.id = r.assigned_reviewer_id`

func (s *Store) GetBausteinReview(ctx context.Context, projectID, targetObjectID, bausteinID int64) (domain.BausteinReview, error) {
	review, err := scanBausteinReview(s.pool.QueryRow(ctx, `
		SELECT `+bausteinReviewSelect+`
		FROM `+bausteinReviewFrom+`
		WHERE r.project_id = $1 AND r.target_object_id = $2 AND r.baustein_id = $3`,
		projectID, targetObjectID, bausteinID))
	if errors.Is(err, pgx.ErrNoRows) {
		return domain.DefaultBausteinReview(projectID, targetObjectID, bausteinID), nil
	}
	return review, err
}

func (s *Store) ListBausteinReviews(ctx context.Context, projectID, targetObjectID int64) (map[int64]domain.BausteinReview, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT `+bausteinReviewSelect+`
		FROM `+bausteinReviewFrom+`
		WHERE r.project_id = $1 AND r.target_object_id = $2`,
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
		SELECT `+bausteinReviewSelect+`
		FROM `+bausteinReviewFrom+`
		WHERE r.project_id = $1
		ORDER BY r.updated_at DESC, r.baustein_id`,
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
	return s.saveBausteinReview(ctx, review, nil)
}

func (s *Store) SaveBausteinReviewWithEvent(ctx context.Context, review domain.BausteinReview, event domain.BausteinReviewEvent) (domain.BausteinReview, error) {
	return s.saveBausteinReview(ctx, review, &event)
}

func (s *Store) saveBausteinReview(ctx context.Context, review domain.BausteinReview, event *domain.BausteinReviewEvent) (domain.BausteinReview, error) {
	review.State = domain.NormalizeReviewState(review.State)
	review.ReturnedRequirementIDs = domain.NormalizeReturnedRequirementIDs(review.ReturnedRequirementIDs)
	if event == nil {
		if err := execSaveBausteinReview(ctx, s.pool, review); err != nil {
			return domain.BausteinReview{}, err
		}
		return s.GetBausteinReview(ctx, review.ProjectID, review.TargetObjectID, review.BausteinID)
	}
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return domain.BausteinReview{}, err
	}
	defer tx.Rollback(ctx)
	if err := execSaveBausteinReview(ctx, tx, review); err != nil {
		return domain.BausteinReview{}, err
	}
	if err := execInsertReviewEvent(ctx, tx, *event); err != nil {
		return domain.BausteinReview{}, err
	}
	if err := tx.Commit(ctx); err != nil {
		return domain.BausteinReview{}, err
	}
	return s.GetBausteinReview(ctx, review.ProjectID, review.TargetObjectID, review.BausteinID)
}

func execSaveBausteinReview(ctx context.Context, exec execer, review domain.BausteinReview) error {
	_, err := exec.Exec(ctx, `
		INSERT INTO baustein_reviews (
			project_id, target_object_id, baustein_id, state, review_note, returned_requirement_ids,
			submitted_by, submitted_at, reviewed_by, reviewed_at, assigned_reviewer_id
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
		ON CONFLICT (project_id, target_object_id, baustein_id) DO UPDATE SET
			state = EXCLUDED.state,
			review_note = EXCLUDED.review_note,
			returned_requirement_ids = EXCLUDED.returned_requirement_ids,
			submitted_by = EXCLUDED.submitted_by,
			submitted_at = EXCLUDED.submitted_at,
			reviewed_by = EXCLUDED.reviewed_by,
			reviewed_at = EXCLUDED.reviewed_at,
			assigned_reviewer_id = EXCLUDED.assigned_reviewer_id,
			updated_at = now()`,
		review.ProjectID, review.TargetObjectID, review.BausteinID, review.State, review.ReviewNote,
		review.ReturnedRequirementIDs,
		nullableInt64(review.SubmittedBy), review.SubmittedAt,
		nullableInt64(review.ReviewedBy), review.ReviewedAt,
		nullableInt64(review.AssignedReviewerID),
	)
	return err
}

func execInsertReviewEvent(ctx context.Context, exec execer, event domain.BausteinReviewEvent) error {
	event.Action = strings.TrimSpace(event.Action)
	event.FromState = domain.NormalizeReviewState(event.FromState)
	event.ToState = domain.NormalizeReviewState(event.ToState)
	event.Note = strings.TrimSpace(event.Note)
	event.ReturnedRequirementIDs = domain.NormalizeReturnedRequirementIDs(event.ReturnedRequirementIDs)
	_, err := exec.Exec(ctx, `
		INSERT INTO baustein_review_events (
			project_id, target_object_id, baustein_id, action, from_state, to_state, note,
			returned_requirement_ids, actor_id
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)`,
		event.ProjectID, event.TargetObjectID, event.BausteinID, event.Action, event.FromState, event.ToState,
		event.Note, event.ReturnedRequirementIDs, nullableInt64(event.ActorID),
	)
	return err
}

func (s *Store) ListBausteinReviewEvents(ctx context.Context, projectID, targetObjectID, bausteinID int64) ([]domain.BausteinReviewEvent, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT e.id, e.project_id, e.target_object_id, e.baustein_id, e.action, e.from_state, e.to_state,
			e.note, e.returned_requirement_ids, e.actor_id,
			COALESCE(NULLIF(u.display_name, ''), u.email, ''), e.created_at
		FROM baustein_review_events e
		LEFT JOIN users u ON u.id = e.actor_id
		WHERE e.project_id = $1 AND e.target_object_id = $2 AND e.baustein_id = $3
		ORDER BY e.created_at DESC, e.id DESC`,
		projectID, targetObjectID, bausteinID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := make([]domain.BausteinReviewEvent, 0)
	for rows.Next() {
		var event domain.BausteinReviewEvent
		var actorID *int64
		if err := rows.Scan(
			&event.ID, &event.ProjectID, &event.TargetObjectID, &event.BausteinID, &event.Action,
			&event.FromState, &event.ToState, &event.Note, &event.ReturnedRequirementIDs, &actorID,
			&event.ActorName, &event.CreatedAt,
		); err != nil {
			return nil, err
		}
		event.FromState = domain.NormalizeReviewState(event.FromState)
		event.ToState = domain.NormalizeReviewState(event.ToState)
		event.ReturnedRequirementIDs = domain.NormalizeReturnedRequirementIDs(event.ReturnedRequirementIDs)
		if actorID != nil {
			event.ActorID = *actorID
		}
		out = append(out, event)
	}
	return out, rows.Err()
}

func (s *Store) ResolveAssignedReviewer(ctx context.Context, projectID, reviewerID int64) (int64, string, error) {
	if reviewerID <= 0 {
		return 0, "", nil
	}
	members, err := s.ListProjectMembers(ctx, projectID)
	if err != nil {
		return 0, "", err
	}
	for _, member := range members {
		if member.UserID == reviewerID && domain.CanBeAssignedReviewer(member.Role) {
			name := member.DisplayName
			if name == "" {
				name = member.Email
			}
			return member.UserID, name, nil
		}
	}
	return 0, "", domain.ErrInvalidReviewer
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
	var submittedBy, reviewedBy, assignedReviewerID *int64
	var submittedAt, reviewedAt *time.Time
	err := scanner.Scan(
		&review.ProjectID, &review.TargetObjectID, &review.BausteinID, &review.State, &review.ReviewNote,
		&review.ReturnedRequirementIDs,
		&submittedBy, &submittedAt, &reviewedBy, &reviewedAt, &assignedReviewerID,
		&review.AssignedReviewerName, &review.UpdatedAt,
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
	if assignedReviewerID != nil {
		review.AssignedReviewerID = *assignedReviewerID
	}
	return review, nil
}
