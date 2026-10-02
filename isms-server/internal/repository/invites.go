package repository

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"time"

	"github.com/Target42/BSI/isms-server/internal/domain"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
)

type ProjectInvite struct {
	ID        int64
	ProjectID int64
	Token     string
	Role      string
	CreatedAt time.Time
}

func newInviteToken() (string, error) {
	buf := make([]byte, 32)
	if _, err := rand.Read(buf); err != nil {
		return "", err
	}
	return hex.EncodeToString(buf), nil
}

func (s *Store) CreateProjectInvite(ctx context.Context, projectID, createdBy int64, role string) (ProjectInvite, error) {
	var lastErr error
	for attempt := 0; attempt < 3; attempt++ {
		token, err := newInviteToken()
		if err != nil {
			return ProjectInvite{}, err
		}
		invite, err := scanInvite(s.pool.QueryRow(ctx, `
			INSERT INTO project_invites (project_id, token, role, created_by)
			VALUES ($1, $2, $3, $4)
			RETURNING id, project_id, token, role, created_at`,
			projectID, token, role, createdBy,
		))
		if err == nil {
			return invite, nil
		}
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23505" {
			lastErr = err
			continue
		}
		return ProjectInvite{}, err
	}
	if lastErr == nil {
		lastErr = fmt.Errorf("create invite")
	}
	return ProjectInvite{}, lastErr
}

func (s *Store) ListActiveProjectInvites(ctx context.Context, projectID int64) ([]ProjectInvite, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT id, project_id, token, role, created_at
		FROM project_invites
		WHERE project_id = $1 AND revoked_at IS NULL
		ORDER BY created_at DESC, id DESC`, projectID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var invites []ProjectInvite
	for rows.Next() {
		invite, err := scanInvite(rows)
		if err != nil {
			return nil, err
		}
		invites = append(invites, invite)
	}
	return invites, rows.Err()
}

func (s *Store) RevokeProjectInvite(ctx context.Context, projectID, inviteID int64) error {
	tag, err := s.pool.Exec(ctx, `
		UPDATE project_invites
		SET revoked_at = now()
		WHERE id = $1 AND project_id = $2 AND revoked_at IS NULL`,
		inviteID, projectID)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

func (s *Store) FindActiveProjectInvite(ctx context.Context, token string) (ProjectInvite, domain.Project, error) {
	var invite ProjectInvite
	var project domain.Project
	err := s.pool.QueryRow(ctx, `
		SELECT i.id, i.project_id, i.token, i.role, i.created_at, p.name
		FROM project_invites i
		JOIN projects p ON p.id = i.project_id
		WHERE i.token = $1 AND i.revoked_at IS NULL`, token,
	).Scan(&invite.ID, &invite.ProjectID, &invite.Token, &invite.Role, &invite.CreatedAt, &project.Name)
	if errors.Is(err, pgx.ErrNoRows) {
		return ProjectInvite{}, domain.Project{}, ErrNotFound
	}
	if err != nil {
		return ProjectInvite{}, domain.Project{}, err
	}
	project.ID = invite.ProjectID
	return invite, project, nil
}

func (s *Store) AcceptProjectInvite(ctx context.Context, token string, userID int64) (int64, bool, error) {
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return 0, false, err
	}
	defer tx.Rollback(ctx)

	var projectID int64
	var role string
	err = tx.QueryRow(ctx, `
		SELECT project_id, role
		FROM project_invites
		WHERE token = $1 AND revoked_at IS NULL`, token,
	).Scan(&projectID, &role)
	if errors.Is(err, pgx.ErrNoRows) {
		return 0, false, ErrNotFound
	}
	if err != nil {
		return 0, false, err
	}

	var existing string
	err = tx.QueryRow(ctx, `
		SELECT role FROM project_members
		WHERE project_id = $1 AND user_id = $2`, projectID, userID,
	).Scan(&existing)
	if err == nil {
		if err := tx.Commit(ctx); err != nil {
			return 0, false, err
		}
		return projectID, true, nil
	}
	if !errors.Is(err, pgx.ErrNoRows) {
		return 0, false, err
	}

	_, err = tx.Exec(ctx, `
		INSERT INTO project_members (project_id, user_id, role)
		VALUES ($1, $2, $3)`, projectID, userID, role)
	if err != nil {
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23505" {
			if err := tx.Commit(ctx); err != nil {
				return 0, false, err
			}
			return projectID, true, nil
		}
		return 0, false, err
	}
	if err := tx.Commit(ctx); err != nil {
		return 0, false, err
	}
	return projectID, false, nil
}

type inviteScanner interface {
	Scan(dest ...any) error
}

func scanInvite(row inviteScanner) (ProjectInvite, error) {
	var invite ProjectInvite
	err := row.Scan(&invite.ID, &invite.ProjectID, &invite.Token, &invite.Role, &invite.CreatedAt)
	return invite, err
}
