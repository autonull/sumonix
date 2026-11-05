#!/usr/bin/env bash
# Scene 1 — The 30-second proof: derive, export, re-check.
set -euo pipefail
source "$(dirname "$0")/../lib.sh"
rule; banner "🐺 THE 30-SECOND PROOF"; rule
say "A build fails. The engine knows why. The why is a file you can re-check."
say ""
say "Step 1 — the reasoner finds: nginx breaks the advisory policy."
cmd "./nix-eval.sh --raw --expr 'import ./tests/proof-artifact.nix' > /tmp/proof.kif"
./nix-eval.sh --raw --expr 'import ./tests/proof-artifact.nix' > /tmp/proof.kif
say "wrote /tmp/proof.kif ($(wc -l < /tmp/proof.kif) lines)"
say ""
say "Step 2 — re-check the certificate with a checker that shares no code with the engine."
cmd "./nix-eval.sh --expr '(import ./proof-check.nix { file = /tmp/proof.kif; })'"
./nix-eval.sh --expr '(import ./proof-check.nix { file = /tmp/proof.kif; })'
say ""
say "Step 3 — alter the certified goal; the checker must refuse it."
cmd "cp /tmp/proof.kif /tmp/proof-bad.kif"
cp /tmp/proof.kif /tmp/proof-bad.kif
cmd "sed -i 's/(goal (policyViolation nginx NoCriticalRunningCVE) \"s9\")/(goal (policyViolation nginx NOPE) \"s9\")/' /tmp/proof-bad.kif"
sed -i 's/(goal (policyViolation nginx NoCriticalRunningCVE) "s9")/(goal (policyViolation nginx NOPE) "s9")/' /tmp/proof-bad.kif
cmd "./nix-eval.sh --expr '(import ./proof-check.nix { file = /tmp/proof-bad.kif; })'"
if ./nix-eval.sh --expr '(import ./proof-check.nix { file = /tmp/proof-bad.kif; })' 2>/tmp/proof-bad.err; then
  say "unexpected: the tampered proof was accepted"
else
  say "refused ✓  (the checker exits non-zero and says which line broke)"
  sed 's/^/  /' /tmp/proof-bad.err | head -5
fi
say ""
rule
