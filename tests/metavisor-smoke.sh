#!/usr/bin/env bash
# M3A smoke test — the resident tick, event log, degraded modes and status.
# Runs the real CLI against a real (temporary) NixOS config.
set -euo pipefail
cd "$(dirname "$0")/.."

tmp="$(mktemp -d "${TMPDIR:-/tmp}/sumonix-metavisor.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

cat > "$tmp/configuration.nix" <<'EOF'
{ lib, ... }: {
  system.stateVersion = "24.11";
  services.postgresql.enable = true;
  services.postgresql.settings.listen_addresses = lib.mkForce "0.0.0.0";
  networking.firewall.allowedTCPPorts = lib.mkForce [ ];
}
EOF

./bin/sumo lift --configuration "$tmp/configuration.nix" > "$tmp/declared.kif"

# A fresh snapshot that attests completeness but omits the declared unit.
cat > "$tmp/observer-drift.sh" <<'EOF'
#!/usr/bin/env bash
cat <<'KIF'
(snapshot "s1" "1000")
(attests "s1" "sha256:aaaa" "9999999999" "fake-observer")
(completeFor unitActive "s1")
(completeFor listener "s1")
KIF
EOF
cat > "$tmp/observer-pass.sh" <<'EOF'
#!/usr/bin/env bash
cat <<'KIF'
(snapshot "s2" "2000")
(attests "s2" "sha256:bbbb" "9999999999" "fake-observer")
(completeFor unitActive "s2")
(completeFor listener "s2")
(observedActive "postgresql.service" "s2")
KIF
EOF
chmod +x "$tmp"/observer-*.sh

tick() {
  SUMO_OBSERVER="$1" ./tools/metavisor.sh \
    --declared "$tmp/declared.kif" --observed "$tmp/observed.kif" \
    --state-dir "$tmp/state" --interval 60
}

tick "$tmp/observer-drift.sh"
[ "$(wc -l < "$tmp/state/events.jsonl")" -eq 1 ] || {
  echo "expected one drift event" >&2; exit 1; }
[ "$(cat "$tmp/state/last-status")" = "drift" ] || {
  echo "expected drift status" >&2; exit 1; }

# The same observation must not append a duplicate event.
tick "$tmp/observer-drift.sh"
[ "$(wc -l < "$tmp/state/events.jsonl")" -eq 1 ] || {
  echo "duplicate drift event appended" >&2; exit 1; }

# Fix the observation: one resolved event, no drift claim.
tick "$tmp/observer-pass.sh"
[ "$(wc -l < "$tmp/state/events.jsonl")" -eq 2 ] || {
  echo "expected a resolved event" >&2; exit 1; }
grep -q '"kind":"resolved"' "$tmp/state/events.jsonl" || {
  echo "resolved event missing" >&2; exit 1; }

# The operator surface must show the source-labeled section and explain drift.
SUMO_DECLARED="$tmp/declared.kif" SUMO_OBSERVED="$tmp/observed.kif" \
  ./bin/sumo status | grep -q "METAVISOR" || {
  echo "status has no metavisor section" >&2; exit 1; }

tick "$tmp/observer-drift.sh"
SUMO_DECLARED="$tmp/declared.kif" SUMO_OBSERVED="$tmp/observed.kif" \
  ./bin/sumo why '(drift "postgresql.service")' | grep -q "declaredRunning" || {
  echo "sumo why does not explain drift" >&2; exit 1; }

# A stale snapshot must yield unknown and never a drift claim.
cat > "$tmp/observed.kif" <<'EOF'
(snapshot "old" "1")
(attests "old" "sha256:eeee" "2" "fake-observer")
(completeFor unitActive "old")
(completeFor listener "old")
EOF
SUMO_DECLARED="$tmp/declared.kif" SUMO_OBSERVED="$tmp/observed.kif" \
  ./bin/sumo drift --json | grep -q '"status":"unknown"' || {
  echo "stale observation did not report unknown" >&2; exit 1; }

echo "metavisor smoke: ok"
