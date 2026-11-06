#!/usr/bin/env bash
# tools/tour-session.sh — the demo session, as a deterministic command sequence.
#
# Records the real `sumo` CLI on this host: live facts collected from this
# machine, then the fixture scenario with its proof, the capability atlas, the
# what-if menu, the policy gate's exit status, an independent proof check, and
# the TUI rendered from the same digest.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SUMO="$ROOT/bin/sumo"
LIVE="$ROOT/.runtime/facts-live.kif"

export TZ=UTC LANG=C LC_ALL=C
export SUMO_RULES="${SUMO_RULES:-$ROOT/rules.kif}"

mkdir -p "$ROOT/.runtime"

PS1='demo@sumonix:~$ '
run() {
  local display="$1"; shift
  printf '%s%s\n' "$PS1" "$display"
  "$@"
  printf '\n'
}

# Run a shell pipeline whose display text differs from its argv.
run_sh() {
  local display="$1" cmd="$2"
  printf '%s%s\n' "$PS1" "$display"
  bash -c "$cmd"
  printf '\n'
}

printf '%s\n' 'sumonix — SUMO reasoning over a machine, on this machine.'
printf '%s\n' 'The first call reads this host. The scenario after it is a labelled fixture.'
printf '\n'

run 'uname -srm' uname -srm

run 'sumo refresh' "$SUMO" refresh
run_sh 'SUMO_FACTS=.runtime/facts-live.kif sumo status' \
       "SUMO_FACTS='$LIVE' '$ROOT/bin/sumo' status"

printf "%s\n" "--- The scenario below is a fixture: an nginx service and a critical CVE."
echo
SUMO_FACTS="$ROOT/demo/facts/host.kif" "$SUMO" status

run 'sumo caps' "$SUMO" caps
run 'sumo closure nginx' "$SUMO" closure nginx
run "sumo query '(vulnerable nginx CVE-2026-9999)'" \
    "$SUMO" query '(vulnerable nginx CVE-2026-9999)'
run 'sumo whatif' "$SUMO" whatif

printf '%s%s\n' "$PS1" 'sumo guard; echo "exit=$?"'
set +e
"$SUMO" guard >/dev/null
status=$?
set -e
printf 'exit=%s  (non-zero means: the gate refuses this build)\n\n' "$status"

printf '%s%s\n' "$PS1" './nix-eval.sh --raw --expr "import ./tests/proof-artifact.nix" > /tmp/proof.kif'
"$ROOT/nix-eval.sh" --raw --expr "import ./tests/proof-artifact.nix" > /tmp/proof.kif
printf '%s%s\n' "$PS1" './nix-eval.sh --expr "(import ./proof-check.nix { file = /tmp/proof.kif; })"'
"$ROOT/nix-eval.sh" --expr "(import ./proof-check.nix { file = /tmp/proof.kif; })"
printf '\n'

printf '%s%s\n' "$PS1" 'sumo dashboard --dump | head -40'
"$ROOT/demo/tui/sumo-tui" --dump --sumo="$SUMO" > /tmp/sumo-dump.txt
head -40 /tmp/sumo-dump.txt
printf '\n'

printf '%s\n' 'The dashboard renders the same digest the CLI just answered from.'
