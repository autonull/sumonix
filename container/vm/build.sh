#!/usr/bin/env bash
# demo/vm/build.sh — build the sumonix demo VM.
#
# Uses a *root store* under the repo ($SUMONIX_BUILD_ROOT). Nix keeps logical
# paths as /nix/store/... so cache.nixos.org substitutes match, but every NAR
# is stored inside the repository. No writes to /nix, no root required.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
VM_DIR="$ROOT/demo/vm"

# Source only the build-related vars; DO NOT set NIX_STORE_DIR/NIX_STATE_DIR
# (those are for eval-only work via the local store; builds use --store)
SUMONIX_BUILD_ROOT="${SUMONIX_BUILD_ROOT:-${ROOT}/.nix-root}"
SUMONIX_BUILD_STORE="local?root=${SUMONIX_BUILD_ROOT}"
SUMONIX_SUBSTITUTERS="${SUMONIX_SUBSTITUTERS:-https://cache.nixos.org}"
SUMONIX_TRUSTED_KEYS="${SUMONIX_TRUSTED_KEYS:-cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=}"

mkdir -p "$SUMONIX_BUILD_ROOT"

echo "Building sumonix demo VM"
echo "  repo : $ROOT"
echo "  store: $SUMONIX_BUILD_STORE"

export NIX_CONFIG="substituters = ${SUMONIX_SUBSTITUTERS}
trusted-public-keys = ${SUMONIX_TRUSTED_KEYS}
sandbox = false
build-users-group ="

# Unset NIX_STORE_DIR/NIX_STATE_DIR to ensure --store is respected
unset NIX_STORE_DIR
unset NIX_STATE_DIR

exec nix --extra-experimental-features 'nix-command flakes' \
  --store "$SUMONIX_BUILD_STORE" \
  --max-jobs "${SUMONIX_MAX_JOBS:-4}" \
  build "$ROOT#nixosConfigurations.demo.config.system.build.vm" \
  -o "$VM_DIR/result-vm" \
  --print-out-paths
