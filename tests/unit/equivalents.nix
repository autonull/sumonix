# Phase 1 — Ontology equivalence subsumption (G3). From-scratch ontology with equivalent class pairs.
# Usage: nix --extra-experimental-features nix-command eval --impure --expr 'import ./tests/unit/equivalents.nix'  -> "ok"
let
  kif = import ../../lib/kif.nix { };
  forms = kif.parse ''
    (subclass Vehicle Entity)
    (subclass Car Vehicle)
    (subclass TinyCar Car)
    (equivalent Car Coupe)
    (equivalent CompactCar TinyCar)
    (instance myCar Coupe)
    (instance myTruck TinyCar)
  '';
  o = import ../../sumo.nix { inherit forms; };
  check = what: ok: if ok then true else throw "failed: ${what}";
in
if builtins.all (x: x) [
  (check "equivalence representative is the least name" (o.rep "TinyCar" == "CompactCar" && o.rep "CompactCar" == "CompactCar"))
  (check "an equivalent class stands in for its parent" (o.isSubclass "Coupe" "Vehicle"))
  (check "an equivalent class stands in for a composed chain" (o.isSubclass "Coupe" "Car" && o.isSubclass "Car" "Coupe"))
  (check "equivalence chain reaches Entity through the chain" (o.isSubclass "CompactCar" "Vehicle"))
  (check "no equivalence crosses to an unrelated class" (!(o.isSubclass "Coupe" "TinyCar")))
  (check "isInstance walks the representative both ways" (o.isInstance "myCar" "Coupe" && o.isInstance "myCar" "Car" && o.isInstance "myCar" "Vehicle"))
  (check "isInstance works through the chain" (o.isInstance "myTruck" "TinyCar" && o.isInstance "myTruck" "CompactCar" && o.isInstance "myTruck" "Vehicle"))
  (check "isInstance is not universal" (!(o.isInstance "myCar" "CompactCar")))
  (check "ancestors of a class contain the parents of its equivalent"
    (builtins.elem "Vehicle" o.ancestors.Car && builtins.elem "Vehicle" o.ancestors.TinyCar))
  (check "a class keeps itself" (o.isSubclass "Coupe" "Coupe"))
  (check "isSubclass refuses non-string classes without throwing" (!(o.isSubclass [ "x" ] "Entity") && !(o.isSubclass "Entity" [ "x" ])))
] then "ok" else "failed"
