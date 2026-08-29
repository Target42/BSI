package config

import (
	"fmt"
	"log/slog"
	"net"
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
	WebPublicBase    string
	TrustedProxies   string
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
		WebPublicBase:    strings.TrimRight(os.Getenv("WEB_PUBLIC_BASE"), "/"),
		TrustedProxies:   os.Getenv("TRUSTED_PROXIES"),
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
	if c.TLSEnabled() {
		return nil
	}
	proxies, err := ParseTrustedProxies(c.TrustedProxies)
	if err != nil {
		return fmt.Errorf("TRUSTED_PROXIES: %w", err)
	}
	if len(proxies) == 0 {
		return fmt.Errorf("TLS_CERT_FILE and TLS_KEY_FILE are required in production, or set TRUSTED_PROXIES when nginx terminates TLS")
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

func ParseTrustedProxies(raw string) ([]*net.IPNet, error) {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return nil, nil
	}
	var nets []*net.IPNet
	for _, part := range strings.Split(raw, ",") {
		part = strings.TrimSpace(part)
		if part == "" {
			continue
		}
		if !strings.Contains(part, "/") {
			ip := net.ParseIP(part)
			if ip == nil {
				return nil, fmt.Errorf("invalid proxy address %q", part)
			}
			bits := 128
			if ip.To4() != nil {
				bits = 32
			}
			part = fmt.Sprintf("%s/%d", ip.String(), bits)
		}
		_, network, err := net.ParseCIDR(part)
		if err != nil {
			return nil, fmt.Errorf("invalid proxy CIDR %q: %w", part, err)
		}
		nets = append(nets, network)
	}
	return nets, nil
}
