#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

echo "🔨 Building NixOS VM (no flake, fast)..."
nix --extra-experimental-features 'nix-command flakes' build -f '<nixpkgs/nixos>' system.build.vm -I nixos-config=./vm.nix --impure -o vm-result

echo "🚀 Booting VM (headless, serial console, 60s timeout)..."
echo "   Discovering what capabilities your packages can compose..."
echo ""
timeout 60s ./vm-result/bin/run-*-vm \
  -nographic -serial mon:stdio -device virtio-rng-pci -no-reboot 2>&1 | \
  awk '
    /SUMO-NIX CAPABILITY DISCOVERY/ { in_spike=1 }
    in_spike { print }
    /✨ Spike complete/ { saw_complete=1 }
    END { if (!saw_complete) exit 1 }
  '

echo ""
echo "🎉 Capability discovery complete! Your nixpkgs is a goldmine."