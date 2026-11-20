#!/usr/bin/env bash
# M2-lite/M3A observer — dumb, read-only, facts + attestations out.
#
# Emits:
#   (snapshot <id> <timestamp>) { meta: {...} }
#   (completeFor unitActive <id>) { meta: {...} }
#   (observedActive <unit> <id>) { meta: {...} }
#   (completeFor listener <id>) { meta: {...} }
#   (observedListener <comm> <addr> <port> <id>) { meta: {...} }
#   (attests <id> <sha256:hash> <expiry> <exporter>) { meta: {...} }
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

# Emit a fact with meta
emit_fact() {
  local fact="$1"
  local snapshot_id="$2"
  local now="$3"
  local expiry="$4"
  local exporter="$5"
  local hash=$(printf '%s' "$fact" | sha256sum | awk '{print $1}')
  printf '%s { meta: { sourceClass: "observed", sourceId: "tools/observe.sh", observedAt: %d, expiresAt: %d, snapshotId: "%s", contentHash: "sha256:%s", confidence: 1.0, provenance: [] } }\n' \
    "$fact" "$now" "$expiry" "$snapshot_id" "$hash"
}

payload=""

# snapshot fact
payload+="$(emit_fact "(snapshot $(kifq "$id") $(kifq "$ts"))" "$id" "$ts" "$expiry" "$exporter")"

if command -v systemctl >/dev/null 2>&1 && \
   systemctl list-units --all --type=service --no-legend --plain --no-pager >/dev/null 2>&1; then
  payload+="$(emit_fact "(completeFor unitActive $(kifq "$id"))" "$id" "$ts" "$expiry" "$exporter")"
  while IFS= read -r unit; do
    [ -z "$unit" ] && continue
    payload+="$(emit_fact "(observedActive $(kifq "$unit") $(kifq "$id"))" "$id" "$ts" "$expiry" "$exporter")"
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
      listeners+="$(emit_fact "(observedListener $(kifq "$proc") $(kifq "$addr") $(kifq "$port") $(kifq "$id"))" "$id" "$ts" "$expiry" "$exporter")"
    fi
  done < <(ss -ltnpH 2>/dev/null)
fi
if [ "$listener_complete" = "true" ]; then
  payload+="$(emit_fact "(completeFor listener $(kifq "$id"))" "$id" "$ts" "$expiry" "$exporter")"
  payload+="$listeners"
fi

hash="$(printf '%s' "$payload" | sha256sum | awk '{print $1}')"
printf '%s' "$payload"
# attests fact also gets meta
attest_fact="(attests $(kifq "$id") $(kifq "sha256:$hash") $(kifq "$expiry") $(kifq "$exporter"))"
attest_hash=$(printf '%s' "$attest_fact" | sha256sum | awk '{print $1}')
printf '%s { meta: { sourceClass: "observed", sourceId: "tools/observe.sh", observedAt: %d, expiresAt: %d, snapshotId: "%s", contentHash: "sha256:%s", confidence: 1.0, provenance: [] } }\n' \
  "$attest_fact" "$ts" "$expiry" "$id" "$attest_hash"