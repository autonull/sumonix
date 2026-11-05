#!/usr/bin/env bash
# Shared environment for sumo-nix scripts. Sourced by nix-eval.sh, run-tests.sh,
# demo/lib.sh, spike/demo.sh, and bin/sumo.

set -euo pipefail

# Repository root (absolute path).
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Local Nix store/state directories (warm closures for fast evals).
#
# NOTE: NIX_STORE_DIR rewrites store paths, so this store can never fetch
# substitutes (cache.nixos.org is keyed on /nix/store/... hashes). It is for
# eval-only work whose outputs are already present.
export NIX_STORE_DIR="${ROOT}/.nix-store"
export NIX_STATE_DIR="${ROOT}/.nix-state"

# Root store for *building*. Nix keeps logical paths as /nix/store/... (so
# binary-cache hashes match) but puts the NARs under ${ROOT}/.nix-root.
# Nothing is written outside the repository; no root privileges needed.
export SUMONIX_BUILD_ROOT="${SUMONIX_BUILD_ROOT:-${ROOT}/.nix-root}"
export SUMONIX_BUILD_STORE="local?root=${SUMONIX_BUILD_ROOT}"
export SUMONIX_SUBSTITUTERS="${SUMONIX_SUBSTITUTERS:-https://cache.nixos.org}"
export SUMONIX_TRUSTED_KEYS="${SUMONIX_TRUSTED_KEYS:-cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=}"