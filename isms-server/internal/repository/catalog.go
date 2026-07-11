package repository

import (
	"context"
	"errors"

	"github.com/Target42/BSI/isms-server/internal/domain"
	"github.com/jackc/pgx/v5"
)

func (s *Store) ListCatalogVersions(ctx context.Context) ([]string, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT DISTINCT catalog_version FROM bausteine ORDER BY catalog_version DESC`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var versions []string
	for rows.Next() {
		var version string
		if err := rows.Scan(&version); err != nil {
			return nil, err
		}
		versions = append(versions, version)
	}
	return versions, rows.Err()
}

func (s *Store) HasCatalog(ctx context.Context, catalogVersion string) (bool, error) {
	var exists bool
	err := s.pool.QueryRow(ctx, `
		SELECT EXISTS(
			SELECT 1 FROM bausteine WHERE catalog_version = $1 LIMIT 1
		)`, catalogVersion).Scan(&exists)
	return exists, err
}

func (s *Store) ListBausteine(ctx context.Context, standard, catalogVersion string) ([]domain.Baustein, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT id, standard, external_id, title, COALESCE(group_name, ''), catalog_version
		FROM bausteine
		WHERE standard = $1 AND catalog_version = $2
		ORDER BY external_id`, standard, catalogVersion)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var items []domain.Baustein
	for rows.Next() {
		var b domain.Baustein
		if err := rows.Scan(&b.ID, &b.Standard, &b.ExternalID, &b.Title, &b.GroupName, &b.CatalogVersion); err != nil {
			return nil, err
		}
		items = append(items, b)
	}
	return items, rows.Err()
}

func (s *Store) ListRequirements(ctx context.Context, bausteinID int64) ([]domain.Requirement, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT id, baustein_id, standard, external_id, baustein_external_id, title,
		       COALESCE(text, ''), level, COALESCE(responsible_role, ''), withdrawn
		FROM requirements
		WHERE baustein_id = $1
		ORDER BY external_id`, bausteinID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var items []domain.Requirement
	for rows.Next() {
		var r domain.Requirement
		if err := rows.Scan(
			&r.ID, &r.BausteinID, &r.Standard, &r.ExternalID, &r.BausteinExternalID,
			&r.Title, &r.Text, &r.Level, &r.ResponsibleRole, &r.Withdrawn,
		); err != nil {
			return nil, err
		}
		items = append(items, r)
	}
	return items, rows.Err()
}

func (s *Store) GetBaustein(ctx context.Context, bausteinID int64) (domain.Baustein, error) {
	var b domain.Baustein
	err := s.pool.QueryRow(ctx, `
		SELECT id, standard, external_id, title, COALESCE(group_name, ''), catalog_version
		FROM bausteine WHERE id = $1`, bausteinID,
	).Scan(&b.ID, &b.Standard, &b.ExternalID, &b.Title, &b.GroupName, &b.CatalogVersion)
	if errors.Is(err, pgx.ErrNoRows) {
		return domain.Baustein{}, ErrNotFound
	}
	return b, err
}
