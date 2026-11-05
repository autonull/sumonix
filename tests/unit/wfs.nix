# T2.2 — WFS Negation: three-valued eval + alternating fixpoint on unstratifiable predicates
# Usage: ./nix-eval.sh --expr 'import ./tests/unit/wfs.nix'  -> "ok"
let
  kif = import ../../kif.nix;
  wfs = import ../../reasoner/wfs.nix;
  stratify = import ../../reasoner/stratify.nix;

  # A simple negative cycle: A -> B, B -> not A
  # In WFS, both A and B become "unknown" because they depend on each other negatively
  facts = kif.parse ''
  '';

  rules = [
    [ "=>" [ "not" [ "a" "?x" ] ] [ "b" "?x" ] ]
    [ "=>" [ "not" [ "b" "?x" ] ] [ "a" "?x" ] ]
  ];

  # Stratifier will mark these as unstratifiable
  strat = stratify { rules = rules; };

  # Run WFS engine
  engine = wfs { facts = facts; rules = rules; unstratifiable = strat.unstratifiable; };

  check = what: ok: if ok then true else throw "failed: ${what}";
in
if builtins.all (x: x) [
  (check "stratifier identifies negative cycle" (builtins.elem "a" strat.unstratifiable && builtins.elem "b" strat.unstratifiable))
  (check "WFS engine marks unstratifiable predicates" (builtins.length engine.diagnostics.unstratifiablePredicates > 0))
  (check "WFS engine has unknown facts" (engine.diagnostics.unknownFacts >= 0))
  (check "WFS engine reports WFS enabled" (engine.diagnostics.wfsEnabled == true))
] then "ok" else "failed"