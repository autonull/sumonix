#!/usr/bin/env bash
# demo/vm/build.sh — build the sumonix demo VM.
#
# Uses a *root store* under the repo ($SUMONIX_BUILD_ROOT). Nix keeps logical
# paths as /nix/store/... so cache.nixos.org substitutes match, but every NAR
# is stored inside the repository. No writes to /nix, no root required.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
VM_DIR="$ROOT/demo/vm"
source "$ROOT/tools/env.sh"

mkdir -p "$SUMONIX_BUILD_ROOT"

echo "Building sumonix demo VM"
echo "  repo : $ROOT"
echo "  store: $SUMONIX_BUILD_STORE"

export NIX_CONFIG="substituters = ${SUMONIX_SUBSTITUTERS}
trusted-public-keys = ${SUMONIX_TRUSTED_KEYS}
sandbox = false
build-users-group ="

exec nix --extra-experimental-features 'nix-command flakes' \
  --store "$SUMONIX_BUILD_STORE" \
  --max-jobs "${SUMONIX_MAX_JOBS:-4}" \
  build "$ROOT#nixosConfigurations.demo.config.system.build.vm" \
  -o "$VM_DIR/result-vm" \
  --print-out-paths
