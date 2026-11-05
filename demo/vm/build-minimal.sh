#!/usr/bin/env bash
# demo/vm/build-minimal.sh — build the minimal sumonix demo VM
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
VM_DIR="$ROOT/demo/vm"

SUMONIX_BUILD_ROOT="${SUMONIX_BUILD_ROOT:-${ROOT}/.nix-root}"
SUMONIX_BUILD_STORE="local?root=${SUMONIX_BUILD_ROOT}"
SUMONIX_SUBSTITUTERS="${SUMONIX_SUBSTITUTERS:-https://cache.nixos.org}"
SUMONIX_TRUSTED_KEYS="${SUMONIX_TRUSTED_KEYS:-cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=}"

mkdir -p "$SUMONIX_BUILD_ROOT"

echo "Building MINIMAL sumonix demo VM"
echo "  repo : $ROOT"
echo "  store: $SUMONIX_BUILD_STORE"

export NIX_CONFIG="substituters = ${SUMONIX_SUBSTITUTERS}
trusted-public-keys = ${SUMONIX_TRUSTED_KEYS}
sandbox = false
build-users-group ="

unset NIX_STORE_DIR
unset NIX_STATE_DIR

exec nix --extra-experimental-features 'nix-command flakes' \
  --store "$SUMONIX_BUILD_STORE" \
  --max-jobs "${SUMONIX_MAX_JOBS:-4}" \
  build "$ROOT#nixosConfigurations.demo-minimal.config.system.build.vm" \
  -o "$VM_DIR/result-vm-minimal" \
  --print-out-paths