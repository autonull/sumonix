# Phase 1 — Declaration-driven Horn synthesis (G4). Crafted declarations + the pinned corpus.
# Usage: nix --extra-experimental-features nix-command eval --impure --expr 'import ./tests/unit/synthesize.nix'  -> "ok"
let
  pkgs = import <nixpkgs> { };
  kif = import ../../lib/kif.nix { };
  text = builtins.readFile;
  pins = import ../../pins.nix;

  crafted = kif.parse ''
    (instance part TransitiveRelation)
    (instance part BinaryPredicate)
    (domain part 1 Object)
    (domain part 2 Object)
    (instance greaterThan TransitiveRelation)
    (instance greaterThan BinaryPredicate)
    (inverse greaterThan lessThan)
    (instance lessThan BinaryPredicate)
    (instance symmetric SymmetricRelation)
    (instance symmetric BinaryPredicate)
    (instance reflexy ReflexiveRelation)
    (instance reflexy BinaryPredicate)
    (domain reflexy 1 Object)
    (domain reflexy 2 Object)
    (instance bareReflexy ReflexiveRelation)
    (instance bareReflexy BinaryPredicate)
    (instance piece BinaryPredicate)
    (subrelation piece part)
    (subAttribute Gone Broken)
    (instance ternaryRel TernaryPredicate)
    (instance ternaryRel TransitiveRelation)
    (instance mysteryRel TransitiveRelation)
    (instance duo SymmetricRelation)
    (instance duo SymmetricRelation)
  '';
  s = import ../../reasoner/synthesize.nix { forms = crafted; };
  ruleTexts = s.diagnostics.rules;
  # With FactMeta, rules include meta; check for key substrings instead of exact match
  hasAll = tokens: builtins.any (rt: builtins.all (t: pkgs.lib.hasInfix t rt) tokens) ruleTexts;

  ontology = import ../../sumo.nix { forms = crafted; };
  facts = kif.parse ''
    (part a b)
    (part b c)
  '';
  e = import ../../datalog.nix { inherit ontology facts; rules = s.rules; };

  pinned = kif.parse (text pins.merge);
  sp = import ../../reasoner/synthesize.nix { forms = pinned; };

  check = what: ok: if ok then true else throw "failed: ${what}";
  allRejectionsHaveReasons = builtins.all (r: r ? reason && r.reason != "") sp.rejected;
  allCraftedHaveReasons = builtins.all (r: r ? reason && r.reason != "") s.rejected;
in
if builtins.all (x: x) [
  # --- crafted declarations ------------------------------------------------
  (check "transitive declaration synthesizes a transitive rule"
    (hasAll [ "=>" "and" "part" "?a" "?b" "?c" ]))
  (check "transitive rule derives the closure from two facts" (e.holds [ "part" "a" "c" ]))
  (check "symmetric declaration synthesizes the flip rule"
    (hasAll [ "=>" "symmetric" "?a" "?b" ]))
  (check "reflexive declaration with a position-1 domain synthesizes identity"
    (hasAll [ "=>" "instance" "?x" "Object" "reflexy" ]))
  (check "reflexive declaration without a domain is rejected with a reason"
    (builtins.elem "reflexive-no-domain" (map (r: r.reason) s.rejected)))
  (check "subrelation synthesizes the inclusion rule with arity from the predicate class"
    (hasAll [ "=>" "piece" "?v0" "?v1" "part" ]))
  (check "subAttribute synthesizes the unary inclusion rule"
    (hasAll [ "=>" "Gone" "?x" "Broken" ]))
  (check "inverse declaration synthesizes both directions"
    (hasAll [ "=>" "greaterThan" "?a" "?b" "lessThan" ] && hasAll [ "=>" "lessThan" "?a" "?b" "greaterThan" ]))
  (check "a transitive ternary relation is rejected with a reason"
    (builtins.elem "non-binary-transitive" (map (r: r.reason) s.rejected)))
  (check "an unknown-arity transitive relation is rejected with a reason"
    (builtins.elem "unknown-arity" (map (r: r.reason) s.rejected)))
  (check "redundant synthesis is reported, not silently double-fired" (s.diagnostics.redundant >= 1))
  (check "every rejection carries a reason" allCraftedHaveReasons)
  # --- pinned corpus --------------------------------------------------------
  (check "the corpus yields more than 100 synthesized rules" (sp.diagnostics.synthesized > 100))
  (check "every corpus rejection carries a reason" allRejectionsHaveReasons)
] then "ok" else "failed"
