#!/usr/bin/env bash
# Baut den ISMS-Go-Server für Linux und/oder Windows (amd64).
# Cross-Compile ohne CGO — von Linux oder Windows (Git Bash/WSL) aus nutzbar.
#
# Beispiele:
#   ./scripts/build.sh
#   ./scripts/build.sh windows
#   ./scripts/build.sh linux,windows ./release
#   OUT_DIR=./release ARCH=amd64 ./scripts/build.sh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGETS="${1:-linux,windows}"
OUT_DIR="${2:-${OUT_DIR:-$ROOT_DIR/dist}}"
ARCH="${ARCH:-amd64}"

if ! command -v go >/dev/null 2>&1; then
  echo "go nicht im PATH. Go 1.22+ installieren." >&2
  exit 1
fi

mkdir -p "$OUT_DIR"
cd "$ROOT_DIR"

export CGO_ENABLED=0
failed=0

IFS=',' read -r -a target_list <<< "$TARGETS"
for os in "${target_list[@]}"; do
  os="$(echo "$os" | tr '[:upper:]' '[:lower:]' | xargs)"
  case "$os" in
    linux|windows) ;;
    *)
      echo "Unbekanntes Target: $os (erlaubt: linux, windows)" >&2
      failed=1
      continue
      ;;
  esac

  if [[ "$os" == "windows" ]]; then
    name="isms-server-windows-${ARCH}.exe"
  else
    name="isms-server-linux-${ARCH}"
  fi
  out="$OUT_DIR/$name"

  echo "Bauen: GOOS=$os GOARCH=$ARCH -> $out"
  GOOS="$os" GOARCH="$ARCH" go build -trimpath -ldflags="-s -w" -o "$out" ./cmd/isms-server || failed=1
done

if [[ "$failed" -ne 0 ]]; then
  echo "Mindestens ein Build ist fehlgeschlagen." >&2
  exit 1
fi

echo
echo "Fertig. Ausgaben in $OUT_DIR :"
ls -la "$OUT_DIR"/isms-server-* 2>/dev/null || true
