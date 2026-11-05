# T3.1 — Soft Rules / MaxSAT: rule weights + violation minimization
# Usage: ./nix-eval.sh --expr 'import ./tests/unit/soft-rules.nix'  -> "ok"
let
  kif = import ../../kif.nix;
  datalog = import ../../datalog.nix;
  softFn = import ../../policy/soft-rules.nix;

  # Test 1: Goal derivable only via low-weight rule
  facts1 = kif.parse ''
    (pkg a)
    (dependsOn a b)
  '';

  rules1 = [
    { id = "risky-vuln"; weight = 10; rule = [ "=>" [ "and" [ "pkg" "?x" ] [ "dependsOn" "?x" "?y" ] [ "vuln" "?y" ] ] [ "risky" "?x" ] ]; }
    { id = "risky-any"; weight = 1; rule = [ "=>" [ "and" [ "pkg" "?x" ] [ "dependsOn" "?x" "?y" ] ] [ "risky" "?x" ] ]; }
  ];

  goal1 = [ "risky" "a" ];

  result1 = softFn { facts = facts1; rules = rules1; goal = goal1; };

  # Test 2: Goal derivable via both rules (need to drop both)
  facts2 = kif.parse ''
    (pkg a)
    (dependsOn a b)
    (vuln b)
  '';

  result2 = softFn { facts = facts2; rules = rules1; goal = goal1; };

  check = what: ok: if ok then true else throw "failed: ${what}";
in
if builtins.all (x: x) [
  (check "Test 1: base case derives goal" (result1.baseDerived))
  (check "Test 1: min weight to make goal underivable is 1 (drop risky-any)" (result1.minWeight == 1))
  (check "Test 1: best set drops risky-any" (builtins.elem "risky-any" (builtins.head result1.bestSets)))
  (check "Test 2: base case derives goal" (result2.baseDerived))
  (check "Test 2: min weight to make goal underivable is 11 (drop both)" (result2.minWeight == 11))
] then "ok" else "failed"