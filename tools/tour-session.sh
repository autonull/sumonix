#!/usr/bin/env bash
# tools/tour-session.sh — the demo session, as a deterministic command sequence.
#
# This is the same sequence demo/vm/session.sh types into the VM console.
# Running it on the host exercises the identical sumo CLI against the curated
# machine facts, so the recording does not depend on a VM build.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export TZ=UTC LANG=C LC_ALL=C
export SUMO_FACTS="${SUMO_FACTS:-$ROOT/demo/vm/host-facts.kif}"
export SUMO_RULES="${SUMO_RULES:-$ROOT/rules.kif}"

PS1='demo@sumonix:~$ '
run() {
  local display="$1"; shift
  printf '%s%s\n' "$PS1" "$display"
  "$@"
  printf '\n'
}

printf '%s\n' 'sumonix reasons about this machine.'
printf '\n'

run 'sumo status'                 "$ROOT/bin/sumo" status
run 'sumo caps'                   "$ROOT/bin/sumo" caps
run 'sumo closure nginx'          "$ROOT/bin/sumo" closure nginx
run "sumo query '(vulnerable nginx CVE-2026-9999)'" \
                                  "$ROOT/bin/sumo" query '(vulnerable nginx CVE-2026-9999)'
run 'sumo whatif'                 "$ROOT/bin/sumo" whatif

printf '%s\n' 'Run `sumo dashboard` for the live panel.'
