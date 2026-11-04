# Phase 4 — Proof export and independent check. The committed proof.kif must re-check
# clean, and four tampered variants must each fail loudly (different failure modes).
# Usage: nix --extra-experimental-features nix-command eval --impure --expr 'import ./tests/proof-check.nix'  -> "ok"
let
  check = what: ok: if ok then true else throw "failed: ${what}";
  cert = import ./proof-artifact.nix;
  checker = file: (import ../proof-check.nix { inherit file; });
  fails = file: !(builtins.tryEval (checker file)).success;
  tamperedFact = builtins.toFile "tampered-fact.kif"
    (builtins.replaceStrings [ "(vulnerable openssl CVE-2026-9999)" ]
                             [ "(vulnerable openssl CVE-2027-0001)" ] cert);
  tamperedBindings = builtins.toFile "tampered-bindings.kif"
    (builtins.replaceStrings [ "(step \"s6\" (vulnerable app CVE-2026-9999) \"vulnerable#3\" (bindings (?cve CVE-2026-9999) (?dep openssl) (?pkg app)))" ]
                             [ "(step \"s6\" (vulnerable app CVE-2026-9999) \"vulnerable#3\" (bindings (?cve CVE-2026-9999) (?dep openssl) (?pkg hello)))" ] cert);
  tamperedGoal = builtins.toFile "tampered-goal.kif"
    (builtins.replaceStrings [ "(goal (policyViolation nginx NoCriticalRunningCVE) \"s9\")" ]
                             [ "(goal (policyViolation nginx NoCriticalRunningCVE) \"s8\")" ] cert);
  # s9 needs s8's fact — moving s9 ahead of s8 violates the premise prefix
  swappedSteps = builtins.toFile "swapped-steps.kif"
    (builtins.replaceStrings
      [ "(step \"s8\" (vulnerable nginx CVE-2026-9999) \"vulnerable#3\" (bindings (?cve CVE-2026-9999) (?dep openssl) (?pkg nginx)))\n(step \"s9\" (policyViolation nginx NoCriticalRunningCVE) \"policyViolation#4\" (bindings (?cve CVE-2026-9999) (?pkg nginx)))" ]
      [ "(step \"s9\" (policyViolation nginx NoCriticalRunningCVE) \"policyViolation#4\" (bindings (?cve CVE-2026-9999) (?pkg nginx)))\n(step \"s8\" (vulnerable nginx CVE-2026-9999) \"vulnerable#3\" (bindings (?cve CVE-2026-9999) (?dep openssl) (?pkg nginx)))" ]
      cert);
  okMessage = checker ../proof.kif;
in
if builtins.all (x: x) [
  (check "the committed artifact re-checks clean" (builtins.substring 0 6 okMessage == "proof:"))
  (check "a flipped axiom fails the re-check" (fails tamperedFact))
  (check "a swapped binding fails the re-check" (fails tamperedBindings))
  (check "a mis-named goal step fails the re-check" (fails tamperedGoal))
  (check "out-of-order steps fail the re-check (premise prefix is enforced)" (fails swappedSteps))
] then "ok" else "failed"
