#!/usr/bin/env bash
# Shared environment for sumo-nix scripts. Sourced by nix-eval.sh, run-tests.sh,
# demo/lib.sh, spike/demo.sh, and bin/sumo.

set -euo pipefail

# Repository root (absolute path).
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Local Nix store/state directories (warm closures for fast evals).
export NIX_STORE_DIR="${ROOT}/.nix-store"
export NIX_STATE_DIR="${ROOT}/.nix-state"