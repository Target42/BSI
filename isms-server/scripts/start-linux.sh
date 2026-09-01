#!/usr/bin/env bash
# Startet den ISMS-Server unter Linux.
# Nutzt die gebaute Binary in dist/, sonst „go run“.
#
#   ./scripts/start-linux.sh
#   ./scripts/start-linux.sh --build

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$ROOT_DIR/dist/isms-server-linux-amd64"
do_build=0

for arg in "$@"; do
  case "$arg" in
    --build|-b) do_build=1 ;;
    *)
      echo "Unbekanntes Argument: $arg (erlaubt: --build)" >&2
      exit 1
      ;;
  esac
done

if [[ ! -f "$ROOT_DIR/.env" ]]; then
  if [[ -f "$ROOT_DIR/.env.example" ]]; then
    cp "$ROOT_DIR/.env.example" "$ROOT_DIR/.env"
    echo ".env aus .env.example angelegt — bei Bedarf anpassen."
  else
    echo ".env fehlt und .env.example wurde nicht gefunden." >&2
    exit 1
  fi
fi

if [[ "$do_build" -eq 1 ]]; then
  echo "Binary bauen…"
  "$ROOT_DIR/scripts/build-linux.sh"
fi

cd "$ROOT_DIR"

if [[ -x "$BIN" ]]; then
  echo "Starte $BIN"
  exec "$BIN"
fi

if ! command -v go >/dev/null 2>&1; then
  echo "Weder Binary ($BIN) noch go im PATH. Zuerst ./scripts/build-linux.sh ausführen." >&2
  exit 1
fi

echo "Starte: go run ./cmd/isms-server"
exec go run ./cmd/isms-server
