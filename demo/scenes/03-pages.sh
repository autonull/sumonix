#!/usr/bin/env bash
# Scene 3 — Your organization is facts too: the Pick Your AI pages, taxonomized under SUMO.
set -euo pipefail
source "$(dirname "$0")/../lib.sh"
rule; banner "📚 YOUR ORGANIZATION, REASONED OVER"; rule
say "Facts: every page of the Pick Your AI repositories, read at the pinned commits,"
say "     taxonomized under SUMO's Document hierarchy. Computed in ~5s, offline."
say ""
say "What the engine finds:"
./nix-eval.sh --raw --expr 'import ./demo/nix/org-digest.nix'
say ""
rule
