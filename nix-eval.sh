#!/usr/bin/env bash
# Convenience wrapper for nix eval.
#
# Store policy: evaluation is eval-only work, so it uses the local store
# (NIX_STORE_DIR, prefix-rewritten) by default. That store cannot substitute
# binary closures or build systems, which is the point: a stray eval must not
# grow a multi-GB build store. The root build store is opt-in:
#
#   SUMONIX_BUILD=1 ./nix-eval.sh ...      # or --build-store
#
# Builds (VM, container, packages) belong in CI, per AGENTS.md.

source "$(dirname "$0")/tools/env.sh"

build_store=0
args=()
for arg in "$@"; do
  case "$arg" in
    --build-store) build_store=1 ;;
    *) args+=("$arg") ;;
  esac
done
if [ "${SUMONIX_BUILD:-0}" = "1" ]; then
  build_store=1
fi

if [ "$build_store" = "1" ] && [ -n "${SUMONIX_BUILD_STORE:-}" ]; then
  exec nix --extra-experimental-features 'nix-command' \
    --store "$SUMONIX_BUILD_STORE" eval --impure "${args[@]}"
fi

exec nix --extra-experimental-features 'nix-command' eval --impure "${args[@]}"
