#!/usr/bin/env bash
# demo/vm/build.sh — Build the sumonix demo VM
# Builds the NixOS VM with the repo source using system store with binary substitutes.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
VM_DIR="$(dirname "$0")"

echo "Building sumonix demo VM..."
echo "Repo: $ROOT"

# Use system nix store with binary substitutes from cache.nixos.org
# The local .nix-conf/nix.conf has the substituters configured

# Build the VM using nix
export SUMONIX_REPO_ROOT="$ROOT"
nix --extra-experimental-features 'nix-command flakes' \
  --option sandbox false \
  --option build-users-group "" \
  build --expr "(import $VM_DIR/vm-wrapper.nix { pkgs = import <nixpkgs> { }; repoRoot = \"$ROOT\"; configFile = \"$VM_DIR/vm.nix\"; })" \
  -I nixpkgs=channel:nixos-unstable \
  -I nixos-config=$VM_DIR/vm.nix \
  --impure \
  -o "$VM_DIR/result-vm"

echo "VM built at $VM_DIR/result-vm"
echo "Run with: $VM_DIR/result-vm/bin/run-*-vm"