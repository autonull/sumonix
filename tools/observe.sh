#!/usr/bin/env bash
# M2-lite/M3A observer — dumb, read-only, facts + attestations out.
#
# Emits:
#   (snapshot <id> <timestamp>)
#   (completeFor unitActive <id>)            if all service units were enumerated
#   (observedActive <unit> <id>)             for every active service
#   (completeFor listener <id>)              only if every listener has an owner
#   (observedListener <comm> <addr> <port> <id>)
#   (attests <id> <sha256:hash> <expiry> <exporter>)
#
# TTL defaults to 60 s (SUMO_OBSERVE_TTL). The observed body is hashed; the
# attestation carries the hash, the expiry, and the exporter. No logic here.
set -euo pipefail
export LC_ALL=C

ttl="${SUMO_OBSERVE_TTL:-60}"
# hostname(1) is not always on the observer's PATH; the kernel's copy is.
exporter="${SUMO_OBSERVER_ID:-$(cat /proc/sys/kernel/hostname 2>/dev/null || echo unknown)}"
ts="$(date +%s)"
boot="$(cut -c1-8 /proc/sys/kernel/random/boot_id 2>/dev/null || echo "$$")"
id="snap-${ts}-${boot}"
expiry=$((ts + ttl))

kifq() {
  # Quote a value as a KIF string.
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  printf '"%s"' "$s"
}

payload=""
payload+="(snapshot $(kifq "$id") $(kifq "$ts"))"$'\n'

if command -v systemctl >/dev/null 2>&1 && \
   systemctl list-units --all --type=service --no-legend --plain --no-pager >/dev/null 2>&1; then
  payload+="(completeFor unitActive $(kifq "$id"))"$'\n'
  while IFS= read -r unit; do
    [ -z "$unit" ] && continue
    payload+="(observedActive $(kifq "$unit") $(kifq "$id"))"$'\n'
  done < <(systemctl list-units --type=service --state=active --no-legend --plain --no-pager 2>/dev/null | awk '{print $1}')
fi

listener_complete=true
listeners=""
if command -v ss >/dev/null 2>&1; then
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    local_addr="$(awk '{print $4}' <<<"$line")"
    proc="$(sed -n 's/.*users:(("\([^"]*\)".*/\1/p' <<<"$line")"
    [ -z "$proc" ] && listener_complete=false
    addr="$(sed -E 's/^\[([^]]*)\]:[0-9]+$/\1/; s/^([^:]+):[0-9]+$/\1/' <<<"$local_addr")"
    port="${local_addr##*:}"
    case "$addr" in
      "::"|"*"|"[::]") addr="0.0.0.0" ;;
    esac
    addr="${addr%%\%*}"
    if [ -n "$proc" ] && [ -n "$port" ]; then
      listeners+="(observedListener $(kifq "$proc") $(kifq "$addr") $(kifq "$port") $(kifq "$id"))"$'\n'
    fi
  done < <(ss -ltnpH 2>/dev/null)
fi
if [ "$listener_complete" = "true" ]; then
  payload+="(completeFor listener $(kifq "$id"))"$'\n'
  payload+="$listeners"
fi

hash="$(printf '%s' "$payload" | sha256sum | awk '{print $1}')"
printf '%s' "$payload"
printf '(attests %s %s %s %s)\n' \
  "$(kifq "$id")" "$(kifq "sha256:$hash")" "$(kifq "$expiry")" "$(kifq "$exporter")"
