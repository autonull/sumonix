#!/usr/bin/env bash
# tools/shot.sh [out.png] — render `sumo dashboard --dump` to a PNG.
#
# The screenshot is the TUI's own output stream: no browser rendering of a
# separate HTML dashboard, no Xvfb. Chromium is only the text rasteriser.
# Run on the host: the TUI reads the same `sumo` CLI the walkthrough uses.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$ROOT/docs/demo/dashboard.png}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$(dirname "$OUT")"

log() { printf '\033[1;36m│\033[0m %s\n' "$*"; }

log "Capturing TUI dump..."
"$ROOT/demo/tui/sumo-tui" --dump --sumo="$ROOT/bin/sumo" > "$TMP/dump.txt"
[ -s "$TMP/dump.txt" ] || { echo "empty TUI dump" >&2; exit 1; }

python3 - "$TMP/dump.txt" "$TMP/dash.html" <<'PY'
import html, sys
src, dst = sys.argv[1], sys.argv[2]
text = open(src, encoding="utf-8").read()
page = """<!doctype html><html><head><meta charset="utf-8"><style>
html,body{margin:0;padding:0;background:#0b0f14;}
pre{margin:0;padding:24px;color:#d8dee9;background:#0b0f14;
    font:14px/1.4 "Noto Sans Mono","Noto Color Emoji",monospace;
    white-space:pre;}
</style></head><body><pre>%s</pre></body></html>""" % html.escape(text)
open(dst, "w", encoding="utf-8").write(page)
PY

cols=$(awk '{ if (length > m) m = length } END { print m + 4 }' "$TMP/dump.txt")
rows=$(wc -l < "$TMP/dump.txt")
w=$(( cols * 9 + 48 ))
h=$(( rows * 20 + 48 ))

log "Rendering screenshot (${w}x${h} @2x)..."
chromium --headless --no-sandbox --disable-gpu --hide-scrollbars \
  --force-device-scale-factor=2 \
  --window-size="${w},${h}" \
  --screenshot="$OUT" "file://$TMP/dash.html" >/dev/null 2>&1

[ -s "$OUT" ] || { echo "screenshot failed" >&2; exit 1; }
log "wrote $OUT (${w}x${h} @2x)"