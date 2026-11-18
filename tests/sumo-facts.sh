#!/usr/bin/env bash
# M0.3 — sumo-facts smoke test: the live exporter, run against stubs.
# Proves the advertised `sumo-facts` package emits parseable KIF for a running
# unit and a listener, without a NixOS host.
set -euo pipefail
cd "$(dirname "$0")/.."
source ./tools/env.sh

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/bin" "$work/run/sumo"

cat > "$work/bin/systemctl" <<'EOF'
#!/bin/sh
case "$*" in
  "list-units --type=service --state=running --no-legend")
    printf 'nginx.service loaded active running A high performance web server\n'
    ;;
  "show -p MainPID --value nginx.service") printf '42\n' ;;
  "show -p User --value nginx.service") printf 'nginx\n' ;;
  *) exit 0 ;;
esac
EOF

cat > "$work/bin/ss" <<'EOF'
#!/bin/sh
printf 'LISTEN 0 128 0.0.0.0:80 0.0.0.0:* users:(("nginx",pid=42,fd=6))\n'
EOF

cat > "$work/bin/nix-store" <<'EOF'
#!/bin/sh
case "$1" in
  -q) printf '/nix/store/aaaa-nginx-1.27.0\n/nix/store/bbbb-openssl-3.3.0\n' ;;
  *) exit 0 ;;
esac
EOF
chmod +x "$work/bin/systemctl" "$work/bin/ss" "$work/bin/nix-store"

PATH="$work/bin:$PATH" FACTS_DIR="$work/run/sumo" \
  sh ./container/nix/sumo-facts.sh > "$work/out.log" 2>&1 \
  || { cat "$work/out.log" >&2; echo "sumo-facts: exporter failed" >&2; exit 1; }

facts="$work/run/sumo/facts.kif"
[ -s "$facts" ] || { echo "sumo-facts: no facts written" >&2; exit 1; }

grep -q '^(instance nginx NIXService)' "$facts" || { cat "$facts" >&2; exit 1; }
grep -q '^(serviceState nginx running)' "$facts" || exit 1
grep -q '^(listensOn nginx 80)' "$facts" || { cat "$facts" >&2; exit 1; }
grep -q '^(runningAs nginx nginx)' "$facts" || exit 1
grep -q '^(instance nginx NIXPackage)' "$facts" || exit 1

# The output must be valid KIF (parse, not just grep).
./nix-eval.sh --expr "builtins.length ((import ./lib/kif.nix { }).parse (builtins.readFile \"$facts\"))" >/dev/null

echo "sumo-facts: ok"
