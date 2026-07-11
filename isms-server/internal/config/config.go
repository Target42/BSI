package config

import (
	"log/slog"
	"os"

	"github.com/joho/godotenv"
)

type Config struct {
	DatabaseURL      string
	HTTPAddr         string
	JWTSecret        string
	AdminEmail       string
	AdminPassword    string
	AdminDisplayName string
	CatalogVersion   string
	CatalogXMLPath   string
}

func Load() (Config, error) {
	_ = godotenv.Load()

	cfg := Config{
		DatabaseURL:      envOrDefault("DATABASE_URL", "postgres://ismsserver:ismsserver@localhost:5432/isms?sslmode=disable"),
		HTTPAddr:         envOrDefault("HTTP_ADDR", ":8080"),
		JWTSecret:        os.Getenv("JWT_SECRET"),
		AdminEmail:       envOrDefault("ADMIN_EMAIL", "admin@example.com"),
		AdminPassword:    envOrDefault("ADMIN_PASSWORD", "changeme"),
		AdminDisplayName: envOrDefault("ADMIN_DISPLAY_NAME", "Administrator"),
		CatalogVersion:   envOrDefault("CATALOG_VERSION", "2023"),
		CatalogXMLPath:   os.Getenv("CATALOG_XML_PATH"),
	}
	if cfg.JWTSecret == "" {
		cfg.JWTSecret = "dev-insecure-change-me"
		slog.Warn("JWT_SECRET not set, using insecure development default")
	}
	return cfg, nil
}

func envOrDefault(key, fallback string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return fallback
}
