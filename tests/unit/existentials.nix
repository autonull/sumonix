# T2.3 — Bounded Existentials: finite-domain Skolem terms (depth ≤ 1)
# Usage: ./nix-eval.sh --expr 'import ./tests/unit/existentials.nix'  -> "ok"
let
  kif = import ../../lib/kif.nix { };
  datalog = import ../../datalog.nix;
  existential = import ../../reasoner/existential.nix { };

  # Test: there exists a dependency chain of length ≤ 2 from a to c
  facts = kif.parse ''
    (dependsOn a b)
    (dependsOn b c)
  '';

  # Rule: (=> (and (dependsOn ?x ?y) (dependsOn ?y ?z)) (chain2 ?x ?z))
  rules = [
    [ "=>" [ "and" [ "dependsOn" "?x" "?y" ] [ "dependsOn" "?y" "?z" ] ] [ "chain2" "?x" "?z" ] ]
  ];

  # Goal: chain2 a c
  goal = [ "chain2" "a" "c" ];

  # Test with existential module
  existentialFn = import ../../reasoner/existential.nix;
  result = existentialFn { inherit facts rules; };

  check = what: ok: if ok then true else throw "failed: ${what}";
in
if builtins.all (x: x) [
  (check "base case derives chain2 a c" (result.holds "chain2" [ "a" "c" ]))
] then "ok" else "failed"