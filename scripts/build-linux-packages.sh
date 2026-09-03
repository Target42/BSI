#!/usr/bin/env bash
# Baut .deb und .rpm für ISMS-Server und/oder Qt-Client (nfpm).
#
# Voraussetzungen:
#   - nfpm im PATH  (https://nfpm.goreleaser.com/install/)
#   - Server: Go 1.22+  oder bereits gebaute Binary
#   - Client: fertige Qt-Binary (qmake/make), z. B. build/ISMS
#
# Beispiele:
#   ./scripts/build-linux-packages.sh
#   ./scripts/build-linux-packages.sh server
#   ./scripts/build-linux-packages.sh client
#   ISMS_VERSION=1.2.0 ISMS_CLIENT_BIN=./build/ISMS ./scripts/build-linux-packages.sh
#
# Ausgaben: dist/packages/

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

PACK_WHAT="${1:-all}"
OUT_DIR="${ISMS_PKG_OUT:-$ROOT_DIR/dist/packages}"
FORMATS="${ISMS_PKG_FORMATS:-deb,rpm}"
export NFPM_ARCH="${NFPM_ARCH:-amd64}"
export ISMS_ROOT="$ROOT_DIR"
export ISMS_SERVER_DIR="${ISMS_SERVER_DIR:-$ROOT_DIR/isms-server}"
export ISMS_MAINTAINER="${ISMS_MAINTAINER:-ISMS Projekt <isms@localhost>}"

if [[ -n "${ISMS_VERSION:-}" ]]; then
  :
elif [[ -f "$ROOT_DIR/packaging/VERSION" ]]; then
  ISMS_VERSION="$(tr -d '[:space:]' < "$ROOT_DIR/packaging/VERSION")"
else
  ISMS_VERSION="$(git -C "$ROOT_DIR" describe --tags --always --dirty 2>/dev/null || true)"
fi
ISMS_VERSION="${ISMS_VERSION#v}"
ISMS_VERSION="${ISMS_VERSION:-0.1.0}"
export ISMS_VERSION

if ! command -v nfpm >/dev/null 2>&1; then
  echo "nfpm fehlt im PATH." >&2
  echo "Installation: https://nfpm.goreleaser.com/install/" >&2
  echo "  z. B.  go install github.com/goreleaser/nfpm/v2/cmd/nfpm@latest" >&2
  exit 1
fi

find_client_bin() {
  if [[ -n "${ISMS_CLIENT_BIN:-}" && -x "$ISMS_CLIENT_BIN" ]]; then
    printf '%s' "$ISMS_CLIENT_BIN"
    return 0
  fi
  local candidate
  for candidate in \
    "$ROOT_DIR/build/ISMS" \
    "$ROOT_DIR/build-linux/ISMS" \
    "$ROOT_DIR/ISMS"
  do
    if [[ -x "$candidate" ]]; then
      printf '%s' "$candidate"
      return 0
    fi
  done
  return 1
}

ensure_server_bin() {
  if [[ -n "${ISMS_SERVER_BIN:-}" && -x "$ISMS_SERVER_BIN" ]]; then
    return 0
  fi
  local dist_bin="$ISMS_SERVER_DIR/dist/isms-server-linux-${NFPM_ARCH}"
  if [[ -x "$dist_bin" ]]; then
    export ISMS_SERVER_BIN="$dist_bin"
    return 0
  fi
  if [[ -x "$ISMS_SERVER_DIR/isms-server" ]]; then
    export ISMS_SERVER_BIN="$ISMS_SERVER_DIR/isms-server"
    return 0
  fi
  if [[ -x "$ISMS_SERVER_DIR/scripts/build.sh" ]]; then
    echo "Server-Binary fehlt — baue linux/${NFPM_ARCH} …"
    "$ISMS_SERVER_DIR/scripts/build.sh" linux "$ISMS_SERVER_DIR/dist"
    export ISMS_SERVER_BIN="$dist_bin"
    return 0
  fi
  echo "Keine Server-Binary gefunden. ISMS_SERVER_BIN setzen oder isms-server/scripts/build.sh ausführen." >&2
  return 1
}

package_one() {
  local name="$1"
  local config="$2"
  local format
  IFS=',' read -r -a format_list <<< "$FORMATS"
  for format in "${format_list[@]}"; do
    format="$(echo "$format" | tr '[:upper:]' '[:lower:]' | xargs)"
    case "$format" in
      deb|rpm) ;;
      *)
        echo "Unbekanntes Format: $format (erlaubt: deb, rpm)" >&2
        return 1
        ;;
    esac
    echo "Paket: $name  Format=$format  Version=$ISMS_VERSION  Arch=$NFPM_ARCH"
    nfpm package --packager "$format" --config "$config" --target "$OUT_DIR"
  done
}

mkdir -p "$OUT_DIR"
failed=0
did_any=0

if [[ "$PACK_WHAT" == "all" || "$PACK_WHAT" == "server" ]]; then
  if ensure_server_bin; then
    package_one "isms-server" "$ROOT_DIR/packaging/isms-server/nfpm.yaml" || failed=1
    did_any=1
  else
    failed=1
  fi
fi

if [[ "$PACK_WHAT" == "all" || "$PACK_WHAT" == "client" ]]; then
  if client_bin="$(find_client_bin)"; then
    export ISMS_CLIENT_BIN="$client_bin"
    package_one "isms-werkzeug" "$ROOT_DIR/packaging/isms-client/nfpm.yaml" || failed=1
    did_any=1
  else
    echo "Client-Binary fehlt (erwartet z. B. build/ISMS)." >&2
    echo "Unter Linux:  qmake BSI.pro && make   danach dieses Skript erneut." >&2
    echo "Oder:  ISMS_CLIENT_BIN=/pfad/zur/ISMS $0 client" >&2
    if [[ "$PACK_WHAT" == "client" ]]; then
      failed=1
    fi
  fi
fi

if [[ "$did_any" -eq 0 ]]; then
  echo "Kein Paket erzeugt." >&2
  exit 1
fi

echo
echo "Fertig. Pakete in $OUT_DIR :"
ls -la "$OUT_DIR"/*.deb "$OUT_DIR"/*.rpm 2>/dev/null || ls -la "$OUT_DIR"

if [[ "$failed" -ne 0 ]]; then
  exit 1
fi
