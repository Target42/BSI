package repository

import (
	"context"
	"errors"

	"github.com/Target42/BSI/isms-server/internal/domain"
	"github.com/jackc/pgx/v5"
)

func (s *Store) InsertNotifications(ctx context.Context, items []domain.Notification) error {
	for _, item := range items {
		if item.UserID <= 0 || item.ProjectID <= 0 {
			continue
		}
		if _, err := s.pool.Exec(ctx, `
			INSERT INTO notifications (
				user_id, project_id, target_object_id, baustein_id, kind, title, body, link_path
			) VALUES ($1, $2, NULLIF($3, 0), NULLIF($4, 0), $5, $6, $7, $8)`,
			item.UserID, item.ProjectID, item.TargetObjectID, item.BausteinID,
			item.Kind, item.Title, item.Body, item.LinkPath); err != nil {
			return err
		}
	}
	return nil
}

func (s *Store) ListNotifications(ctx context.Context, userID int64) ([]domain.Notification, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT n.id, n.user_id, n.project_id, COALESCE(p.name, ''),
		       COALESCE(n.target_object_id, 0), COALESCE(n.baustein_id, 0),
		       n.kind, n.title, n.body, n.link_path, n.read_at, n.created_at
		FROM notifications n
		JOIN projects p ON p.id = n.project_id
		WHERE n.user_id = $1
		ORDER BY n.created_at DESC, n.id DESC
		LIMIT 200`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := make([]domain.Notification, 0)
	for rows.Next() {
		var item domain.Notification
		if err := rows.Scan(
			&item.ID, &item.UserID, &item.ProjectID, &item.ProjectName,
			&item.TargetObjectID, &item.BausteinID,
			&item.Kind, &item.Title, &item.Body, &item.LinkPath, &item.ReadAt, &item.CreatedAt,
		); err != nil {
			return nil, err
		}
		out = append(out, item)
	}
	return out, rows.Err()
}

func (s *Store) UnreadNotificationCount(ctx context.Context, userID int64) (int, error) {
	var count int
	err := s.pool.QueryRow(ctx, `
		SELECT COUNT(*) FROM notifications
		WHERE user_id = $1 AND read_at IS NULL`, userID).Scan(&count)
	return count, err
}

func (s *Store) MarkNotificationRead(ctx context.Context, userID, notificationID int64) error {
	var id int64
	err := s.pool.QueryRow(ctx, `
		UPDATE notifications SET read_at = COALESCE(read_at, now())
		WHERE id = $1 AND user_id = $2
		RETURNING id`, notificationID, userID).Scan(&id)
	if errors.Is(err, pgx.ErrNoRows) {
		return ErrNotFound
	}
	return err
}

func (s *Store) MarkAllNotificationsRead(ctx context.Context, userID int64) error {
	_, err := s.pool.Exec(ctx, `
		UPDATE notifications SET read_at = now()
		WHERE user_id = $1 AND read_at IS NULL`, userID)
	return err
}

func (s *Store) GetNotification(ctx context.Context, userID, notificationID int64) (domain.Notification, error) {
	var item domain.Notification
	err := s.pool.QueryRow(ctx, `
		SELECT n.id, n.user_id, n.project_id, COALESCE(p.name, ''),
		       COALESCE(n.target_object_id, 0), COALESCE(n.baustein_id, 0),
		       n.kind, n.title, n.body, n.link_path, n.read_at, n.created_at
		FROM notifications n
		JOIN projects p ON p.id = n.project_id
		WHERE n.id = $1 AND n.user_id = $2`,
		notificationID, userID).Scan(
		&item.ID, &item.UserID, &item.ProjectID, &item.ProjectName,
		&item.TargetObjectID, &item.BausteinID,
		&item.Kind, &item.Title, &item.Body, &item.LinkPath, &item.ReadAt, &item.CreatedAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return domain.Notification{}, ErrNotFound
	}
	return item, err
}

func (s *Store) ListBausteinResponsibleUserIDs(ctx context.Context, projectID, targetObjectID, bausteinID int64) ([]int64, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT DISTINCT responsible_user_id FROM (
			SELECT a.responsible_user_id
			FROM requirement_assessments a
			JOIN requirements r ON r.id = a.requirement_id
			WHERE a.project_id = $1 AND a.target_object_id = $2 AND r.baustein_id = $3
			  AND a.responsible_user_id IS NOT NULL
			UNION
			SELECT m.responsible_user_id
			FROM measures m
			JOIN requirements r ON r.id = m.requirement_id
			WHERE m.project_id = $1 AND m.target_object_id = $2 AND r.baustein_id = $3
			  AND m.responsible_user_id IS NOT NULL
		) q`, projectID, targetObjectID, bausteinID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var ids []int64
	for rows.Next() {
		var id int64
		if err := rows.Scan(&id); err != nil {
			return nil, err
		}
		ids = append(ids, id)
	}
	return ids, rows.Err()
}

func (s *Store) UsersByIDs(ctx context.Context, ids []int64) ([]domain.User, error) {
	if len(ids) == 0 {
		return nil, nil
	}
	rows, err := s.pool.Query(ctx, `
		SELECT id, email, display_name, is_admin, created_at
		FROM users WHERE id = ANY($1)`, ids)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var users []domain.User
	for rows.Next() {
		var user domain.User
		if err := rows.Scan(&user.ID, &user.Email, &user.DisplayName, &user.IsAdmin, &user.CreatedAt); err != nil {
			return nil, err
		}
		users = append(users, user)
	}
	return users, rows.Err()
}
