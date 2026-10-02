#!/usr/bin/env bash
# Installiert den ISMS-Go-Server als systemd-Dienst.
# Als root ausführen, im Verzeichnis isms-server/ (oder ISMS_SRC setzen).
#
#   sudo ./scripts/install-systemd.sh

set -euo pipefail

SRC_DIR="${ISMS_SRC:-$(cd "$(dirname "$0")/.." && pwd)}"
INSTALL_DIR="${ISMS_INSTALL_DIR:-/opt/isms}"
ENV_DIR="${ISMS_ENV_DIR:-/etc/isms}"
SERVICE_USER="${ISMS_USER:-isms}"
BINARY_SRC="${SRC_DIR}/isms-server"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Bitte als root ausführen (sudo)." >&2
  exit 1
fi

if [[ ! -x "$BINARY_SRC" ]]; then
  echo "Binary fehlt: $BINARY_SRC"
  echo "Zuerst:  cd \"$SRC_DIR\" && go build -o isms-server ./cmd/isms-server"
  exit 1
fi

if ! id -u "$SERVICE_USER" >/dev/null 2>&1; then
  useradd --system --home "$INSTALL_DIR" --shell /usr/sbin/nologin "$SERVICE_USER"
fi

install -d -o "$SERVICE_USER" -g "$SERVICE_USER" -m 0755 "$INSTALL_DIR"
install -d -o "$SERVICE_USER" -g "$SERVICE_USER" -m 0755 "$INSTALL_DIR/migrations"
install -d -o root -g "$SERVICE_USER" -m 0750 "$ENV_DIR"

install -o "$SERVICE_USER" -g "$SERVICE_USER" -m 0755 "$BINARY_SRC" "$INSTALL_DIR/isms-server"
install -o "$SERVICE_USER" -g "$SERVICE_USER" -m 0644 "$SRC_DIR"/migrations/*.sql "$INSTALL_DIR/migrations/"
install -d -o "$SERVICE_USER" -g "$SERVICE_USER" -m 0755 "$INSTALL_DIR/catalog"
install -d -o "$SERVICE_USER" -g "$SERVICE_USER" -m 0755 "$INSTALL_DIR/downloads"

ENV_TARGET="$ENV_DIR/isms.env"
if [[ ! -f "$ENV_TARGET" ]]; then
  if [[ -f "$SRC_DIR/.env" ]]; then
    install -o root -g "$SERVICE_USER" -m 0640 "$SRC_DIR/.env" "$ENV_TARGET"
  else
    install -o root -g "$SERVICE_USER" -m 0640 "$SRC_DIR/.env.example" "$ENV_TARGET"
    echo "Vorlage nach $ENV_TARGET kopiert — bitte anpassen (JWT_SECRET, Passwort, DATABASE_URL)."
  fi
fi
# Arbeitsverzeichnis der Binary (godotenv lädt .env von dort).
install -o "$SERVICE_USER" -g "$SERVICE_USER" -m 0640 "$ENV_TARGET" "$INSTALL_DIR/.env"

install -d -m 0755 /usr/lib/isms
install -d -m 0755 /usr/share/isms/nginx
install -m 0755 "$SRC_DIR/scripts/ensure-db.sh" /usr/lib/isms/ensure-db.sh
install -m 0755 "$SRC_DIR/scripts/setup-nginx.sh" /usr/sbin/isms-setup-nginx
install -m 0644 "$SRC_DIR/deploy/nginx-isms.conf" /usr/share/isms/nginx/nginx-isms.conf
install -m 0644 "$SRC_DIR/deploy/nginx-prefix.conf" /usr/share/isms/nginx/nginx-prefix.conf
install -m 0644 "$SRC_DIR/deploy/isms.env.nginx.example" /usr/share/isms/isms.env.nginx-subdomain.example
install -m 0644 "$SRC_DIR/deploy/isms.env.nginx-prefix.example" /usr/share/isms/isms.env.nginx-prefix.example
install -m 0644 "$SRC_DIR/scripts/isms-server.service" /etc/systemd/system/isms-server.service

/usr/lib/isms/ensure-db.sh || echo "Datenbank noch nicht angelegt. Nach PostgreSQL: systemctl restart isms-server" >&2

systemctl daemon-reload
systemctl enable --now isms-server

echo
echo "Status:  systemctl status isms-server"
echo "Logs:    journalctl -u isms-server -f"
echo "Env:     $ENV_TARGET"
echo "Health:  curl -s http://127.0.0.1:8080/health"
echo "nginx:   isms-setup-nginx subdomain isms.example.com"
echo "         isms-setup-nginx prefix /isms"
