#!/usr/bin/env bash
# Convenience wrapper for nix eval with local store

source "$(dirname "$0")/tools/env.sh"

exec nix --extra-experimental-features 'nix-command' eval --impure "$@"