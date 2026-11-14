#!/usr/bin/env bash
# Convenience wrapper for nix eval with local store

source "$(dirname "$0")/tools/env.sh"

# Use the build store if SUMONIX_BUILD_STORE is set, otherwise use NIX_STORE_DIR
if [ -n "${SUMONIX_BUILD_STORE:-}" ]; then
  exec nix --extra-experimental-features 'nix-command' --store "$SUMONIX_BUILD_STORE" eval --impure "$@"
else
  exec nix --extra-experimental-features 'nix-command' eval --impure "$@"
fi