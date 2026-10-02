#!/bin/sh
# Legt die PostgreSQL-Rolle und -Datenbank aus DATABASE_URL an, falls sie fehlen.
# Remote-URLs bleiben unberührt. Läuft als root (Paket-postinst oder systemd ExecStartPre=+).
#
#   sudo ./scripts/ensure-db.sh
#   ISMS_ENSURE_DB_DRY_RUN=1 DATABASE_URL=postgres://ismsserver:secret@localhost:5432/isms ./scripts/ensure-db.sh
set -eu

ENV_FILE="${ISMS_ENV_FILE:-/etc/isms/isms.env}"
INSTALL_DIR="${ISMS_INSTALL_DIR:-/opt/isms}"
SERVICE_USER="${ISMS_USER:-isms}"

read_database_url() {
  if [ -n "${DATABASE_URL:-}" ]; then
    return 0
  fi
  if [ ! -f "$ENV_FILE" ]; then
    return 0
  fi
  DATABASE_URL=$(grep -E '^[[:space:]]*DATABASE_URL=' "$ENV_FILE" 2>/dev/null | tail -n 1 || true)
  DATABASE_URL=${DATABASE_URL#*=}
  DATABASE_URL=$(printf '%s' "$DATABASE_URL" | tr -d '\r')
  DATABASE_URL=$(printf '%s' "$DATABASE_URL" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  DATABASE_URL=${DATABASE_URL#\"}
  DATABASE_URL=${DATABASE_URL%\"}
  DATABASE_URL=${DATABASE_URL#\'}
  DATABASE_URL=${DATABASE_URL%\'}
}

set_kv() {
  key=$1
  val=$2
  file=$3
  tmp=$(mktemp)
  if [ -f "$file" ]; then
    awk -v k="$key" -v v="$val" '
      BEGIN { found = 0 }
      $0 ~ "^" k "=" { print k "=" v; found = 1; next }
      { print }
      END { if (!found) print k "=" v }
    ' "$file" > "$tmp"
    cat "$tmp" > "$file"
    rm -f "$tmp"
  else
    printf '%s=%s\n' "$key" "$val" > "$file"
  fi
}

sync_dotenv() {
  if [ -f "$ENV_FILE" ] && [ -d "$INSTALL_DIR" ] && getent passwd "$SERVICE_USER" >/dev/null 2>&1; then
    install -o "$SERVICE_USER" -g "$SERVICE_USER" -m 0640 "$ENV_FILE" "$INSTALL_DIR/.env"
  fi
}

is_local_host() {
  case "$1" in
    localhost|127.0.0.1|::1) return 0 ;;
  esac
  if [ "$1" = "[::1]" ]; then
    return 0
  fi
  return 1
}

valid_ident() {
  printf '%s' "$1" | grep -Eq '^[A-Za-z_][A-Za-z0-9_]*$'
}

psql_postgres() {
  if ! command -v runuser >/dev/null 2>&1; then
    echo "runuser fehlt (Paket util-linux)." >&2
    exit 1
  fi
  runuser -u postgres -- psql -v ON_ERROR_STOP=1 -X -p "$db_port" "$@"
}

read_database_url

created_url=0
if [ -z "${DATABASE_URL:-}" ]; then
  db_pass=$(od -An -tx1 -N16 /dev/urandom | tr -d ' \n')
  DATABASE_URL="postgres://ismsserver:${db_pass}@localhost:5432/isms?sslmode=disable"
  created_url=1
  if [ "${ISMS_ENSURE_DB_DRY_RUN:-}" != 1 ]; then
    install -d -o root -g "$SERVICE_USER" -m 0750 "$(dirname "$ENV_FILE")"
    if [ ! -f "$ENV_FILE" ]; then
      printf '%s\n' \
        'ENV=development' \
        "DATABASE_URL=${DATABASE_URL}" \
        'HTTP_ADDR=:8080' \
        'JWT_SECRET=' \
        'JWT_TTL=8h' \
        'ADMIN_EMAIL=admin@example.com' \
        'ADMIN_PASSWORD=' \
        'ADMIN_DISPLAY_NAME=Administrator' \
        > "$ENV_FILE"
      chown root:"$SERVICE_USER" "$ENV_FILE"
      chmod 0640 "$ENV_FILE"
    else
      set_kv DATABASE_URL "$DATABASE_URL" "$ENV_FILE"
    fi
    echo "DATABASE_URL war nicht gesetzt und wurde in $ENV_FILE eingetragen."
  else
    echo "dry-run: würde DATABASE_URL in $ENV_FILE eintragen"
  fi
fi

rest=${DATABASE_URL#*://}
case "$DATABASE_URL" in
  postgres://*|postgresql://*) ;;
  *)
    echo "DATABASE_URL muss mit postgres:// oder postgresql:// beginnen." >&2
    exit 1
    ;;
esac
case "$rest" in
  *@*) ;;
  *)
    echo "DATABASE_URL ohne Benutzer (erwartet user:pass@host/db)." >&2
    exit 1
    ;;
esac

userpass=${rest%%@*}
hostpath=${rest#*@}
case "$userpass" in
  *:*) ;;
  *)
    echo "DATABASE_URL ohne Passwort (erwartet user:pass@host/db)." >&2
    exit 1
    ;;
esac
db_user=${userpass%%:*}
db_pass=${userpass#*:}
nl='
'
case "$db_pass" in
  *"$nl"*)
    echo "Passwort in DATABASE_URL enthält einen Zeilenumbruch." >&2
    exit 1
    ;;
esac
hostport=${hostpath%%/*}
dbquery=${hostpath#*/}
db_name=${dbquery%%\?*}
case "$hostport" in
  \[*)
    db_host=${hostport%%]*}
    db_host="${db_host}]"
    restport=${hostport#*]}
    case "$restport" in
      :*) db_port=${restport#:} ;;
      *) db_port=5432 ;;
    esac
    ;;
  *:*)
    db_host=${hostport%%:*}
    db_port=${hostport##*:}
    ;;
  *)
    db_host=$hostport
    db_port=5432
    ;;
esac
case "$db_port" in
  ''|*[!0-9]*)
    echo "Ungültiger Port in DATABASE_URL: ${db_port}" >&2
    exit 1
    ;;
esac

if ! is_local_host "$db_host"; then
  echo "DATABASE_URL zeigt auf ${db_host} — lokale Datenbank wird nicht angelegt."
  sync_dotenv
  exit 0
fi

if ! valid_ident "$db_user" || ! valid_ident "$db_name"; then
  echo "Benutzer oder Datenbankname in DATABASE_URL ist kein einfacher Bezeichner. Bitte die Datenbank manuell anlegen." >&2
  exit 1
fi

case "$db_user" in
  postgres|PUBLIC)
    echo "DATABASE_URL darf nicht den Superuser postgres verwenden." >&2
    exit 1
    ;;
esac
case "$db_name" in
  postgres|template0|template1)
    echo "DATABASE_URL darf nicht die Systemdatenbank ${db_name} verwenden." >&2
    exit 1
    ;;
esac

# Mehr als ein @ heißt: Passwort enthält @ und lässt sich hier nicht sicher zerlegen.
case "$hostpath" in
  *@*)
    echo "DATABASE_URL enthält mehrere @. Bitte die Datenbank manuell anlegen." >&2
    exit 1
    ;;
esac

if [ "${ISMS_ENSURE_DB_DRY_RUN:-}" = 1 ]; then
  echo "dry-run: Rolle ${db_user}, Datenbank ${db_name} auf ${db_host}:${db_port}"
  exit 0
fi

if ! command -v psql >/dev/null 2>&1 || ! getent passwd postgres >/dev/null 2>&1; then
  echo "PostgreSQL ist nicht installiert. Paket postgresql installieren oder DATABASE_URL auf eine bestehende Datenbank setzen." >&2
  exit 1
fi

if command -v systemctl >/dev/null 2>&1; then
  systemctl start postgresql >/dev/null 2>&1 || true
fi

i=0
while [ "$i" -lt 20 ]; do
  if psql_postgres -d postgres -c 'SELECT 1' >/dev/null 2>&1; then
    break
  fi
  i=$((i + 1))
  sleep 1
done
if ! psql_postgres -d postgres -c 'SELECT 1' >/dev/null 2>&1; then
  echo "PostgreSQL antwortet nicht. Dienst prüfen: systemctl status postgresql" >&2
  exit 1
fi

sql_pass=$(printf '%s' "$db_pass" | sed "s/'/''/g")
# Tag muss ein Bezeichner sein. Hex aus od kann mit einer Ziffer beginnen, dann liest PostgreSQL $2… als Parameter.
tag=isms$(od -An -tx1 -N8 /dev/urandom | tr -d ' \n')

# stdin: eine Datei aus mktemp gehört root (0600), der Benutzer postgres darf sie nicht lesen.
psql_postgres -d postgres -f - >/dev/null <<EOF
DO \$${tag}\$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '${db_user}') THEN
    CREATE ROLE ${db_user} LOGIN PASSWORD '${sql_pass}';
  END IF;
END
\$${tag}\$;
SELECT format('CREATE DATABASE %I OWNER %I', '${db_name}', '${db_user}')
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = '${db_name}')
\gexec
EOF

psql_postgres -d "$db_name" -f - >/dev/null <<EOF
GRANT ALL PRIVILEGES ON DATABASE ${db_name} TO ${db_user};
GRANT ALL ON SCHEMA public TO ${db_user};
ALTER SCHEMA public OWNER TO ${db_user};
EOF

sync_dotenv

if [ "$created_url" -eq 1 ]; then
  echo "Lokale Datenbank ${db_name} (Rolle ${db_user}) angelegt. Zugangsdaten stehen in ${ENV_FILE}."
else
  echo "PostgreSQL: Rolle ${db_user}, Datenbank ${db_name} ist bereit."
fi
