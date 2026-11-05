# Phase 2 — Stratifier. Crafted unstratifiable/stratifiable rule sets + the pinned corpus.
# Usage: nix --extra-experimental-features nix-command eval --impure --expr 'import ./tests/unit/stratify.nix'  -> "ok"
let
  kif = import ../../lib/kif.nix { };
  pins = import ../../pins.nix;

  crafted = kif.parse ''
    (=> (b ?x) (a ?x))
    (=> (not (a ?x)) (b ?x))
    (=> (a ?x) (c ?x))
    (=> (holdsItem ?x) (inStock ?x))
    (=> (and (inStock ?x) (not (discontinued ?x))) (canOrder ?x))
  '';
  s = import ../../reasoner/stratify.nix { rules = crafted; };

  admitted = import ../../reasoner/stratify.nix { rules = crafted; manualAdmission = [ "a" "b" ]; };

  # A recursive positive cycle plus a safe negation: fully stratifiable.
  recursive = kif.parse ''
    (=> (and (edge ?a ?b) (edge ?b ?c)) (edge ?a ?c))
    (=> (and (inside ?x ?y) (not (sealed ?y))) (reachable ?x ?y))
  '';
  recResult = import ../../reasoner/stratify.nix { rules = recursive; };

  pinned = kif.parse (builtins.readFile pins.merge);
  pinnedRules = builtins.filter (f: builtins.head f == "=>") pinned;
  corpus = import ../../reasoner/stratify.nix { rules = pinnedRules; };

  check = what: ok: if ok then true else throw "failed: ${what}";
  rejectedIds = map (r: r.rule) s.rejections;
in
if builtins.all (x: x) [
  # --- crafted ---------------------------------------------------------------
  (check "a cycle through a negative edge rejects both predicates' rules"
    (builtins.elem "a" s.unstratifiable && builtins.elem "b" s.unstratifiable))
  (check "the untroubled predicate c is not unstratifiable" (!(builtins.elem "c" s.unstratifiable)))
  (check "rules deriving an unstratifiable predicate are rejected with a reason"
    (builtins.all (r: r.reason == "unstratified-negation") s.rejections))
  (check "both neg-cycle rules are rejected"
    (builtins.length s.rejections == 2))
  (check "no rejection line is silent" (builtins.all (r: r ? predicate && r ? rule) s.rejections))
  (check "manual admission keeps the exception and logs it"
    (admitted.admittedUnstratified == [ "a" "b" ] && admitted.rejections == [ ]))
  (check "the admitted exception shows up in diagnostics" (admitted.diagnostics.manualAdmission != [ ]))
  # --- stratifiable recursion ---------------------------------------------------
  (check "positive recursion is stratifiable with no rejections"
    (recResult.rejections == [ ] && recResult.admittedUnstratified == [ ]))
  (check "the negated premise sits in a lower stratum than its reader"
    (let
      stratum = p: (builtins.head (builtins.filter (x: x.predicate == p) recResult.strata)).stratum;
    in stratum "sealed" < stratum "reachable"))
  # --- pinned corpus -----------------------------------------------------------
  (check "the corpus stratifier runs and finds the negative cycles"
    (corpus.diagnostics.predicates > 0 && builtins.length corpus.unstratifiable > 0))
  (check "every corpus rejection carries the unstratified-negation reason"
    (builtins.all (r: r.reason == "unstratified-negation") corpus.rejections))
  (check "corpus diagnostics lists rejected rules, not silent drops"
    (builtins.all (r: r ? rule && r ? predicate) corpus.rejections))
  (check "corpus stratum assignment is stable" corpus.diagnostics.strataStable)
] then "ok" else "failed"
