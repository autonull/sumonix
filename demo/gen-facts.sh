#!/usr/bin/env bash
# Regenerate demo/facts/nixpkgs.kif from the pinned nixpkgs.
# The file is committed so the demo works offline; run this to refresh it.
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$(pwd)"
export NIX_STORE_DIR="$ROOT/.nix-store" NIX_STATE_DIR="$ROOT/.nix-state"
REV="${NIXPKGS_REV:-1d060086d60cb76a40cf37109f979d88a5bd6396}"
OUT="$(nix --extra-experimental-features 'nix-command flakes' eval --impure --raw \
  --expr "(builtins.getFlake \"github:NixOS/nixpkgs/${REV}\").outPath")"
nix --extra-experimental-features 'nix-command flakes' eval --impure --raw \
  --expr "(import ./spike/nixpkgs-snapshot.nix { pkgs = import ${OUT} {}; })" > demo/facts/nixpkgs.kif
echo "wrote $(wc -l < demo/facts/nixpkgs.kif) lines to demo/facts/nixpkgs.kif (nixpkgs ${REV:0:12})"
