#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

echo "🔨 Building NixOS VM (no flake, fast)..."
nix build -f '<nixpkgs/nixos>' system.build.vm -I nixos-config=./vm.nix --impure -o vm-result

echo "🚀 Booting VM (headless, serial console, 60s timeout)..."
timeout 60s ./vm-result/bin/run-*-vm \
  -nographic -serial mon:stdio -device virtio-rng-pci -no-reboot 2>&1 | \
  awk '
    /sumo-spike/ { in_spike=1 }
    in_spike { print }
    /⊢/ { saw_proof=1 }
    END { if (!saw_proof) exit 1 }
  '

echo ""
echo "✅ Spike completed inside NixOS VM"