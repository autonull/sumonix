#!/usr/bin/env bash
# tools/shot.sh — Capture TUI screenshot via vt10x
# Usage: ./tools/shot.sh <output.png>

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT="${1:-$ROOT/docs/demo/dashboard.png}"

if ! command -v vt10x &> /dev/null; then
  echo "ERROR: vt10x not found. Install with: go install github.com/gdamore/vt10x@latest"
  exit 1
fi

# Run the TUI in dump mode and capture the output
TUI_BIN="/home/me/sumonix/demo/vm/tui/sumo-tui"
if [ ! -f "$TUI_BIN" ]; then
  echo "Building TUI..."
  cd "$ROOT/demo/vm/tui" && go build -o "$TUI_BIN" .
fi

# Capture the TUI output
"$TUI_BIN" --dump --sumo "$ROOT/bin/sumo" > /tmp/tui-output.txt 2>&1

# Convert to PNG using vt10x
vt10x -i /tmp/tui-output.txt -o "$OUTPUT"

echo "Screenshot saved to $OUTPUT"