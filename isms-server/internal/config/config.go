package config

import (
	"fmt"
	"log/slog"
	"os"
	"strings"
	"time"

	"github.com/joho/godotenv"
)

const devJWTSecret = "dev-insecure-change-me"

type Config struct {
	Environment      string
	DatabaseURL      string
	HTTPAddr         string
	JWTSecret        string
	JWTTTL           time.Duration
	TLSCertFile      string
	TLSKeyFile       string
	AdminEmail       string
	AdminPassword    string
	AdminDisplayName string
	CatalogVersion   string
	CatalogXMLPath   string
}

func Load() (Config, error) {
	_ = godotenv.Load()

	cfg := Config{
		Environment:      strings.ToLower(envOrDefault("ENV", "development")),
		DatabaseURL:      envOrDefault("DATABASE_URL", "postgres://ismsserver:ismsserver@localhost:5432/isms?sslmode=disable"),
		HTTPAddr:         envOrDefault("HTTP_ADDR", ":8080"),
		JWTSecret:        os.Getenv("JWT_SECRET"),
		AdminEmail:       envOrDefault("ADMIN_EMAIL", "admin@example.com"),
		AdminPassword:    envOrDefault("ADMIN_PASSWORD", "changeme"),
		AdminDisplayName: envOrDefault("ADMIN_DISPLAY_NAME", "Administrator"),
		CatalogVersion:   envOrDefault("CATALOG_VERSION", "2023"),
		CatalogXMLPath:   os.Getenv("CATALOG_XML_PATH"),
		TLSCertFile:      os.Getenv("TLS_CERT_FILE"),
		TLSKeyFile:       os.Getenv("TLS_KEY_FILE"),
	}

	ttl, err := parseDuration(envOrDefault("JWT_TTL", "24h"), 24*time.Hour)
	if err != nil {
		return Config{}, fmt.Errorf("JWT_TTL: %w", err)
	}
	cfg.JWTTTL = ttl

	if cfg.JWTSecret == "" {
		cfg.JWTSecret = devJWTSecret
		slog.Warn("JWT_SECRET not set, using insecure development default")
	}

	if err := cfg.Validate(); err != nil {
		return Config{}, err
	}
	return cfg, nil
}

func (c Config) Validate() error {
	if c.Environment != "production" {
		return nil
	}
	if len(c.JWTSecret) < 32 {
		return fmt.Errorf("JWT_SECRET must be at least 32 characters in production")
	}
	if c.JWTSecret == devJWTSecret {
		return fmt.Errorf("JWT_SECRET must be explicitly set in production")
	}
	if c.TLSCertFile == "" || c.TLSKeyFile == "" {
		return fmt.Errorf("TLS_CERT_FILE and TLS_KEY_FILE are required in production")
	}
	return nil
}

func (c Config) TLSEnabled() bool {
	return c.TLSCertFile != "" && c.TLSKeyFile != ""
}

func envOrDefault(key, fallback string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return fallback
}

func parseDuration(raw string, fallback time.Duration) (time.Duration, error) {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return fallback, nil
	}
	if duration, err := time.ParseDuration(raw); err == nil {
		return duration, nil
	}
	return 0, fmt.Errorf("invalid duration %q (examples: 8h, 30m, 24h)", raw)
}
