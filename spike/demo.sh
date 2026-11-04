#!/usr/bin/env bash
# Build and boot the sumo-nix capability discovery VM.
# Builds run through the local Nix daemon; the machine needs a writable /nix/store
# (root, or a daemon with build users) and kernel namespaces for the sandbox.
# Optional: set NIXPKGS_PATH to a nixpkgs source tree; otherwise the nixpkgs flake from your registry is used.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export NIXPKGS_PATH="${NIXPKGS_PATH:-}"

NIX_COMMON=(--extra-experimental-features 'nix-command flakes')

echo "🔨 Resolving nixpkgs..."
if [ -z "$NIXPKGS_PATH" ]; then
  NIXPKGS_PATH="$(nix "${NIX_COMMON[@]}" eval --impure --raw --expr '(builtins.getFlake "nixpkgs").outPath')"
fi
echo "   Using nixpkgs at: $NIXPKGS_PATH"

echo "🔨 Building NixOS VM (no flake, fast)..."
nix "${NIX_COMMON[@]}" build -f "${NIXPKGS_PATH}/nixos" vm \
  -I nixos-config="${REPO_ROOT}/spike/vm.nix" --impure -o "${REPO_ROOT}/vm-result"

echo "🚀 Booting VM (headless, serial console, ${SPIKE_TIMEOUT:-180}s timeout)..."
echo "   Discovering what capabilities your packages can compose..."
echo ""
timeout "${SPIKE_TIMEOUT:-180}s" "${REPO_ROOT}"/vm-result/bin/run-*-vm \
  -nographic -serial mon:stdio -device virtio-rng-pci -no-reboot 2>&1 | \
  awk '
    /SUMO-NIX CAPABILITY DISCOVERY/ { in_spike=1 }
    in_spike { print }
    /✨ Spike complete/ { saw_complete=1 }
    END { if (!saw_complete) exit 1 }
  '

echo ""
echo "🎉 Capability discovery complete! Your nixpkgs is a goldmine."
