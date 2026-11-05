#!/usr/bin/env bash
# tools/gen-demo.sh — Re-record all demo scenes with asciinema

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCENES_DIR="$ROOT/demo/scenes"
CASTS_DIR="$ROOT/demo/casts"

if ! command -v asciinema &> /dev/null; then
  echo "WARNING: asciinema not found, recording as text only"
  for scene in "$SCENES_DIR"/*.sh; do
    name=$(basename "$scene" .sh)
    echo "Recording $name..."
    bash "$scene" > "$CASTS_DIR/$name.txt" 2>&1 || true
  done
  echo "Text recordings saved to $CASTS_DIR/"
  exit 0
fi

echo "Re-recording all demo scenes with asciinema..."
for scene in "$SCENES_DIR"/*.sh; do
  name=$(basename "$scene" .sh)
  echo "Recording $name..."
  asciinema rec --overwrite --command "bash $scene" "$CASTS_DIR/$name.cast" || true
done

echo "All scenes recorded to $CASTS_DIR/"