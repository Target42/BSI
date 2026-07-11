package main

import (
	"context"
	"log/slog"
	"net/http"
	"os"
	"path/filepath"

	"github.com/Target42/BSI/isms-server/internal/auth"
	"github.com/Target42/BSI/isms-server/internal/bootstrap"
	"github.com/Target42/BSI/isms-server/internal/config"
	"github.com/Target42/BSI/isms-server/internal/db"
	"github.com/Target42/BSI/isms-server/internal/httpx"
	"github.com/Target42/BSI/isms-server/internal/repository"
)

func main() {
	slog.SetDefault(slog.New(slog.NewTextHandler(os.Stdout, nil)))

	cfg, err := config.Load()
	if err != nil {
		slog.Error("config", "error", err)
		os.Exit(1)
	}

	migrationsPath := filepath.Join("migrations")
	if _, err := os.Stat(migrationsPath); os.IsNotExist(err) {
		// When started from repo root instead of isms-server/.
		migrationsPath = filepath.Join("isms-server", "migrations")
	}

	if err := db.RunMigrations(cfg.DatabaseURL, migrationsPath); err != nil {
		slog.Error("migrations", "error", err)
		os.Exit(1)
	}

	ctx := context.Background()
	pool, err := db.Connect(ctx, cfg.DatabaseURL)
	if err != nil {
		slog.Error("database", "error", err)
		os.Exit(1)
	}
	defer pool.Close()

	store := repository.New(pool)
	if err := bootstrap.EnsureAdminUser(ctx, store, cfg); err != nil {
		slog.Error("bootstrap admin", "error", err)
		os.Exit(1)
	}
	if err := bootstrap.EnsureGrundschutzCatalog(ctx, store, cfg); err != nil {
		slog.Error("bootstrap catalog", "error", err)
		os.Exit(1)
	}

	authService := auth.NewService(cfg.JWTSecret, cfg.JWTTTL)
	server := httpx.NewServer(authService, store)

	router := server.Router()
	if cfg.TLSEnabled() {
		slog.Info("starting ISMS server with TLS", "addr", cfg.HTTPAddr, "jwt_ttl", cfg.JWTTTL.String())
		err = http.ListenAndServeTLS(cfg.HTTPAddr, cfg.TLSCertFile, cfg.TLSKeyFile, router)
	} else {
		if cfg.Environment == "production" {
			slog.Error("refusing to start without TLS in production")
			os.Exit(1)
		}
		slog.Warn("TLS not configured, serving plain HTTP (development only)", "addr", cfg.HTTPAddr)
		slog.Info("starting ISMS server", "addr", cfg.HTTPAddr, "jwt_ttl", cfg.JWTTTL.String())
		err = http.ListenAndServe(cfg.HTTPAddr, router)
	}
	if err != nil {
		slog.Error("server stopped", "error", err)
		os.Exit(1)
	}
}
