#!/usr/bin/env bash
# Scene 2 — Your package set is a knowledge graph: ask what it can compose.
set -euo pipefail
source "$(dirname "$0")/../lib.sh"
rule; banner "📦 YOUR PACKAGE SET, REASONED OVER"; rule
say "Facts: instance/dependsOn/hasLicense/providesCapability for 60 real nixpkgs packages"
say "     (fetched once, pinned, committed to demo/facts/nixpkgs.kif)."
say ""
cmd "./nix-eval.sh --raw --expr '(import ./spike/run-spike.nix { snapshot = builtins.readFile ./demo/facts/nixpkgs.kif; })'"
./nix-eval.sh --raw --expr '(import ./spike/run-spike.nix { snapshot = builtins.readFile ./demo/facts/nixpkgs.kif; })'
say ""
rule
