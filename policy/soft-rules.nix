# T3.1 — Soft Rules / MaxSAT: rule weights + violation minimization.
# Reuses relaxation machinery from relax.nix.
# Usage: (import ./soft-rules.nix { ontology; facts; rules; goal; })
#   rules: list of { id; weight; rule }
#   Returns: { bestSet; minWeight; allOptions; }
{ ontology ? null, facts ? [ ], rules ? [ ], goal ? [ ] }:
let
  # Shared KIF helpers (type-aware show for int/string/list)
  kif = import ../lib/kif.nix { };
  inherit (kif) show;
  datalog = import ../datalog.nix;

  # Extract weights and rule ids
  ruleIds = builtins.map (r: r.id) rules;
  ruleWeights = builtins.map (r: r.weight) rules;
  ruleList = builtins.map (r: r.rule) rules;

  # Total weight of all rules
  totalWeight = builtins.foldl' (a: w: a + w) 0 ruleWeights;

  # Named rules for the relaxation engine
  namedRules = builtins.genList
    (i:
      let r = builtins.elemAt ruleList i; c = builtins.elemAt r 2;
      in { id = "${if builtins.isList c then builtins.head c else "?"}#${toString (i + 1)}"; rule = r; weight = builtins.elemAt ruleWeights i; ruleId = builtins.elemAt ruleIds i; })
    (builtins.length ruleList);

  # Run engine with a subset of rules (by keeping only some rule indices)
  run = keepIndices:
    let
      ruleIdsToKeep = builtins.map (i: (builtins.elemAt namedRules i).ruleId) keepIndices;
      kept = builtins.filter (e: builtins.elem e.ruleId ruleIdsToKeep) namedRules;
    in datalog { inherit ontology; facts = facts; rules = builtins.map (e: e.rule) kept; };

  # Check if goal is derivable with a set of rule indices
  goalDerivable = keepIndices:
    (run keepIndices).holds goal;

  # Weight of a set of rule indices
  weightOf = indices:
    builtins.foldl' (a: i: a + (builtins.elemAt namedRules i).weight) 0 indices;

  # All rule indices
  allIndices = builtins.genList (i: i) (builtins.length namedRules);

  # Check base case - all rules
  baseDerived = goalDerivable allIndices;
  baseWeight = weightOf allIndices;

  # Find all subsets where goal is NOT derivable (violations resolved)
  # We want the minimum weight subset that makes goal underivable
  # Actually, we want to find minimal weight rules to DROP to make goal underivable
  # This is equivalent to finding maximal weight subset to KEEP where goal is underivable
  # But simpler: find minimal weight set of rules to DROP such that goal is underivable

  # Generate all subsets of rules to drop (powerset of indices)
  powerset = xs:
    if xs == [ ] then [ [ ] ]
    else
      let
        rest = powerset (builtins.tail xs);
        head = builtins.head xs;
      in
      rest ++ (builtins.map (ys: [ head ] ++ ys) rest);

  allSubsets = powerset allIndices;

  # Find subsets where goal is underivable
  violatingSubsets = builtins.filter (dropIndices:
    let keepIndices = builtins.filter (i: !(builtins.elem i dropIndices)) allIndices;
    in !goalDerivable keepIndices
  ) allSubsets;

  # Find minimum weight among violating subsets
  minWeight = if violatingSubsets == [ ] then -1 else
    let
      initMin = -1;
      foldFn = min: dropIndices:
        let w = weightOf dropIndices;
        in if min == -1 || w < min then w else min;
    in builtins.foldl' foldFn initMin violatingSubsets;

  # Best sets (minimum weight)
  bestSetsRaw = builtins.filter (dropIndices: weightOf dropIndices == minWeight) violatingSubsets;

  # All options sorted by weight
  allOptions = builtins.sort (a: b: weightOf a < weightOf b)
    (builtins.map (dropIndices: {
      drop = dropIndices;
      keep = builtins.filter (i: !(builtins.elem i dropIndices)) allIndices;
      weight = weightOf dropIndices;
      derived = goalDerivable (builtins.filter (i: !(builtins.elem i dropIndices)) allIndices);
    }) violatingSubsets);

in
{
  baseDerived = baseDerived;
  baseWeight = baseWeight;
  minWeight = minWeight;
  bestSets = builtins.map (dropIndices: builtins.map (i: (builtins.elemAt namedRules i).ruleId) dropIndices) bestSetsRaw;
  allOptions = builtins.map (opt: opt // { drop = builtins.map (i: (builtins.elemAt namedRules i).ruleId) opt.drop; }) allOptions;
  diagnostics = { totalRules = builtins.length rules; totalWeight = totalWeight; subsetsChecked = builtins.length allSubsets; };
}