# Self-signed TLS certificate for local HTTPS development.
# Requires OpenSSL in PATH.

$ErrorActionPreference = "Stop"

$certDir = Join-Path $PSScriptRoot ".." "certs"
New-Item -ItemType Directory -Force -Path $certDir | Out-Null

$keyPath = Join-Path $certDir "server.key"
$crtPath = Join-Path $certDir "server.crt"

openssl req -x509 -newkey rsa:4096 -sha256 -days 825 -nodes `
  -keyout $keyPath -out $crtPath `
  -subj "/CN=localhost" `
  -addext "subjectAltName=DNS:localhost,IP:127.0.0.1"

Write-Host "Created:"
Write-Host "  $crtPath"
Write-Host "  $keyPath"
Write-Host ""
Write-Host "Add to .env:"
Write-Host "  TLS_CERT_FILE=certs/server.crt"
Write-Host "  TLS_KEY_FILE=certs/server.key"
Write-Host "  HTTP_ADDR=:8443"
Write-Host ""
Write-Host "Client URL: https://localhost:8443"
Write-Host "Enable 'Self-signed TLS-Zertifikat akzeptieren' in the login dialog."
