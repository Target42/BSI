package config

import "testing"

func TestValidateProductionRequiresStrongSecretAndTLS(t *testing.T) {
	cfg := Config{
		Environment: "production",
		JWTSecret:   "short",
	}
	if err := cfg.Validate(); err == nil {
		t.Fatal("expected error for short JWT secret")
	}

	cfg.JWTSecret = "this-is-a-very-long-production-secret-value"
	if err := cfg.Validate(); err == nil {
		t.Fatal("expected error for missing TLS in production")
	}

	cfg.TLSCertFile = "cert.pem"
	cfg.TLSKeyFile = "key.pem"
	if err := cfg.Validate(); err != nil {
		t.Fatalf("unexpected validation error: %v", err)
	}
}
