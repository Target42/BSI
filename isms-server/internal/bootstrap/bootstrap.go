package bootstrap

import (
	"context"
	"log/slog"

	"github.com/Target42/BSI/isms-server/internal/auth"
	"github.com/Target42/BSI/isms-server/internal/config"
	"github.com/Target42/BSI/isms-server/internal/repository"
)

func EnsureAdminUser(ctx context.Context, store *repository.Store, cfg config.Config) error {
	count, err := store.CountUsers(ctx)
	if err != nil {
		return err
	}
	if count > 0 {
		return nil
	}

	hash, err := auth.HashPassword(cfg.AdminPassword)
	if err != nil {
		return err
	}
	user, err := store.CreateUser(ctx, cfg.AdminEmail, cfg.AdminDisplayName, hash)
	if err != nil {
		return err
	}
	if err := store.SetUserAdmin(ctx, user.ID, true); err != nil {
		return err
	}
	slog.Info("created bootstrap admin user", "email", user.Email, "id", user.ID)
	return nil
}
