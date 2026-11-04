# Phase 5 — Relaxation menu. The goal does not hold with the candidate set in
# force: enumerate the single toggles whose removal makes it hold, each with a
# proof sketch; when no single toggle flips, list size-2 flips; for a holding
# goal, list its proof leaves that are individually load-bearing.
#
#   menu { goal; facts; rules; ontology ? null; passWhen ? "underivable"; candidates ? [ ] }
#     -> { basePass; menu; minFlipsGroups; supports; results; diagnostics; }
#
# A candidate is { name; dropFacts ? [ ]; dropRules ? [ ]; note ? "" }.
# dropFacts: facts to remove from the universe; dropRules: engine rule ids
# ("head#index", as printed by diagnostics) to remove. `menu` entries carry the
# proof in the flipped state (the why-tree when the goal is derivable, or
# "goal underivable" as the explanation of the new verdict).
{ ontology ? null, facts ? [ ], rules ? [ ], goal ? [ ], passWhen ? "underivable", candidates ? [ ] }:
let
  show = s: if builtins.isString s then s else "(" + builtins.concatStringsSep " " (map show s) + ")";
  namedRules = builtins.genList
    (i:
      let r = builtins.elemAt rules i; c = builtins.elemAt r 2;
      in { id = "${if builtins.isList c then builtins.head c else "?"}#${toString (i + 1)}"; rule = r; })
    (builtins.length rules);
  polarity = derived: if passWhen == "derivable" then derived else !derived;

  run = { facts' ? facts, dropRuleIds ? [ ] }:
    let kept = builtins.filter (e: !(builtins.elem e.id dropRuleIds)) namedRules;
    in import ../datalog.nix { inherit ontology; facts = facts'; rules = map (e: e.rule) kept; };

  baseEngine = run { };
  baseDerived = baseEngine.holds goal;
  basePass = polarity baseDerived;

  tryOne = c:
    let
      dropFactTexts = builtins.map show (c.dropFacts or [ ]);
      remainingFacts = builtins.filter (f: !(builtins.elem (show f) dropFactTexts)) facts;
      e = run { facts' = remainingFacts; dropRuleIds = c.dropRules or [ ]; };
      derived = e.holds goal;
      pass = polarity derived;
      flip = pass != basePass;
      proof = if derived then e.explain goal else "goal underivable";
    in
    { inherit (c) name; drop = { facts = dropFactTexts; rules = c.dropRules or [ ]; };
      inherit pass derived flip proof;
      note = c.note or ""; };

  results = builtins.map tryOne candidates;
  menu = builtins.filter (r: r.flip) results;

  idxs = builtins.genList (i: i) (builtins.length candidates);
  pairIdxs = builtins.concatMap
    (i: builtins.genList (k: [ i (i + 1 + k) ]) ((builtins.length candidates) - i - 1)) idxs;
  tryPair = p:
    let
      cs = builtins.map (i: builtins.elemAt candidates i) p;
      dropFactTexts = builtins.concatMap (c: builtins.map show (c.dropFacts or [ ])) cs;
      remainingFacts = builtins.filter (f: !(builtins.elem (show f) dropFactTexts)) facts;
      dropRuleIds = builtins.concatMap (c: c.dropRules or [ ]) cs;
      e = run { facts' = remainingFacts; dropRuleIds = dropRuleIds; };
      derived = e.holds goal;
      pass = polarity derived;
    in
    if pass == basePass then null else builtins.map (c: c.name) cs;
  minFlipsGroups =
    if menu != [ ] || pairIdxs == [ ] then [ ]
    else builtins.filter (x: x != null) (builtins.map tryPair pairIdxs);

  # The leaves of the goal's proof, when it holds: which single fact removals flip it.
  proofLeaves = t:
    if t ? asserted then [ (t.fact or "?") ]
    else builtins.concatMap proofLeaves (t.from or [ ]);
  leaves = if baseDerived then proofLeaves (baseEngine.why goal) else [ ];
  supports =
    if !baseDerived || passWhen != "derivable" then [ ]
    else
      builtins.map (factText:
        let
          remainingFacts = builtins.filter (f: show f != factText) facts;
          e = run { facts' = remainingFacts; };
          derived = e.holds goal;
        in { fact = factText; flip = derived != baseDerived; })
        leaves;

in
{
  inherit basePass baseDerived results menu minFlipsGroups supports;
  diagnostics = {
    basePass = basePass;
    baseDerived = baseDerived;
    candidates = builtins.length candidates;
    flips = builtins.length menu;
    passWhen = passWhen;
  };
}
