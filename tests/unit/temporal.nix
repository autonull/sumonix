# T3.3 — Temporal/Modal: dedicated module for temporal reasoning
# Usage: ./nix-eval.sh --expr 'import ./tests/unit/temporal.nix'  -> "ok"
let
  kif = import ../../kif.nix;
  temporal = import ../../reasoner/temporal.nix { };

  # Test: temporal reasoning with before/during relations
  facts = kif.parse ''
    (before t1 t2)
    (before t2 t3)
    (during e1 t2)
  '';

  # Rules for temporal reasoning
  rules = [
    # before is transitive
    [ "=>" [ "and" [ "before" "?x" "?y" ] [ "before" "?y" "?z" ] ] [ "before" "?x" "?z" ] ]
    # during is transitive
    [ "=>" [ "and" [ "during" "?x" "?y" ] [ "during" "?y" "?z" ] ] [ "during" "?x" "?z" ] ]
    # event during an interval that is before another interval
    [ "=>" [ "and" [ "during" "?e" "?t1" ] [ "before" "?t1" "?t2" ] ] [ "before" "?e" "?t2" ] ]
  ];

  # Goals to test
  goal1 = [ "before" "t1" "t3" ];  # transitive before
  goal2 = [ "before" "e1" "t3" ];  # during + before

  temporalFn = import ../../reasoner/temporal.nix;
  result = temporalFn { inherit facts rules; };

  check = what: ok: if ok then true else throw "failed: ${what}";
in
if builtins.all (x: x) [
  (check "before is transitive: before t1 t3" (result.holds "before" [ "t1" "t3" ]))
  (check "during + before: before e1 t3" (result.holds "before" [ "e1" "t3" ]))
  (check "temporal module has temporal diagnostics" (result.diagnostics ? temporalReasoning))
] then "ok" else "failed"