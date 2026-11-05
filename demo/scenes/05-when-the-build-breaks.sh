#!/usr/bin/env bash
# Scene 5 — The gate: when one fact breaks policy, you get the proof — and the smallest override.
set -euo pipefail
source "$(dirname "$0")/../lib.sh"
rule; banner "🚧 THE BUILD FAILS — AND HERE IS WHY"; rule
say "A nixpkgs build about to ship CVE-2026-9999 in a *running* NIXService."
say "The gate fails the build. The proof is small enough to read."
./nix-eval.sh --raw --expr 'import ./demo/nix/policy-digest.nix'
say ""
say "Each ✓ is a true single-flip: if you could drop that fact, the build passes."
say "The relaxation menu is the honest answer to “what do I have to change for this to ship?”"
say ""
rule
