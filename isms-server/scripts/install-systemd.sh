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

install -m 0644 "$SRC_DIR/scripts/isms-server.service" /etc/systemd/system/isms-server.service

systemctl daemon-reload
systemctl enable --now isms-server

echo
echo "Status:  systemctl status isms-server"
echo "Logs:    journalctl -u isms-server -f"
echo "Env:     $ENV_TARGET"
echo "Health:  curl -s http://127.0.0.1:8080/health"
