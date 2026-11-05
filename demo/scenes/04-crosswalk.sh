#!/usr/bin/env bash
# Scene 4 — The crosswalk answers typed questions; where it has nothing, it says so.
set -euo pipefail
source "$(dirname "$0")/../lib.sh"
rule; banner "🧭 THE CROSSWALK KNOWS WHAT IT KNOWS"; rule
say "PyAI fields ↔ Hugging Face tags ↔ SUMO classes. Answers are 0/1 plus an explicit null."
./nix-eval.sh --raw --expr 'import ./demo/nix/crosswalk-digest.nix'
say ""
rule
