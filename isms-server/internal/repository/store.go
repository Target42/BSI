package repository

import (
	"context"
	"errors"
	"fmt"
	"strings"

	"github.com/Target42/BSI/isms-server/internal/auth"
	"github.com/Target42/BSI/isms-server/internal/domain"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

var ErrNotFound = errors.New("not found")
var ErrForbidden = errors.New("forbidden")
var ErrVersionConflict = errors.New("version conflict")

type Store struct {
	pool *pgxpool.Pool
}

func New(pool *pgxpool.Pool) *Store {
	return &Store{pool: pool}
}

func (s *Store) CountUsers(ctx context.Context) (int64, error) {
	var count int64
	err := s.pool.QueryRow(ctx, `SELECT COUNT(*) FROM users`).Scan(&count)
	return count, err
}

func (s *Store) CreateUser(ctx context.Context, email, displayName, passwordHash string) (domain.User, error) {
	var user domain.User
	err := s.pool.QueryRow(ctx, `
		INSERT INTO users (email, display_name, password_hash)
		VALUES ($1, $2, $3)
		RETURNING id, email, display_name, created_at`,
		email, displayName, passwordHash,
	).Scan(&user.ID, &user.Email, &user.DisplayName, &user.CreatedAt)
	return user, err
}

func (s *Store) FindUserByEmail(ctx context.Context, email string) (domain.User, string, error) {
	var user domain.User
	var passwordHash string
	err := s.pool.QueryRow(ctx, `
		SELECT id, email, display_name, password_hash, token_version, created_at
		FROM users WHERE email = $1`, email,
	).Scan(&user.ID, &user.Email, &user.DisplayName, &passwordHash, &user.TokenVersion, &user.CreatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return domain.User{}, "", ErrNotFound
	}
	return user, passwordHash, err
}

func (s *Store) UserByID(ctx context.Context, id int64) (domain.User, error) {
	var user domain.User
	err := s.pool.QueryRow(ctx, `
		SELECT id, email, display_name, is_admin, created_at
		FROM users WHERE id = $1`, id,
	).Scan(&user.ID, &user.Email, &user.DisplayName, &user.IsAdmin, &user.CreatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return domain.User{}, ErrNotFound
	}
	return user, err
}

func (s *Store) TokenVersion(ctx context.Context, userID int64) (int, error) {
	var version int
	err := s.pool.QueryRow(ctx, `SELECT token_version FROM users WHERE id = $1`, userID).Scan(&version)
	if errors.Is(err, pgx.ErrNoRows) {
		return 0, ErrNotFound
	}
	return version, err
}

func (s *Store) UpdatePasswordHash(ctx context.Context, userID int64, passwordHash string) (int, error) {
	var version int
	err := s.pool.QueryRow(ctx, `
		UPDATE users SET password_hash = $2, token_version = token_version + 1
		WHERE id = $1
		RETURNING token_version`, userID, passwordHash,
	).Scan(&version)
	if errors.Is(err, pgx.ErrNoRows) {
		return 0, ErrNotFound
	}
	return version, err
}

func (s *Store) ProjectRole(ctx context.Context, projectID, userID int64) (string, error) {
	var role string
	err := s.pool.QueryRow(ctx, `
		SELECT role FROM project_members
		WHERE project_id = $1 AND user_id = $2`, projectID, userID,
	).Scan(&role)
	if errors.Is(err, pgx.ErrNoRows) {
		return "", ErrForbidden
	}
	return role, err
}

func (s *Store) RequireProjectRole(ctx context.Context, projectID int64, user *auth.Claims, minRole string) (string, error) {
	access, err := s.projectAccess(ctx, projectID, user, minRole, true)
	if err != nil {
		return "", err
	}
	return access.Role, nil
}

func (s *Store) RequireProjectMember(ctx context.Context, projectID int64, user *auth.Claims, minRole string) (string, error) {
	access, err := s.projectAccess(ctx, projectID, user, minRole, false)
	if err != nil {
		return "", err
	}
	return access.Role, nil
}

func (s *Store) LoadAccessibleProject(ctx context.Context, projectID int64, user *auth.Claims, minRole string, membersOnly bool) (domain.Project, string, error) {
	access, err := s.projectAccess(ctx, projectID, user, minRole, !membersOnly)
	if err != nil {
		return domain.Project{}, "", err
	}
	project, err := s.GetProject(ctx, projectID)
	if err != nil {
		return domain.Project{}, "", err
	}
	project.Role = access.Role
	project.IsMember = access.IsMember
	return project, access.Role, nil
}

type projectAccessResult struct {
	Role       string
	IsMember   bool
	Visibility string
}

func (s *Store) projectAccess(ctx context.Context, projectID int64, user *auth.Claims, minRole string, allowPublic bool) (projectAccessResult, error) {
	var userID int64
	if user != nil {
		userID = user.UserID
	}
	var visibility, memberRole string
	err := s.pool.QueryRow(ctx, `
		SELECT p.visibility,
		       COALESCE((
		           SELECT pm.role FROM project_members pm
		           WHERE pm.project_id = p.id AND pm.user_id = $2
		       ), '')
		FROM projects p
		WHERE p.id = $1`, projectID, userID,
	).Scan(&visibility, &memberRole)
	if errors.Is(err, pgx.ErrNoRows) {
		return projectAccessResult{}, ErrNotFound
	}
	if err != nil {
		return projectAccessResult{}, err
	}

	result := projectAccessResult{Role: memberRole, IsMember: memberRole != "", Visibility: visibility}
	if !allowPublic {
		if memberRole == "" || domain.RoleRank(memberRole) < domain.RoleRank(minRole) {
			return result, ErrForbidden
		}
		return result, nil
	}
	role, ok := domain.ResolveProjectRole(memberRole, visibility, minRole)
	if !ok {
		return result, ErrForbidden
	}
	result.Role = role
	return result, nil
}

const projectColumns = `id, name, description, catalog_version, visibility, created_at, updated_at`

func scanProject(scanner interface {
	Scan(dest ...any) error
}, extra ...any) (domain.Project, error) {
	var p domain.Project
	dest := []any{&p.ID, &p.Name, &p.Description, &p.CatalogVersion, &p.Visibility, &p.CreatedAt, &p.UpdatedAt}
	dest = append(dest, extra...)
	err := scanner.Scan(dest...)
	if p.Visibility == "" {
		p.Visibility = domain.VisibilityPrivate
	}
	return p, err
}

func (s *Store) ListProjects(ctx context.Context, userID int64) ([]domain.Project, error) {
	query := `
		SELECT p.id, p.name, p.description, p.catalog_version, p.visibility, p.created_at, p.updated_at,
		       'viewer' AS role, FALSE AS is_member
		FROM projects p
		WHERE p.visibility = 'public'
		ORDER BY p.updated_at DESC`
	args := []any{}
	if userID > 0 {
		query = `
			SELECT p.id, p.name, p.description, p.catalog_version, p.visibility, p.created_at, p.updated_at,
			       COALESCE(pm.role, 'viewer') AS role, (pm.user_id IS NOT NULL) AS is_member
			FROM projects p
			LEFT JOIN project_members pm ON pm.project_id = p.id AND pm.user_id = $1
			WHERE pm.user_id IS NOT NULL OR p.visibility = 'public'
			ORDER BY p.updated_at DESC`
		args = []any{userID}
	}
	rows, err := s.pool.Query(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var projects []domain.Project
	for rows.Next() {
		var role string
		var isMember bool
		p, err := scanProject(rows, &role, &isMember)
		if err != nil {
			return nil, err
		}
		p.Role = role
		p.IsMember = isMember
		projects = append(projects, p)
	}
	return projects, rows.Err()
}

func (s *Store) CreateProject(ctx context.Context, userID int64, name, description, catalogVersion, visibility string) (domain.Project, error) {
	visibility = domain.NormalizeVisibility(visibility)
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return domain.Project{}, err
	}
	defer tx.Rollback(ctx)

	var project domain.Project
	err = tx.QueryRow(ctx, `
		INSERT INTO projects (name, description, catalog_version, visibility)
		VALUES ($1, $2, $3, $4)
		RETURNING `+projectColumns,
		name, description, catalogVersion, visibility,
	).Scan(&project.ID, &project.Name, &project.Description, &project.CatalogVersion, &project.Visibility, &project.CreatedAt, &project.UpdatedAt)
	if err != nil {
		return domain.Project{}, err
	}

	_, err = tx.Exec(ctx, `
		INSERT INTO project_members (project_id, user_id, role)
		VALUES ($1, $2, 'owner')`, project.ID, userID)
	if err != nil {
		return domain.Project{}, err
	}

	_, err = tx.Exec(ctx, `
		INSERT INTO target_objects (project_id, parent_id, type, name, description)
		VALUES ($1, 0, 'Informationsverbund', $2, $3)`,
		project.ID, name, description)
	if err != nil {
		return domain.Project{}, err
	}

	if err := tx.Commit(ctx); err != nil {
		return domain.Project{}, err
	}
	project.Role = "owner"
	project.IsMember = true
	return project, nil
}

func (s *Store) GetProject(ctx context.Context, projectID int64) (domain.Project, error) {
	var p domain.Project
	err := s.pool.QueryRow(ctx, `
		SELECT `+projectColumns+`
		FROM projects WHERE id = $1`, projectID,
	).Scan(&p.ID, &p.Name, &p.Description, &p.CatalogVersion, &p.Visibility, &p.CreatedAt, &p.UpdatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return domain.Project{}, ErrNotFound
	}
	if p.Visibility == "" {
		p.Visibility = domain.VisibilityPrivate
	}
	return p, err
}

func (s *Store) UpdateProject(ctx context.Context, project domain.Project) (domain.Project, error) {
	project.Visibility = domain.NormalizeVisibility(project.Visibility)
	err := s.pool.QueryRow(ctx, `
		UPDATE projects
		SET name = $2, description = $3, visibility = $4, updated_at = now()
		WHERE id = $1
		RETURNING `+projectColumns,
		project.ID, project.Name, project.Description, project.Visibility,
	).Scan(&project.ID, &project.Name, &project.Description, &project.CatalogVersion, &project.Visibility, &project.CreatedAt, &project.UpdatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return domain.Project{}, ErrNotFound
	}
	return project, err
}

func (s *Store) DeleteProject(ctx context.Context, projectID int64) error {
	tag, err := s.pool.Exec(ctx, `DELETE FROM projects WHERE id = $1`, projectID)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

const targetObjectColumns = `
	id, project_id, parent_id, type, protection_need,
	confidentiality, integrity, availability, inherit_protection_need, protection_need_note,
	name, description, created_at, updated_at`

func scanTargetObject(scanner interface{ Scan(dest ...any) error }) (domain.TargetObject, error) {
	var t domain.TargetObject
	err := scanner.Scan(
		&t.ID, &t.ProjectID, &t.ParentID, &t.Type, &t.ProtectionNeed,
		&t.Confidentiality, &t.Integrity, &t.Availability, &t.InheritProtectionNeed, &t.ProtectionNeedNote,
		&t.Name, &t.Description, &t.CreatedAt, &t.UpdatedAt,
	)
	return t, err
}

func (s *Store) listTargetObjectsRaw(ctx context.Context, projectID int64) ([]domain.TargetObject, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT `+targetObjectColumns+`
		FROM target_objects
		WHERE project_id = $1
		ORDER BY parent_id, id`, projectID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var items []domain.TargetObject
	for rows.Next() {
		t, err := scanTargetObject(rows)
		if err != nil {
			return nil, err
		}
		items = append(items, t)
	}
	return items, rows.Err()
}

func (s *Store) persistInheritedProtectionNeed(ctx context.Context, t domain.TargetObject) error {
	_, err := s.pool.Exec(ctx, `
		UPDATE target_objects
		SET confidentiality = $2, integrity = $3, availability = $4, protection_need = $5, updated_at = now()
		WHERE id = $1`,
		t.ID, t.Confidentiality, t.Integrity, t.Availability, t.ProtectionNeed,
	)
	return err
}

func (s *Store) cascadeInheritedProtectionNeed(ctx context.Context, projectID int64) error {
	items, err := s.listTargetObjectsRaw(ctx, projectID)
	if err != nil {
		return err
	}
	domain.ResolveInheritedProtectionNeeds(items)
	for _, item := range items {
		if !item.InheritProtectionNeed {
			continue
		}
		if err := s.persistInheritedProtectionNeed(ctx, item); err != nil {
			return err
		}
	}
	return nil
}

func (s *Store) ListTargetObjects(ctx context.Context, projectID int64) ([]domain.TargetObject, error) {
	items, err := s.listTargetObjectsRaw(ctx, projectID)
	if err != nil {
		return nil, err
	}
	domain.ResolveInheritedProtectionNeeds(items)
	return items, nil
}

func (s *Store) GetTargetObject(ctx context.Context, id int64) (domain.TargetObject, error) {
	t, err := scanTargetObject(s.pool.QueryRow(ctx, `
		SELECT `+targetObjectColumns+`
		FROM target_objects WHERE id = $1`, id))
	if errors.Is(err, pgx.ErrNoRows) {
		return domain.TargetObject{}, ErrNotFound
	}
	if err != nil {
		return domain.TargetObject{}, err
	}
	if t.InheritProtectionNeed && t.ParentID > 0 {
		items, listErr := s.ListTargetObjects(ctx, t.ProjectID)
		if listErr != nil {
			return domain.TargetObject{}, listErr
		}
		for _, item := range items {
			if item.ID == t.ID {
				return item, nil
			}
		}
	}
	domain.ApplyTargetObjectProtectionNeed(&t, nil)
	return t, nil
}

func (s *Store) CreateTargetObject(ctx context.Context, t domain.TargetObject) (domain.TargetObject, error) {
	created, err := scanTargetObject(s.pool.QueryRow(ctx, `
		INSERT INTO target_objects (
			project_id, parent_id, type, protection_need,
			confidentiality, integrity, availability, inherit_protection_need, protection_need_note,
			name, description)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
		RETURNING `+targetObjectColumns,
		t.ProjectID, t.ParentID, t.Type, t.ProtectionNeed,
		t.Confidentiality, t.Integrity, t.Availability, t.InheritProtectionNeed, t.ProtectionNeedNote,
		t.Name, t.Description,
	))
	return created, err
}

func (s *Store) UpdateTargetObject(ctx context.Context, t domain.TargetObject) (domain.TargetObject, error) {
	updated, err := scanTargetObject(s.pool.QueryRow(ctx, `
		UPDATE target_objects
		SET parent_id = $2, type = $3, protection_need = $4,
			confidentiality = $5, integrity = $6, availability = $7,
			inherit_protection_need = $8, protection_need_note = $9,
			name = $10, description = $11, updated_at = now()
		WHERE id = $1
		RETURNING `+targetObjectColumns,
		t.ID, t.ParentID, t.Type, t.ProtectionNeed,
		t.Confidentiality, t.Integrity, t.Availability, t.InheritProtectionNeed, t.ProtectionNeedNote,
		t.Name, t.Description,
	))
	if errors.Is(err, pgx.ErrNoRows) {
		return domain.TargetObject{}, ErrNotFound
	}
	if err != nil {
		return domain.TargetObject{}, err
	}
	if err := s.cascadeInheritedProtectionNeed(ctx, updated.ProjectID); err != nil {
		return domain.TargetObject{}, err
	}
	return s.GetTargetObject(ctx, updated.ID)
}

func (s *Store) DeleteTargetObject(ctx context.Context, targetObjectID int64) error {
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)

	if err := s.deleteTargetSubtree(ctx, tx, targetObjectID); err != nil {
		return err
	}
	return tx.Commit(ctx)
}

func (s *Store) deleteTargetSubtree(ctx context.Context, tx pgx.Tx, rootID int64) error {
	rows, err := tx.Query(ctx, `SELECT id FROM target_objects WHERE parent_id = $1`, rootID)
	if err != nil {
		return err
	}
	var childIDs []int64
	for rows.Next() {
		var id int64
		if err := rows.Scan(&id); err != nil {
			rows.Close()
			return err
		}
		childIDs = append(childIDs, id)
	}
	rows.Close()
	if err := rows.Err(); err != nil {
		return err
	}
	for _, childID := range childIDs {
		if err := s.deleteTargetSubtree(ctx, tx, childID); err != nil {
			return err
		}
	}
	tag, err := tx.Exec(ctx, `DELETE FROM target_objects WHERE id = $1`, rootID)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

func (s *Store) TargetObjectProjectID(ctx context.Context, targetObjectID int64) (int64, error) {
	var projectID int64
	err := s.pool.QueryRow(ctx, `SELECT project_id FROM target_objects WHERE id = $1`, targetObjectID).Scan(&projectID)
	if errors.Is(err, pgx.ErrNoRows) {
		return 0, ErrNotFound
	}
	return projectID, err
}

func (s *Store) ListAssessments(ctx context.Context, projectID, targetObjectID int64) ([]domain.RequirementAssessment, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT id, project_id, target_object_id, requirement_id, status, note, responsible,
		       due_date::text, version, updated_at
		FROM requirement_assessments
		WHERE project_id = $1 AND target_object_id = $2
		ORDER BY requirement_id`, projectID, targetObjectID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var items []domain.RequirementAssessment
	for rows.Next() {
		var a domain.RequirementAssessment
		var dueDate *string
		if err := rows.Scan(&a.ID, &a.ProjectID, &a.TargetObjectID, &a.RequirementID, &a.Status, &a.Note, &a.Responsible, &dueDate, &a.Version, &a.UpdatedAt); err != nil {
			return nil, err
		}
		a.DueDate = dueDate
		items = append(items, a)
	}
	return items, rows.Err()
}

func (s *Store) GetAssessment(ctx context.Context, projectID, targetObjectID, requirementID int64) (domain.RequirementAssessment, error) {
	var a domain.RequirementAssessment
	var dueDate *string
	err := s.pool.QueryRow(ctx, `
		SELECT id, project_id, target_object_id, requirement_id, status, note, responsible,
		       due_date::text, version, updated_at
		FROM requirement_assessments
		WHERE project_id = $1 AND target_object_id = $2 AND requirement_id = $3`,
		projectID, targetObjectID, requirementID,
	).Scan(&a.ID, &a.ProjectID, &a.TargetObjectID, &a.RequirementID, &a.Status, &a.Note, &a.Responsible, &dueDate, &a.Version, &a.UpdatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return domain.RequirementAssessment{
			ProjectID:      projectID,
			TargetObjectID: targetObjectID,
			RequirementID:  requirementID,
			Status:         "Offen",
			Version:        0,
		}, nil
	}
	a.DueDate = dueDate
	return a, err
}

func (s *Store) SaveAssessment(ctx context.Context, assessment domain.RequirementAssessment) (domain.RequirementAssessment, error) {
	if assessment.Version > 0 {
		tag, err := s.pool.Exec(ctx, `
			UPDATE requirement_assessments
			SET status = $4, note = $5, responsible = $6, due_date = $7,
			    version = version + 1, updated_at = now()
			WHERE project_id = $1 AND target_object_id = $2 AND requirement_id = $3 AND version = $8`,
			assessment.ProjectID, assessment.TargetObjectID, assessment.RequirementID,
			assessment.Status, assessment.Note, assessment.Responsible, nullableDate(assessment.DueDate), assessment.Version,
		)
		if err != nil {
			return domain.RequirementAssessment{}, err
		}
		if tag.RowsAffected() == 0 {
			current, err := s.GetAssessment(ctx, assessment.ProjectID, assessment.TargetObjectID, assessment.RequirementID)
			if err != nil {
				return domain.RequirementAssessment{}, err
			}
			if current.Version == 0 {
				return domain.RequirementAssessment{}, fmt.Errorf("%w: stale version", ErrVersionConflict)
			}
			return current, fmt.Errorf("%w", ErrVersionConflict)
		}
	} else {
		_, err := s.pool.Exec(ctx, `
			INSERT INTO requirement_assessments
			(project_id, target_object_id, requirement_id, status, note, responsible, due_date)
			VALUES ($1, $2, $3, $4, $5, $6, $7)
			ON CONFLICT (project_id, target_object_id, requirement_id) DO UPDATE SET
			  status = EXCLUDED.status,
			  note = EXCLUDED.note,
			  responsible = EXCLUDED.responsible,
			  due_date = EXCLUDED.due_date,
			  version = requirement_assessments.version + 1,
			  updated_at = now()`,
			assessment.ProjectID, assessment.TargetObjectID, assessment.RequirementID,
			assessment.Status, assessment.Note, assessment.Responsible, nullableDate(assessment.DueDate),
		)
		if err != nil {
			return domain.RequirementAssessment{}, err
		}
	}

	_, err := s.pool.Exec(ctx, `UPDATE projects SET updated_at = now() WHERE id = $1`, assessment.ProjectID)
	if err != nil {
		return domain.RequirementAssessment{}, err
	}
	return s.GetAssessment(ctx, assessment.ProjectID, assessment.TargetObjectID, assessment.RequirementID)
}

func (s *Store) ApplicabilityMap(ctx context.Context, projectID, targetObjectID int64) (map[int64]string, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT baustein_id, status
		FROM baustein_applicability
		WHERE project_id = $1 AND target_object_id = $2`, projectID, targetObjectID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	result := make(map[int64]string)
	for rows.Next() {
		var bausteinID int64
		var status string
		if err := rows.Scan(&bausteinID, &status); err != nil {
			return nil, err
		}
		result[bausteinID] = status
	}
	return result, rows.Err()
}

func (s *Store) SaveApplicability(ctx context.Context, item domain.BausteinApplicability) (domain.BausteinApplicability, error) {
	err := s.pool.QueryRow(ctx, `
		INSERT INTO baustein_applicability (project_id, target_object_id, baustein_id, status)
		VALUES ($1, $2, $3, $4)
		ON CONFLICT (project_id, target_object_id, baustein_id) DO UPDATE SET status = EXCLUDED.status
		RETURNING id, project_id, target_object_id, baustein_id, status`,
		item.ProjectID, item.TargetObjectID, item.BausteinID, item.Status,
	).Scan(&item.ID, &item.ProjectID, &item.TargetObjectID, &item.BausteinID, &item.Status)
	return item, err
}

func (s *Store) DeleteApplicability(ctx context.Context, projectID, targetObjectID, bausteinID int64) error {
	_, err := s.pool.Exec(ctx, `
		DELETE FROM baustein_applicability
		WHERE project_id = $1 AND target_object_id = $2 AND baustein_id = $3`,
		projectID, targetObjectID, bausteinID)
	return err
}

func (s *Store) GetDeviation(ctx context.Context, projectID, targetObjectID, bausteinID int64) (string, error) {
	var note string
	err := s.pool.QueryRow(ctx, `
		SELECT note FROM baustein_deviations
		WHERE project_id = $1 AND target_object_id = $2 AND baustein_id = $3`,
		projectID, targetObjectID, bausteinID).Scan(&note)
	if errors.Is(err, pgx.ErrNoRows) {
		return "", nil
	}
	return note, err
}

func (s *Store) SaveDeviation(ctx context.Context, projectID, targetObjectID, bausteinID int64, note string) error {
	if strings.TrimSpace(note) == "" {
		return s.DeleteDeviation(ctx, projectID, targetObjectID, bausteinID)
	}
	_, err := s.pool.Exec(ctx, `
		INSERT INTO baustein_deviations (project_id, target_object_id, baustein_id, note)
		VALUES ($1, $2, $3, $4)
		ON CONFLICT (project_id, target_object_id, baustein_id) DO UPDATE SET note = EXCLUDED.note`,
		projectID, targetObjectID, bausteinID, note)
	return err
}

func (s *Store) DeleteDeviation(ctx context.Context, projectID, targetObjectID, bausteinID int64) error {
	_, err := s.pool.Exec(ctx, `
		DELETE FROM baustein_deviations
		WHERE project_id = $1 AND target_object_id = $2 AND baustein_id = $3`,
		projectID, targetObjectID, bausteinID)
	return err
}

func nullableDate(value *string) any {
	if value == nil || *value == "" {
		return nil
	}
	return *value
}
