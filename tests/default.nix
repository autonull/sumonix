# mlnix eval tests/default.nix      ->  "ok" or a failed assertion
#
# The expected numbers come from outside this repository: a separate Python reader of the same pinned Merge.kif
# (paren-depth scan, transitive closure by recursion) printed them. Change them only when the pin changes.
let
  kif = import ../kif.nix;
  pins = import ../pins.nix;
  forms = kif.parse (builtins.readFile pins.merge);
  o = import ../sumo.nix { inherit forms; };
  n = builtins.length;
  check = what: ok: if ok then true else throw "failed: ${what}";
in
if builtins.all (x: x) [
  (check "kif.parse: top-level forms" (n forms == 5505))
  (check "kif.parse: a small text" (kif.parse "(a (b \"c d\") ?x) ; gone\n(e)" == [ [ "a" [ "b" "\"c d\"" ] "?x" ] [ "e" ] ]))
  (check "classes with a parent" (n (builtins.attrNames o.parents) == 712))
  (check "all classes" (n (builtins.attrNames o.classes) == 714))
  (check "asserted instances" (n (builtins.attrNames o.classOf) > 0 && o.classOf.part == [ "SpatialRelation" "PartialOrderingRelation" "BinaryPredicate" ]))
  (check "ancestors of Human" (o.ancestors.Human == [
    "Animal" "AutonomousAgent" "CognitiveAgent" "CorpuscularObject" "Entity" "Hominid" "Mammal" "Object" "OrganicObject"
    "OrganicThing" "Organism" "Physical" "Primate" "SelfConnectedObject" "SentientAgent" "Vertebrate" "WarmBloodedVertebrate"
  ]))
  (check "Human is an Entity" (o.isSubclass "Human" "Entity"))
  (check "Entity is not a Human" (!(o.isSubclass "Entity" "Human")))
  (check "a class is a lambda" (builtins.isFunction o.classes.Human && o.classes.Entity "part" && !(o.classes.Human "part")))
  (check "domain of part" (o.domains.part == { "1" = "Object"; "2" = "Object"; }))
  (check "well typed" (o.wellTyped "rangeSubclass" [ "AssignmentFn" ]))
  (check "ill typed" (!(o.wellTyped "part" [ "part" "part" ])))
] then "ok" else "failed"
