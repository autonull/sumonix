#!/usr/bin/env bash
# Disk budget gate for local experiments.
#
#   tools/budget.sh baseline            # record current sizes
#   tools/budget.sh check [MB]          # fail if growth since baseline > cap (default 2048)
#   tools/budget.sh report              # human-readable current vs baseline
#
# Scope: the directories a local build can grow (.nix-root, .runtime,
# .artifacts, .nix-state). The eval store is included because it must stay small.
set -euo pipefail
cd "$(dirname "$0")/.."
source ./tools/env.sh

STATE="$ROOT/.runtime/budget-baseline"
DIRS=(.nix-root .nix-store .runtime .artifacts .nix-state)

size_mb() {
  local total=0 d s
  for d in "${DIRS[@]}"; do
    s="$(du -sm "$d" 2>/dev/null | cut -f1 || true)"
    total=$((total + ${s:-0}))
  done
  printf '%s' "$total"
}

case "${1:-report}" in
  baseline)
    mkdir -p "$(dirname "$STATE")"
    size_mb > "$STATE"
    printf 'budget: baseline %s MB (%s)\n' "$(cat "$STATE")" "${DIRS[*]}"
    ;;
  check)
    cap="${2:-2048}"
    [ -f "$STATE" ] || { printf 'budget: no baseline; run: tools/budget.sh baseline\n' >&2; exit 2; }
    base="$(cat "$STATE")"
    now="$(size_mb)"
    grown=$((now - base))
    printf 'budget: %s MB -> %s MB (growth %s MB, cap %s MB)\n' "$base" "$now" "$grown" "$cap"
    if [ "$grown" -gt "$cap" ]; then
      printf 'budget: OVER CAP by %s MB - stop and delete before continuing\n' "$((grown - cap))" >&2
      exit 1
    fi
    ;;
  report)
    now="$(size_mb)"
    base="$(cat "$STATE" 2>/dev/null || echo "none")"
    printf 'budget: now %s MB, baseline %s\n' "$now" "$base"
    for d in "${DIRS[@]}"; do
      printf '  %-16s %s\n' "$d" "$(du -sh "$d" 2>/dev/null | cut -f1 || echo 0)"
    done
    ;;
  *)
    printf 'usage: tools/budget.sh [baseline|check [MB]|report]\n' >&2
    exit 2
    ;;
esac
