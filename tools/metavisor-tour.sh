#!/usr/bin/env bash
# D1 — the 60-second metavisor tour, live.
#
#   tools/metavisor-tour.sh          # run, write demo/transcripts/06-metavisor-live.txt
#   tools/metavisor-tour.sh --check  # run, byte-diff the normalized transcript
#   tools/metavisor-tour.sh --record # run under asciinema -> docs/demo/metavisor-tour.cast
#
# Scene 1 is eval-time: a real NixOS module (wildcard postgres, closed firewall)
# is gated through `sumo gate`, which fails with the why-tree naming both
# option paths. Scenes 2-3 run against the container's real systemd: stop the
# declared unit and a timer tick turns it into proven drift; `sumo repair` ranks
# single-option patches, each verified by re-lifting the patched config; the top
# patch is applied and the whole system rebuilds through the same gate.
#
# Every line is produced by the real CLI. Timestamps, snapshot ids, hashes and
# durations are normalized before the transcript is compared, so the text is
# byte-stable while the evidence is live.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/tools/env.sh"

cd "$ROOT"

TRANSCRIPT="$ROOT/demo/transcripts/06-metavisor-live.txt"
CAST="$ROOT/docs/demo/metavisor-tour.cast"

CONTAINER_NAME="${CONTAINER_NAME:-sumonix-demo}"
INTERVAL=10

# Podman state stays inside the repo (container/run.sh does the same).
export CONTAINERS_STORAGE_CONF="${CONTAINERS_STORAGE_CONF:-$ROOT/.runtime/podman/storage.conf}"
export CONTAINER_RUNROOT="${CONTAINER_RUNROOT:-$ROOT/.runtime/podman/runroot}"

mode=run
case "${1:-}" in
  --check) mode=check ;;
  --record) mode=record ;;
  run) mode=run ;;
  "") ;;
  *) echo "usage: tools/metavisor-tour.sh [--check|--record]" >&2; exit 2 ;;
esac

if [ "$mode" = "record" ]; then
  command -v asciinema >/dev/null || {
    echo "asciinema is not installed; cannot record the cast" >&2
    exit 1
  }
  mkdir -p "$(dirname "$CAST")"
  asciinema rec --overwrite --window-size 110x48 \
    --command "bash $ROOT/tools/metavisor-tour.sh run" "$CAST"
  echo "wrote $CAST"
  exit 0
fi

mkdir -p "$(dirname "$TRANSCRIPT")"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/sumonix-tour.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT
log="$tmp/transcript"

if [ "$mode" = "record" ]; then live=1; else live=0; fi
say() {
  if [ "$live" = "1" ]; then printf '%s\n' "$*" | tee -a "$log"
  else printf '%s\n' "$*" >> "$log"; fi
}
blank() { say ""; }

# Run a command, show it, and append what it printed (stderr warnings dropped:
# they are host noise, not evidence).
show() {
  local cmdline="$*"
  if [ "$live" = "1" ]; then printf '$ %s\n' "$cmdline" | tee -a "$log"
  else printf '$ %s\n' "$cmdline" >> "$log"; fi
  set +e
  "$@" > "$tmp/out" 2> "$tmp/err"
  local rc=$?
  grep -v '^evaluation warning:' "$tmp/err" >> "$tmp/out" || true
  grep -v '^warning: Git tree' "$tmp/out" >> "$log" || true
  return "$rc"
}

ctr() {
  podman exec "$CONTAINER_NAME" /run/current-system/sw/bin/bash -lc "$*"
}

# Force one metavisor tick and print the newest journal line (structured, no
# timestamps: `-o cat` keeps only the message).
tick() {
  ctr "systemctl start sumonix-metavisor.service" >/dev/null 2>&1 || true
  ctr "journalctl -t sumonix-metavisor -n 1 -o cat --no-pager" 2>/dev/null | tail -n 1
}

status() {
  ctr "/run/current-system/sw/bin/sumo status" 2>/dev/null \
    | sed -n '/METAVISOR/,$p' | sed '/^Facts:/,$d'
}

# Normalize live-but-volatile values so the transcript can be compared.
normalize() {
  sed -E \
    -e 's/snap-[0-9]+-[0-9a-f]+/snap-<id>/g' \
    -e 's/sha256:[0-9a-f]{64}/sha256:<hash>/g' \
    -e 's#/nix/store/[0-9a-z]+-#/nix/store/<hash>-#g' \
    -e 's/\([0-9]+ facts/(<n> facts/g' \
    -e 's/exporter [0-9a-f]{12,64}/exporter <exporter>/g' \
    -e 's/"ts":[0-9]+/"ts":<ts>/g' \
    -e 's/\bin [0-9]+(\.[0-9]+)?s\b/in <t>/g' \
    -e '/^real[[:space:]]/d' \
    -e 's/^[[:space:]]+$//' \
    -e '/^$/N;/^\n$/D'
}

# --- prerequisites -----------------------------------------------------------
if ! podman container exists "$CONTAINER_NAME" 2>/dev/null; then
  say "# building the NixOS container (first run only)"
  "$ROOT/container/run.sh" build >> "$tmp/build.log" 2>&1 || {
    tail -20 "$tmp/build.log" >&2
    exit 1
  }
  "$ROOT/container/run.sh" run >> "$tmp/build.log" 2>&1 || {
    tail -20 "$tmp/build.log" >&2
    exit 1
  }
fi

# A fresh container starts empty; the tour must be repeatable on a used one too.
ctr "systemctl start postgresql" >/dev/null 2>&1 || true
# Clean metavisor state: the tour is a recording, so it starts from zero on a
# reused container too (a fresh container is already empty).
ctr "rm -rf /var/lib/sumonix-metavisor/* /run/sumo/observed.kif" >/dev/null 2>&1 || true
ctr "systemctl reset-failed" >/dev/null 2>&1 || true
ctr "pkill -f 'nc -l' " >/dev/null 2>&1 || true

# --- scene 1: the gate -------------------------------------------------------
blank
say "1 · The gate: postgres listens on 0.0.0.0, the firewall allows nothing"
say "    -> the eval fails with a proof naming both option paths"
blank
set +e
show ./bin/sumo gate --configuration container/nixos/d1-bad.nix
gate_rc=$?
set -e
if [ "$gate_rc" -ne 1 ]; then
  say "!! expected gate exit 1, got $gate_rc"
  exit 1
fi

# --- scene 2: live drift -----------------------------------------------------
blank
say "2 · Stop the declared unit; one timer tick later the drift is proven"
blank
say "$ systemctl stop postgresql"
ctr "systemctl stop postgresql" >/dev/null 2>&1 || true
say "$ run the metavisor tick"
journal_drift="$(tick)"
status_drift="$(status)"
printf '%s\n' "$status_drift" >> "$log"
printf 'journal: %s\n' "$journal_drift" >> "$log"

printf '%s\n' "$status_drift" | grep -q 'status: drift' || {
  say "!! expected drift after stopping postgresql"
  exit 1
}
printf '%s\n' "$journal_drift" | grep -q 'drift unit=postgresql.service' || {
  say "!! the journal did not record the drift"
  exit 1
}

blank
say "    and a listener nobody declared is a violation, not a guess"
blank
say "$ nc -l 0.0.0.0 9999   # a rogue listener"
podman exec -d "$CONTAINER_NAME" /run/current-system/sw/bin/nc -l 0.0.0.0 9999 \
  >/dev/null 2>&1 || true
sleep 1
journal_rogue="$(tick)"
status_rogue="$(status)"
printf '%s\n' "$status_rogue" >> "$log"
printf 'journal: %s\n' "$journal_rogue" >> "$log"
printf '%s\n' "$status_rogue" | grep -q 'status: violation' || {
  say "!! expected a rogue-listener violation"
  exit 1
}
ctr "pkill -f 'nc -l'" >/dev/null 2>&1 || true
ctr "systemctl start postgresql" >/dev/null 2>&1 || true

# --- scene 3: repair, verified by re-lifting ---------------------------------
blank
say "3 · Repair: ranked single-option patches, each re-lifted and re-gated"
blank
set +e
show podman exec "$CONTAINER_NAME" /run/current-system/sw/bin/bash -lc \
  "/run/current-system/sw/bin/sumo repair --configuration /etc/nixos/bad.nix"
repair_rc=$?
set -e
if [ "$repair_rc" -ne 0 ]; then
  say "!! repair failed (exit $repair_rc)"
  exit 1
fi

# Apply the top patch mechanically: option path + value from the CLI's JSON.
set +e
patch="$(podman exec "$CONTAINER_NAME" /run/current-system/sw/bin/bash -lc \
  "/run/current-system/sw/bin/sumo repair --configuration /etc/nixos/bad.nix --json" 2>/dev/null \
  | tail -n 1 | jq -r '.ranked[0].edits[0] | "\(.optionPath) \(.value | tojson)"')"
set -e
[ -n "$patch" ] && [ "$patch" != "null null" ] || {
  say "!! could not read the top patch from the JSON"
  exit 1
}
option="${patch%% *}"
value="${patch#* }"
say "$(printf '$ apply #1: %s = %s' "$option" "$value")"

podman exec "$CONTAINER_NAME" /run/current-system/sw/bin/bash -lc "
  cat > /tmp/patched.nix <<'NIX'
{ lib, ... }: {
  imports = [ /etc/nixos/configuration.nix /etc/nixos/bad.nix ];
  $option = lib.mkOverride 10 $value;
}
NIX
" || { say "!! could not write /tmp/patched.nix"; exit 1; }

blank
say "$ nixos-rebuild build   # the gate runs inside the rebuild"
set +e
podman exec "$CONTAINER_NAME" /run/current-system/sw/bin/bash -lc \
  "cd /tmp && NIXOS_CONFIG=/tmp/patched.nix nixos-rebuild build --option sandbox false" \
  > "$tmp/rebuild.log" 2>&1
rebuild_rc=$?
set -e

if [ "$rebuild_rc" -ne 0 ]; then
  tail -20 "$tmp/rebuild.log" | tee -a "$log"
  say "!! rebuild failed"
  exit 1
fi
say "nixos-rebuild build: gate passed, the patched system built"

blank
set +e
show podman exec "$CONTAINER_NAME" /run/current-system/sw/bin/bash -lc \
  "/run/current-system/sw/bin/sumo repair --configuration /tmp/patched.nix"
set -e

# --- final state: the honest degraded mode ------------------------------------
blank
say "4 · Rootless limit, stated not hidden: postgres runs as its own uid, so"
say "    \`ss\` cannot attribute its socket -> status unknown, never a false pass (R1)"
blank
ctr "systemctl start postgresql" >/dev/null 2>&1 || true
journal_unknown="$(tick)"
status_unknown="$(status)"
printf '%s\n' "$status_unknown" >> "$log"
printf 'journal: %s\n' "$journal_unknown" >> "$log"
printf '%s\n' "$status_unknown" | grep -q 'status: unknown' || {
  say "!! expected unknown with a partial-attribution reason"
  exit 1
}
printf '%s\n' "$status_unknown" | grep -q 'unknown' || exit 1

normalize < "$log" > "$tmp/normalized"

if [ "$mode" = "check" ]; then
  if diff -u "$TRANSCRIPT" "$tmp/normalized" > "$tmp/diff"; then
    echo "metavisor tour: transcript byte-stable"
    exit 0
  fi
  cat "$tmp/diff" >&2
  echo "metavisor tour: transcript changed (re-run without --check to update)" >&2
  exit 1
fi

cp "$tmp/normalized" "$TRANSCRIPT"
if [ "$live" = "0" ]; then cat "$tmp/normalized"; fi
echo
echo "wrote $TRANSCRIPT"
