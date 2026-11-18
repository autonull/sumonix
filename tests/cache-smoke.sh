#!/usr/bin/env bash
# M0.1 cache smoke test: warm hit, byte-diff cached vs uncached, poison handling.
set -euo pipefail
cd "$(dirname "$0")/.."
source ./tools/env.sh

work="$(mktemp -d)"
export SUMO_CACHE_DIR="$work/cache"
trap 'rm -rf "$work"' EXIT

fail() { printf 'cache-smoke: %s\n' "$*" >&2; exit 1; }

# Cold run fills the cache.
./bin/sumo caps > "$work/cold.out"
[ -s "$work/cold.out" ] || fail "cold run produced no output"
[ -d "$SUMO_CACHE_DIR" ] || fail "cache directory was not created"

# Warm run: same bytes, and fast.
start=$(date +%s%N)
./bin/sumo caps > "$work/warm.out"
end=$(date +%s%N)
ms=$(( (end - start) / 1000000 ))
cmp -s "$work/cold.out" "$work/warm.out" || fail "warm output differs from cold"
[ "$ms" -lt 300 ] || fail "warm run took ${ms}ms (expected <300ms)"

# --no-cache reproduces the same bytes.
./bin/sumo caps --no-cache > "$work/uncached.out"
cmp -s "$work/cold.out" "$work/uncached.out" || fail "uncached output differs"

# A poisoned entry must be reported and recomputed, never served.
entry="$(find "$SUMO_CACHE_DIR" -path '*/caps/*.out' -type f | head -n 1)"
[ -n "$entry" ] || fail "no cache entry found"
printf 'garbage\n' >> "$entry"
if ! ./bin/sumo caps > "$work/poisoned.out" 2> "$work/poisoned.err"; then
  fail "run after poisoning failed"
fi
grep -q 'failed its checksum' "$work/poisoned.err" || fail "poisoned entry was not reported"
cmp -s "$work/cold.out" "$work/poisoned.out" || fail "poisoned entry was served or recomputed wrong"

printf 'cache-smoke: ok (warm %sms)\n' "$ms"
