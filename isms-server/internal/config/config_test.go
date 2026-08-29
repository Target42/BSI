package config

import (
	"net"
	"testing"
)

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

	cfg.TLSCertFile = ""
	cfg.TLSKeyFile = ""
	cfg.TrustedProxies = "127.0.0.1,::1"
	if err := cfg.Validate(); err != nil {
		t.Fatalf("nginx TLS termination should satisfy production: %v", err)
	}
}

func TestParseTrustedProxies(t *testing.T) {
	got, err := ParseTrustedProxies("127.0.0.1, 10.0.0.0/8")
	if err != nil {
		t.Fatal(err)
	}
	if len(got) != 2 {
		t.Fatalf("len %d", len(got))
	}
	if !got[0].Contains(mustIP("127.0.0.1")) || !got[1].Contains(mustIP("10.1.2.3")) {
		t.Fatalf("%v", got)
	}
	if _, err := ParseTrustedProxies("not-an-ip"); err == nil {
		t.Fatal("expected error")
	}
	empty, err := ParseTrustedProxies("  ")
	if err != nil || empty != nil {
		t.Fatalf("empty: %v %v", empty, err)
	}
}

func mustIP(s string) net.IP {
	ip := net.ParseIP(s)
	if ip == nil {
		panic(s)
	}
	return ip
}
