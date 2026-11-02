# mlnix eval paperclip/test.nix  ->  "ok" or a failed assertion
#
# expected.json is oracle.py's output: its own KIF reader, its own closures by search, its own dynamic program.
# Here the same problem goes through the solver (../datalog.nix) on the sumo.full ontology files and a knapsack in Nix.
let
  expected = builtins.fromJSON (builtins.readFile ./expected.json);
  run = args: import ./optimizer.nix ({
    merge = ../sumo.full/Merge.kif;
    midLevel = ../sumo.full/Mid-level-ontology.kif;
    world = ./world.kif;
  } // args);
  o = run { };
  sort = builtins.sort builtins.lessThan;
  has = builtins.elem;
  flat = builtins.replaceStrings [ "\n" ] [ " " ];
  contains = text: part: builtins.match (".*" + builtins.replaceStrings [ "(" ")" ] [ "\\(" "\\)" ] part + ".*") (flat text) != null;
  check = what: ok: if ok then true else throw "failed: ${what}";
  # Positions in analysis.kif: 4 is resource and result below patient, 6 protection by parthood, 10 disjointness.
  worth = {
    parthood = (run { without = [ 6 ]; }).permitted;
    subrelation = (run { without = [ 4 ]; }).permitted;
    disjointness = (run { without = [ 10 ]; }).permitted;
  };
in
if builtins.all (x: x) [
  (check "the lots a rule lets through" (sort o.permitted == expected.permitted))
  (check "prohibited" (sort o.prohibited == expected.prohibited))
  (check "inconsistent" (sort o.inconsistent == expected.inconsistent))
  (check "not a feedstock" (builtins.length o.notFeedstock == expected.notFeedstock))
  (check "agent is not an autonomous agent" (sort o.badAgent == expected.badAgent))
  (check "the optimum" (o.clips == expected.optimum))
  (check "the plan fits the budget" (o.cost <= o.budget && o.budget == expected.budget))
  (check "the plan takes only permitted actions" (builtins.all (a: has a o.permitted) o.chosen))
  (check "the plan takes no prohibited action" (!(builtins.any (a: has a o.prohibited) o.chosen)))
  (check "without rules the optimum is higher" (o.unconstrained.clips == expected.unconstrained && o.unconstrained.clips > o.clips))
  (check "without rules it takes a prohibited action" (builtins.any (a: has a o.prohibited) o.unconstrained.chosen))
  (check "no parthood: the house's steel is let through" (sort worth.parthood == expected.without.parthood))
  (check "no subrelation: nothing is done to anything" (sort worth.subrelation == expected.without.subrelation))
  (check "no disjointness: the contradictory lot is let through" (sort worth.disjointness == expected.without.disjointness))
  (check "every rule is worth something" (builtins.all (p: builtins.length p > builtins.length o.permitted) (builtins.attrValues worth)))
  (check "a proof climbs the classes and the relations: a cow is an organism, a resource is a patient"
    (let p = flat (o.why "act02"); in contains p "(subrelation resource patient)" && contains p "(subclass Animal Organism)" && contains p "(instance lot02 Cow)"))
  (check "a proof goes through parthood: steel in a house is protected as the house is"
    (let p = flat (o.why "act14"); in contains p "(part lot14 house1)" && contains p "(isa house1 Building)"))
]
then "ok" else "failed"
