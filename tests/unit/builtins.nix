# T2.6 — Builtins: test greaterThan, lessThan, notEqual, subsetOf, supersetOf
# Usage: nix --extra-experimental-features nix-command eval --impure --expr 'import ./tests/unit/builtins.nix'
let
  kif = import ../../lib/kif.nix { };
  facts = kif.parse ''
    (instance a NIXPackage)
    (instance b NIXPackage)
    (hasVersion a "1.2.3")
    (hasVersion b "2.0.0")
    (hasIntVal a 10)
    (hasIntVal b 5)
    (hasList a [ "x" "y" ])
    (hasList b [ "x" "y" "z" ])
  '';
  ontology = import ../../sumo.nix { forms = [ ]; };
  rules = [ ];
  bi = import ../../reasoner/builtins.nix { };
  e = import ../../datalog.nix { ontology = ontology; rules = rules; facts = facts; builtinRegistry = bi; };

  check = what: ok: if ok then true else throw "failed: ${what}";
in
if builtins.all (x: x) [
  # greaterThan with versions
  (check "greaterThan version" (e.ask [ "greaterThan" "2.0.0" "1.2.3" ] != [ ]))
  (check "greaterThan version false" (e.ask [ "greaterThan" "1.2.3" "2.0.0" ] == [ ]))
  # greaterThan with integers
  (check "greaterThan int" (e.ask [ "greaterThan" "10" "5" ] != [ ]))
  (check "greaterThan int false" (e.ask [ "greaterThan" "5" "10" ] == [ ]))
  # lessThan
  (check "lessThan version" (e.ask [ "lessThan" "1.2.3" "2.0.0" ] != [ ]))
  (check "lessThan int" (e.ask [ "lessThan" "5" "10" ] != [ ]))
  # notEqual
  (check "notEqual" (e.ask [ "notEqual" "a" "b" ] != [ ]))
  (check "notEqual false" (e.ask [ "notEqual" "a" "a" ] == [ ]))
  # subsetOf
  (check "subsetOf" (e.ask [ "subsetOf" "[ \"x\" \"y\" ]" "[ \"x\" \"y\" \"z\" ]" ] != [ ]))
  (check "subsetOf false" (e.ask [ "subsetOf" "[ \"x\" \"y\" \"z\" ]" "[ \"x\" \"y\" ]" ] == [ ]))
  # supersetOf
  (check "supersetOf" (e.ask [ "supersetOf" "[ \"x\" \"y\" \"z\" ]" "[ \"x\" \"y\" ]" ] != [ ]))
  (check "supersetOf false" (e.ask [ "supersetOf" "[ \"x\" \"y\" ]" "[ \"x\" \"y\" \"z\" ]" ] == [ ]))
] then "ok" else "failed"