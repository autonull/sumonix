#!/usr/bin/env bash
# demo/tour.sh — scripted tour inside the NixOS container.
# Installed by sumo-facts.service (or module) at /run/sumo/tour.sh.
# Run: podman exec -it -u demo sumonix-demo bash -lc 'source /run/sumo/tour.sh'

set -euo pipefail
export TZ=UTC LANG=C
PS1='demo@sumonix:~$ '

run() { printf '%s%s\n' "$PS1" "$1"; eval "$1"; printf '\n'; }

printf '%s\n' 'sumonix reasons about this NixOS system.'
printf '%s\n' 'Facts: live NixOS state + labelled nixpkgs/CVE fixture.'
printf '\n'

run 'sumo status'
run 'sumo caps'
run 'sumo closure openssl'
run "sumo query '(vulnerable nginx CVE-2026-9999)'"
run 'sumo whatif'
run 'echo "Starting dashboard (press q to quit)..."'
run 'timeout 10 sumo dashboard || true'

printf '%s\n' 'Tour complete. Interactive session ready.'