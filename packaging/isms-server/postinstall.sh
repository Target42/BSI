#!/bin/sh
# Nach der Paketinstallation: Systemuser, Rechte, systemd.
set -e

SERVICE_USER="${ISMS_USER:-isms}"
INSTALL_DIR="${ISMS_INSTALL_DIR:-/opt/isms}"
ENV_DIR="${ISMS_ENV_DIR:-/etc/isms}"
ENV_FILE="$ENV_DIR/isms.env"

if ! getent passwd "$SERVICE_USER" >/dev/null 2>&1; then
  useradd --system --home "$INSTALL_DIR" --shell /usr/sbin/nologin "$SERVICE_USER" || true
fi

install -d -o "$SERVICE_USER" -g "$SERVICE_USER" -m 0755 "$INSTALL_DIR"
install -d -o "$SERVICE_USER" -g "$SERVICE_USER" -m 0755 "$INSTALL_DIR/migrations"
install -d -o "$SERVICE_USER" -g "$SERVICE_USER" -m 0755 "$INSTALL_DIR/catalog"
install -d -o root -g "$SERVICE_USER" -m 0750 "$ENV_DIR"

if [ -f "$ENV_FILE" ]; then
  chown root:"$SERVICE_USER" "$ENV_FILE" 2>/dev/null || true
  chmod 0640 "$ENV_FILE" 2>/dev/null || true
  # godotenv liest .env aus dem Arbeitsverzeichnis der Binary.
  install -o "$SERVICE_USER" -g "$SERVICE_USER" -m 0640 "$ENV_FILE" "$INSTALL_DIR/.env"
fi

chown -R "$SERVICE_USER":"$SERVICE_USER" "$INSTALL_DIR" 2>/dev/null || true

if command -v systemctl >/dev/null 2>&1; then
  systemctl daemon-reload || true
  systemctl enable isms-server >/dev/null 2>&1 || true
  systemctl restart isms-server >/dev/null 2>&1 || true
fi

echo "ISMS-Server: $INSTALL_DIR"
echo "Umgebung:    $ENV_FILE  (JWT_SECRET und ADMIN_PASSWORD prüfen)"
echo "Status:      systemctl status isms-server"
echo "Health:      curl -s http://127.0.0.1:8080/health"
