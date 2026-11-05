#!/usr/bin/env bash
# demo/vm/session.sh — Scripted tour for the sumonix demo VM.
# Deterministic command sequence on the autologin console, byte-stable.
# Broadcast as an *input* (keystrokes) to the console; interactive use is unaffected.

set -euo pipefail

# Normalize environment for byte-stable output
export TZ=UTC
export LANG=C
export PS1='demo@sumonix:~$ '

# Helper to run a command with normalized output
run_cmd() {
  local cmd="$1"
  echo "$PS1$cmd"
  eval "$cmd"
  echo ""
}

# Wait for prompt
sleep 2

# The tour sequence
run_cmd "sumo status"
sleep 1

run_cmd "sumo caps"
sleep 1

run_cmd "sumo closure nginx"
sleep 1

run_cmd "sumo query '(vulnerable nginx CVE-2026-9999)'"
sleep 1

run_cmd "sumo whatif"
sleep 1

# Dashboard would be interactive; we just show it starts
run_cmd "echo 'Starting dashboard (press q to quit)...'"
run_cmd "timeout 5 sumo dashboard || true"
sleep 1

echo "Tour complete. The VM is ready for interactive exploration."