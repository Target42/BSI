#!/usr/bin/env bash
# Baut den ISMS-Server unter Linux (amd64).
#
#   ./scripts/build-linux.sh
#   ./scripts/build-linux.sh ./release

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ $# -ge 1 ]]; then
  exec "$ROOT_DIR/scripts/build.sh" linux "$1"
fi
exec "$ROOT_DIR/scripts/build.sh" linux
