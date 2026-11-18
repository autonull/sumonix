#!/usr/bin/env bash
# M3A — one metavisor refresh tick (systemd timer or manual).
#
#   1. Run the dumb observer into the observed file (hashed, TTL'd facts).
#   2. Evaluate declared + observed through `sumo drift` at one frozen `now`.
#   3. Append one JSON line per new drift/violation to the event log.
#   4. Log one structured journal line per new event (proof ID included).
#   5. Report degraded modes: observer dead -> unknown; engine behind -> logged.
#
# Exit status is 0 unless --fail-on-violation is set and the status is violation.
# The log is append-only; the observation itself stays ephemeral.
set -euo pipefail
export LC_ALL=C

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUMO="${SUMO_BIN:-$ROOT/bin/sumo}"
OBSERVER="${SUMO_OBSERVER:-$ROOT/tools/observe.sh}"

state="${SUMONIX_METAVISOR_STATE:-$ROOT/.runtime/metavisor}"
interval="${SUMO_METAVISOR_INTERVAL:-60}"
fail_on_violation=false
declared=""
observed=""

usage() {
  cat <<'EOF'
Usage: metavisor.sh [options]

  --declared FILE        Lifted declared facts (default: /etc/sumo/declared.kif,
                         then <repo>/.runtime/declared.kif)
  --observed FILE        Observer output (default: /run/sumo/observed.kif,
                         then <repo>/.runtime/observed.kif)
  --state-dir DIR        Event state (default: <repo>/.runtime/metavisor)
  --interval SECONDS     Refresh interval, used for the "engine behind" warning
  --fail-on-violation    Exit 1 when the status is violation
  -h, --help             This help

Environment:
  SUMO_BIN, SUMO_OBSERVER, SUMO_METAVISOR_INTERVAL, SUMO_OBSERVE_TTL,
  SUMONIX_METAVISOR_STATE
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --declared) declared="${2:-}"; shift 2 ;;
    --observed) observed="${2:-}"; shift 2 ;;
    --state-dir) state="${2:-}"; shift 2 ;;
    --interval) interval="${2:-}"; shift 2 ;;
    --fail-on-violation) fail_on_violation=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "metavisor: unknown argument: $1" >&2; exit 2 ;;
  esac
done

if [ -z "$declared" ]; then
  if [ -f /etc/sumo/declared.kif ]; then
    declared=/etc/sumo/declared.kif
  else
    declared="$ROOT/.runtime/declared.kif"
  fi
fi
if [ -z "$observed" ]; then
  if [ -d /run/sumo ]; then
    observed=/run/sumo/observed.kif
  else
    observed="$ROOT/.runtime/observed.kif"
  fi
fi

mkdir -p "$state"
events="$state/events.jsonl"
last_sig="$state/last-signature"
last_status_file="$state/last-status"
observer_marker="$state/observer-failed"
unknown_marker="$state/unknown"
: >> "$events"

journal() {
  if command -v logger >/dev/null 2>&1; then
    logger -t sumonix-metavisor -- "$*"
  else
    echo "sumonix-metavisor: $*" >&2
  fi
}

if [ ! -f "$declared" ]; then
  journal "degraded: no declared facts at $declared; run 'sumo lift' or enable the module"
  exit 2
fi

mkdir -p "$(dirname "$observed")" 2>/dev/null || true
if [ ! -w "$(dirname "$observed")" ]; then
  observed="$ROOT/.runtime/observed.kif"
  mkdir -p "$(dirname "$observed")"
fi

export SUMO_OBSERVE_TTL="${SUMO_OBSERVE_TTL:-$((interval * 2))}"

# 1. Observe. A dead observer leaves the previous file in place; its TTL then
# expires and the status becomes unknown (R1), never a false drift claim.
tmp="$observed.tmp.$$"
if "$OBSERVER" > "$tmp" 2> "$state/observer.err"; then
  mv "$tmp" "$observed"
  if [ -f "$observer_marker" ]; then
    rm -f "$observer_marker"
    journal "observer recovered (exporter output at $observed)"
  fi
else
  rm -f "$tmp"
  if [ ! -f "$observer_marker" ]; then
    reason="$(head -c 300 "$state/observer.err" 2>/dev/null | tr '\n' ' ' || true)"
    journal "degraded: observer failed; observation will expire (${reason:-no stderr})"
    touch "$observer_marker"
  fi
fi

# 2. Evaluate at one frozen timestamp, so the JSON and journal agree exactly.
ts="$(date +%s)"
start="$(date +%s)"
set +e
json="$("$SUMO" drift --declared "$declared" --observed "$observed" --now "$ts" --json 2> "$state/drift.err")"
rc=$?
set -e
elapsed=$(( $(date +%s) - start ))

if [ -z "$json" ]; then
  err="$(head -c 400 "$state/drift.err" 2>/dev/null | tr '\n' ' ' || true)"
  printf '{"ts":%s,"kind":"engine-unavailable","status":"unknown","error":"%s"}\n' \
    "$ts" "${err//\"/\\\"}" >> "$events"
  journal "degraded: engine unavailable (${err:-exit $rc}); status unknown"
  exit 0
fi

status="$(printf '%s' "$json" | sed -n 's/.*"status":"\([a-z]*\)".*/\1/p' | head -1)"
unknown_reason="$(printf '%s' "$json" | sed -n 's/.*"unknownReason":"\([^"]*\)".*/\1/p' | head -1)"
signature="$(printf '%s' "$json" | sed -n 's/.*"signature":"\([^"]*\)".*/\1/p' | head -1)"
status="${status:-unknown}"

if [ "$elapsed" -gt "$interval" ]; then
  journal "engine behind: tick took ${elapsed}s > interval ${interval}s; snapshot mode (last observation retained)"
fi

previous="$(cat "$last_status_file" 2>/dev/null || true)"
printf '%s\n' "$status" > "$last_status_file"

case "$status" in
  drift|violation)
    if [ ! -f "$last_sig" ] || ! cmp -s <(printf '%s' "$signature") "$last_sig"; then
      printf '%s' "$signature" > "$last_sig"
      printf '{"ts":%s,"event":%s}\n' "$ts" "$json" >> "$events"
      journal_lines="$("$SUMO" drift --declared "$declared" --observed "$observed" --now "$ts" --journal 2>/dev/null || true)"
      while IFS=$'\t' read -r id message; do
        [ -z "$id" ] && continue
        [ "$id" = "unknown" ] && continue
        journal "$message (proof $id)"
      done <<< "$journal_lines"
    fi
    [ -f "$unknown_marker" ] && rm -f "$unknown_marker"
    ;;
  pass)
    if [ -f "$last_sig" ]; then
      rm -f "$last_sig"
      printf '{"ts":%s,"kind":"resolved","status":"pass"}\n' "$ts" >> "$events"
      journal "resolved: no drift, no rogue listeners"
    fi
    [ -f "$unknown_marker" ] && rm -f "$unknown_marker"
    ;;
  *)
    if [ "$previous" != "unknown" ] || [ ! -f "$unknown_marker" ]; then
      printf '{"ts":%s,"kind":"unknown","status":"unknown","reason":"%s"}\n' \
        "$ts" "${unknown_reason//\"/\\\"}" >> "$events"
      journal "unknown: ${unknown_reason:-observation stale or partial}"
      touch "$unknown_marker"
    fi
    ;;
esac

printf '%s' "$json" > "$state/last.json"
if [ "$fail_on_violation" = "true" ] && [ "$status" = "violation" ]; then
  exit 1
fi
exit 0
