#!/usr/bin/env bash
# tools/tour.sh [out.cast] — record the demo session as an asciicast.
#
# Uses tools/tour-session.sh, so the recording is reproducible and does not
# depend on a VM build. The VM runs the same commands (demo/vm/session.sh).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$ROOT/docs/demo/tour.cast}"
mkdir -p "$(dirname "$OUT")"

command -v asciinema >/dev/null || {
  echo "asciinema not installed; skipping cast (txt-only)" >&2
  exit 0
}

asciinema rec --overwrite --cols 100 --rows 40 \
  --command "bash $ROOT/tools/tour-session.sh" "$OUT"

echo "wrote $OUT"
