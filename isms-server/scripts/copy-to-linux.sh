#!/usr/bin/env bash
# Kopiert Binary, Migrationen, Katalog und Install-Dateien auf einen Linux-Rechner.
# Zielbenutzer und Host kommen aus Umgebungsvariablen.
#
# Pflicht:
#   export ISMS_USER=ubuntu
#   export ISMS_HOST=192.168.1.10
#   ./scripts/copy-to-linux.sh
#
# Optional:
#   export ISMS_REMOTE_DIR=isms-server   # Default: ~/isms-server
#   export ISMS_SSH_PORT=22
#   export CATALOG_XML_PATH=/pfad/XML_Kompendium_2023.xml
#
#   ./scripts/copy-to-linux.sh --skip-build
#   ./scripts/copy-to-linux.sh --include-env   # kopiert auch lokale .env

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKIP_BUILD=0
INCLUDE_ENV=0

for arg in "$@"; do
  case "$arg" in
    --skip-build) SKIP_BUILD=1 ;;
    --include-env) INCLUDE_ENV=1 ;;
    *)
      echo "Unbekanntes Argument: $arg" >&2
      echo "Erlaubt: --skip-build  --include-env" >&2
      exit 1
      ;;
  esac
done

if [[ -z "${ISMS_USER:-}" || -z "${ISMS_HOST:-}" ]]; then
  echo "ISMS_USER und ISMS_HOST müssen gesetzt sein." >&2
  echo >&2
  echo "  export ISMS_USER=ubuntu" >&2
  echo "  export ISMS_HOST=mein-linux-host" >&2
  echo "  ./scripts/copy-to-linux.sh" >&2
  exit 1
fi

REMOTE_DIR="${ISMS_REMOTE_DIR:-isms-server}"
SSH_PORT="${ISMS_SSH_PORT:-22}"
LINUX_BIN="$ROOT_DIR/dist/isms-server-linux-amd64"
SSH_TARGET="${ISMS_USER}@${ISMS_HOST}"

if ! command -v ssh >/dev/null 2>&1 || ! command -v scp >/dev/null 2>&1; then
  echo "ssh/scp nicht im PATH." >&2
  exit 1
fi

if [[ "$SKIP_BUILD" -eq 0 || ! -f "$LINUX_BIN" ]]; then
  echo "Linux-Binary bauen…"
  "$ROOT_DIR/scripts/build.sh" linux
fi

if [[ ! -f "$LINUX_BIN" ]]; then
  echo "Linux-Binary fehlt: $LINUX_BIN" >&2
  exit 1
fi

find_catalog() {
  local candidates=()
  if [[ -n "${CATALOG_XML_PATH:-}" ]]; then
    candidates+=("$CATALOG_XML_PATH")
  fi
  if [[ -f "$ROOT_DIR/.env" ]]; then
    local from_env
    from_env="$(awk -F= '/^[[:space:]]*CATALOG_XML_PATH[[:space:]]*=/{sub(/^[^=]+=/,""); gsub(/^[[:space:]"'\'']+|[[:space:]"'\'']+$/,""); print; exit}' "$ROOT_DIR/.env" || true)"
    if [[ -n "$from_env" ]]; then
      candidates+=("$from_env")
    fi
  fi
  candidates+=(
    "$ROOT_DIR/catalog/XML_Kompendium_2023.xml"
    "$ROOT_DIR/../xml/XML_Kompendium_2023.xml"
    "$HOME/Documents/XML_Kompendium_2023.xml"
    "$HOME/Dokumente/XML_Kompendium_2023.xml"
  )
  local path
  for path in "${candidates[@]}"; do
    if [[ -n "$path" && -f "$path" ]]; then
      echo "$path"
      return 0
    fi
  done
  return 1
}

STAGE="$(mktemp -d "${TMPDIR:-/tmp}/isms-copy.XXXXXX")"
cleanup() { rm -rf "$STAGE"; }
trap cleanup EXIT

mkdir -p "$STAGE/migrations" "$STAGE/scripts" "$STAGE/deploy" "$STAGE/catalog"
cp "$LINUX_BIN" "$STAGE/isms-server"
cp "$ROOT_DIR"/migrations/*.sql "$STAGE/migrations/"
cp "$ROOT_DIR/.env.example" "$STAGE/.env.example"
if [[ "$INCLUDE_ENV" -eq 1 && -f "$ROOT_DIR/.env" ]]; then
  cp "$ROOT_DIR/.env" "$STAGE/.env"
  echo "Lokale .env wird mitkopiert (enthält Secrets)."
fi
cp "$ROOT_DIR/scripts/install-systemd.sh" "$STAGE/scripts/"
cp "$ROOT_DIR/scripts/isms-server.service" "$STAGE/scripts/"
cp "$ROOT_DIR/scripts/setup-local-db.sql" "$STAGE/scripts/"
cp "$ROOT_DIR/scripts/start-linux.sh" "$STAGE/scripts/"
cp "$ROOT_DIR/scripts/build-linux.sh" "$STAGE/scripts/" 2>/dev/null || true
if [[ -d "$ROOT_DIR/deploy" ]]; then
  cp "$ROOT_DIR/deploy/"* "$STAGE/deploy/" 2>/dev/null || true
fi

CATALOG="$(find_catalog || true)"
if [[ -n "$CATALOG" ]]; then
  cp "$CATALOG" "$STAGE/catalog/XML_Kompendium_2023.xml"
  echo "Katalog: $CATALOG"
else
  echo "Kein Katalog-XML gefunden — CATALOG_XML_PATH setzen oder Datei nach Documents legen."
fi

SSH_OPTS=(-p "$SSH_PORT" -o StrictHostKeyChecking=accept-new)
SCP_OPTS=(-P "$SSH_PORT" -o StrictHostKeyChecking=accept-new)

echo "Zielverzeichnis anlegen: ${SSH_TARGET}:$REMOTE_DIR"
ssh "${SSH_OPTS[@]}" "$SSH_TARGET" "mkdir -p -- '$REMOTE_DIR'"

echo "Kopiere nach ${SSH_TARGET}:$REMOTE_DIR …"
scp "${SCP_OPTS[@]}" -r \
  "$STAGE/isms-server" \
  "$STAGE/.env.example" \
  "$STAGE/migrations" \
  "$STAGE/scripts" \
  "$STAGE/deploy" \
  "$STAGE/catalog" \
  "${SSH_TARGET}:$REMOTE_DIR/"

if [[ "$INCLUDE_ENV" -eq 1 && -f "$STAGE/.env" ]]; then
  scp "${SCP_OPTS[@]}" "$STAGE/.env" "${SSH_TARGET}:$REMOTE_DIR/.env"
fi

ssh "${SSH_OPTS[@]}" "$SSH_TARGET" "chmod +x -- '$REMOTE_DIR/isms-server' '$REMOTE_DIR/scripts/'*.sh"

echo
echo "Fertig. Auf dem Zielrechner:"
echo "  ssh -p $SSH_PORT $SSH_TARGET"
echo "  cd $REMOTE_DIR"
echo "  chmod +x isms-server scripts/*.sh"
echo "  cp .env.example .env && nano .env"
echo "  # optional: sudo -u postgres psql -f scripts/setup-local-db.sql"
echo "  ./scripts/start-linux.sh"
echo "  # oder Dienst: sudo ./scripts/install-systemd.sh"
