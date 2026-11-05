#!/usr/bin/env bash
# Run the full sumo-nix test suite with the local store (same as ./demo/lib.sh).
# Exits non-zero on the first failure, after printing what failed.
set -euo pipefail
cd "$(dirname "$0")"
export NIX_STORE_DIR="$(pwd)/.nix-store" NIX_STATE_DIR="$(pwd)/.nix-state"

tests=(
  tests/default.nix
  tests/rules.nix
  tests/ingest-smoke.nix
  tests/ingest-report.nix
  tests/bags.nix
  tests/decide.nix
  tests/hf.nix
  tests/org.nix
  tests/pyai.nix
  tests/proof-check.nix
  tests/unit/equivalents.nix
  tests/unit/synthesize.nix
  tests/unit/stratify.nix
  tests/unit/relax.nix
  tests/unit/congruence.nix
  tests/unit/builtins.nix
  tests/unit/disjunctive.nix
  tests/unit/soft-rules.nix
  tests/unit/wfs.nix
  tests/unit/existentials.nix
  tests/unit/temporal.nix
)

fail=0
for t in "${tests[@]}"; do
  printf '  %-44s ' "$t…"
  if out="$(./nix-eval.sh --expr "import ./$t" 2>&1)"; then
    echo "✓"
  else
    echo "✗"
    printf '%s\n' "$out" | sed 's/^/      /'
    fail=1
  fi
done
if [ "$fail" -ne 0 ]; then
  echo "✗ suite failed"
  exit 1
fi
echo "✓ all ${#tests[@]} tests passed"
