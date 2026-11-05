#!/usr/bin/env bash
# Convenience wrapper for nix eval with local store

export NIX_STORE_DIR=/home/me/sumonix/.nix-store
export NIX_STATE_DIR=/home/me/sumonix/.nix-state

exec nix --extra-experimental-features 'nix-command' eval --impure "$@"