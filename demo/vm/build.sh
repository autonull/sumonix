#!/usr/bin/env bash
# demo/vm/build.sh — Build the sumonix demo VM
# Builds the NixOS VM with the repo source using local store.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
VM_DIR="$(dirname "$0")"

echo "Building sumonix demo VM..."
echo "Repo: $ROOT"

# Use local store for building
export NIX_STORE_DIR="$ROOT/.nix-store"
export NIX_STATE_DIR="$ROOT/.nix-state"

# Find nixpkgs in local store
NIXPKGS_PATH=$(find "$ROOT/.nix-store/nix/store" -maxdepth 1 -name "*-source" -type d | head -1)
if [ -z "$NIXPKGS_PATH" ]; then
  echo "Error: nixpkgs source not found in local store"
  exit 1
fi
echo "Using nixpkgs at: $NIXPKGS_PATH"

# Build the VM using nix
export SUMONIX_REPO_ROOT="$ROOT"
nix --extra-experimental-features 'nix-command flakes' \
  build -f "$NIXPKGS_PATH/nixos" vm \
  -I nixos-config="$VM_DIR/vm.nix" \
  --argstr repoRoot "$ROOT" \
  --impure \
  -o "$VM_DIR/result-vm"

echo "VM built at $VM_DIR/result-vm"
echo "Run with: $VM_DIR/result-vm/bin/run-*-vm"