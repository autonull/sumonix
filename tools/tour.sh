#!/usr/bin/env bash
# tools/tour.sh [out.cast] — record the SUMOnix walkthrough as an asciicast.
#
# The session lives in tools/tour-session.sh, so the recording is reproducible:
# same commands, same order, real `sumo` output. Needs `asciinema` (host).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$ROOT/docs/demo/tour.cast}"
mkdir -p "$(dirname "$OUT")"

command -v asciinema >/dev/null || {
  echo "asciinema not installed; cannot record the walkthrough" >&2
  exit 1
}

asciinema rec --overwrite --window-size 110x50 \
  --command "bash $ROOT/tools/tour-session.sh" "$OUT"

echo "wrote $OUT"
