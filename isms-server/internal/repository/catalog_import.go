package repository

import (
	"context"

	"github.com/Target42/BSI/isms-server/internal/catalog"
	"github.com/Target42/BSI/isms-server/internal/domain"
)

func (s *Store) ReplaceGrundschutzCatalog(ctx context.Context, result catalog.ImportResult) error {
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)

	if _, err := tx.Exec(ctx, `DELETE FROM requirements`); err != nil {
		return err
	}
	if _, err := tx.Exec(ctx, `
		DELETE FROM bausteine WHERE standard = $1 AND catalog_version = $2`,
		catalog.StandardITGrundschutz, result.CatalogVersion); err != nil {
		return err
	}

	bausteinIDs := make(map[string]int64, len(result.Bausteine))
	for _, b := range result.Bausteine {
		var id int64
		err := tx.QueryRow(ctx, `
			INSERT INTO bausteine (standard, external_id, title, group_name, catalog_version)
			VALUES ($1, $2, $3, $4, $5)
			RETURNING id`,
			b.Standard, b.ExternalID, b.Title, b.GroupName, result.CatalogVersion,
		).Scan(&id)
		if err != nil {
			return err
		}
		bausteinIDs[b.ExternalID] = id
	}

	for _, r := range result.Requirements {
		bausteinID, ok := bausteinIDs[r.BausteinExternalID]
		if !ok {
			continue
		}
		_, err := tx.Exec(ctx, `
			INSERT INTO requirements
			(baustein_id, standard, external_id, baustein_external_id, title, text, level, responsible_role, withdrawn)
			VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)`,
			bausteinID, r.Standard, r.ExternalID, r.BausteinExternalID,
			r.Title, r.Text, r.Level, r.ResponsibleRole, r.Withdrawn,
		)
		if err != nil {
			return err
		}
	}

	_, err = tx.Exec(ctx, `
		INSERT INTO catalog_meta (key, value) VALUES ('grundschutz_version', $1)
		ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value`, result.CatalogVersion)
	if err != nil {
		return err
	}

	return tx.Commit(ctx)
}

func (s *Store) SetUserAdmin(ctx context.Context, userID int64, isAdmin bool) error {
	_, err := s.pool.Exec(ctx, `UPDATE users SET is_admin = $2 WHERE id = $1`, userID, isAdmin)
	return err
}

func (s *Store) IsAdmin(ctx context.Context, userID int64) (bool, error) {
	var isAdmin bool
	err := s.pool.QueryRow(ctx, `SELECT is_admin FROM users WHERE id = $1`, userID).Scan(&isAdmin)
	return isAdmin, err
}

func (s *Store) ListUsers(ctx context.Context) ([]domain.User, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT id, email, display_name, is_admin, created_at FROM users ORDER BY display_name, email`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var users []domain.User
	for rows.Next() {
		var u domain.User
		if err := rows.Scan(&u.ID, &u.Email, &u.DisplayName, &u.IsAdmin, &u.CreatedAt); err != nil {
			return nil, err
		}
		users = append(users, u)
	}
	return users, rows.Err()
}

type ProjectMember struct {
	UserID      int64  `json:"userId"`
	Email       string `json:"email"`
	DisplayName string `json:"displayName"`
	Role        string `json:"role"`
}

func (s *Store) ListProjectMembers(ctx context.Context, projectID int64) ([]ProjectMember, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT u.id, u.email, u.display_name, pm.role
		FROM project_members pm
		JOIN users u ON u.id = pm.user_id
		WHERE pm.project_id = $1
		ORDER BY pm.role DESC, u.display_name`, projectID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var members []ProjectMember
	for rows.Next() {
		var m ProjectMember
		if err := rows.Scan(&m.UserID, &m.Email, &m.DisplayName, &m.Role); err != nil {
			return nil, err
		}
		members = append(members, m)
	}
	return members, rows.Err()
}

func (s *Store) AddProjectMember(ctx context.Context, projectID, userID int64, role string) (ProjectMember, error) {
	_, err := s.pool.Exec(ctx, `
		INSERT INTO project_members (project_id, user_id, role)
		VALUES ($1, $2, $3)
		ON CONFLICT (project_id, user_id) DO UPDATE SET role = EXCLUDED.role`,
		projectID, userID, role)
	if err != nil {
		return ProjectMember{}, err
	}
	members, err := s.ListProjectMembers(ctx, projectID)
	if err != nil {
		return ProjectMember{}, err
	}
	for _, m := range members {
		if m.UserID == userID {
			return m, nil
		}
	}
	return ProjectMember{}, ErrNotFound
}

func (s *Store) UpdateProjectMemberRole(ctx context.Context, projectID, userID int64, role string) (ProjectMember, error) {
	tag, err := s.pool.Exec(ctx, `
		UPDATE project_members SET role = $3 WHERE project_id = $1 AND user_id = $2`,
		projectID, userID, role)
	if err != nil {
		return ProjectMember{}, err
	}
	if tag.RowsAffected() == 0 {
		return ProjectMember{}, ErrNotFound
	}
	members, err := s.ListProjectMembers(ctx, projectID)
	if err != nil {
		return ProjectMember{}, err
	}
	for _, m := range members {
		if m.UserID == userID {
			return m, nil
		}
	}
	return ProjectMember{}, ErrNotFound
}

func (s *Store) RemoveProjectMember(ctx context.Context, projectID, userID int64) error {
	tag, err := s.pool.Exec(ctx, `
		DELETE FROM project_members WHERE project_id = $1 AND user_id = $2`,
		projectID, userID)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

func (s *Store) CountProjectOwners(ctx context.Context, projectID int64) (int, error) {
	var count int
	err := s.pool.QueryRow(ctx, `
		SELECT COUNT(*) FROM project_members WHERE project_id = $1 AND role = 'owner'`, projectID,
	).Scan(&count)
	return count, err
}
