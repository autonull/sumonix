# Stratifier: rejects rules that sit on a cycle through a negative edge, assigns strata to the rest.
#
#   stratify { rules; manualAdmission ? [ ]; }
#     -> { strata; rejections; unstratifiable; admittedUnstratified; predicates; diagnostics; }
#
# rules are (=> antecedent consequent) forms in evaluation order; a rule keeps the id
# datalog.nix derives for it ("<head>#<index+1>"). Rules whose consequent is not an atom
# (a variable head, or a structural head) are skipped from the graph and listed under
# `skipped` — they carry no derivation weight for stratification.
#
# A predicate is unstratifiable when a cycle through at least one negative edge runs
# through it. Every rule deriving an unstratifiable predicate is rejected with reason
# `unstratified-negation` — unless the predicate is in manualAdmission, in which case
# it is kept and logged under admittedUnstratified (and diagnostics.manualAdmission).
#
# Strata: 0 for predicates derived without negated premises; otherwise
# 1 + max stratum of a negated premise, resp. max of positive premises. Positive
# recursion shares a stratum. Iteration is bounded; an admitted negative cycle that
# cannot be ordered is assigned its common stratum and logged, never diverges.
{ rules ? [ ], manualAdmission ? [ ] }:
let
  inherit (builtins) all any attrNames concatMap elem elemAt filter foldl' genList head isList isString length listToAttrs map sort tail;

  # Shared KIF helpers (engine's isVar is ? only; stratify keeps its own isVar for ?/@)
  kif = import ../lib/kif.nix { };
  inherit (kif) show headOf flatten subforms ground count isKifOp;
  # stratify's isVar is ? or @, plus members starting @ are not vars — keep local
  isVar = s: isString s && (builtins.substring 0 1 s == "?" || builtins.substring 0 1 s == "@");
  # stratify's unique uses count (keeps non-strings) — keep local
  unique = xs: attrNames (count xs);
  isStructural = h: elem h [ "and" "or" "not" "exists" "forall" "<=>" "=>" ];
  # Atoms of an antecedent with their polarity: `not` flips it. (not (not P) = P.)
  bodyWalk = neg: f:
    if !(isList f) then [ ]
    else
      let h = headOf f; in
      if h == "not" then concatMap (bodyWalk (!neg)) (tail f)
      else if isStructural h then concatMap (bodyWalk neg) (tail f)
      else if h == "" || isVar h then [ ]
      else [ { atom = f; inherit neg; } ];
  atomsOf = ant: bodyWalk false ant;
  posAtoms = ant: map (x: x.atom) (filter (x: !x.neg) (atomsOf ant));
  negAtoms = ant: map (x: x.atom) (filter (x: x.neg) (atomsOf ant));

  named = genList
    (i:
      let r = elemAt rules i; c = elemAt r 2; in
      { id = "${headOf c}#${toString (i + 1)}"; antecedent = elemAt r 1; consequent = c; consHead = headOf c;
        skipped = isVar (headOf c) || isStructural (headOf c) || headOf c == ""; })
    (length rules);
  active = filter (r: !r.skipped) named;

  edges = concatMap (r:
    (map (a: { from = r.consHead; to = headOf a; neg = false; rule = r.id; }) (posAtoms r.antecedent))
    ++ (map (a: { from = r.consHead; to = headOf a; neg = true; rule = r.id; }) (negAtoms r.antecedent))) active;
  preds = unique (concatMap (e: [ e.from e.to ]) edges);

  edgeAll = listToAttrs (map (p: { name = p; value = unique (map (e: e.to) (filter (e: e.from == p) edges)); }) preds);
  edgeRev = foldl' (m: e: m // { ${e.to} = (m.${e.to} or [ ]) ++ [ e.from ]; })
    (listToAttrs (map (q: { name = q; value = [ ]; }) preds)) edges;
  closureVia = em: p: map (e: e.key) (builtins.genericClosure { startSet = [ { key = p; } ]; operator = x: map (t: { key = t; }) (em.${x.key} or [ ]); });
  fwd = listToAttrs (map (p: { name = p; value = closureVia edgeAll p; }) preds);
  bwd = listToAttrs (map (p: { name = p; value = closureVia edgeRev p; }) preds);

  # Predicates on a cycle through at least one negative edge.
  negEdges = filter (e: e.neg) edges;
  cycleNodes = unique (concatMap (e:
    filter (p: (elem p (fwd.${e.to} or [ ]) || p == e.to) && (elem p (bwd.${e.from} or [ ]) || p == e.from)) preds) negEdges);
  unstratifiable = sort builtins.lessThan (filter (p: !(elem p manualAdmission)) cycleNodes);
  admittedUnstratified = sort builtins.lessThan (filter (p: elem p manualAdmission) cycleNodes);
  rejectedSet = listToAttrs (map (p: { name = p; value = true; }) unstratifiable);

  # Strata over the admitted subprogram: rejected heads and their rules leave the graph;
  # negative edges originating a rejected predicate leave with it. Fixpoint, bounded.
  admitted = filter (r: !(rejectedSet ? ${r.consHead})) active;
  stratEdges = concatMap (r:
    (map (a: { from = r.consHead; to = headOf a; neg = false; }) (posAtoms r.antecedent))
    ++ (map (a: { from = r.consHead; to = headOf a; neg = true; }) (negAtoms r.antecedent))) admitted;
  predSet = unique (unique (concatMap (e: [ e.from e.to ]) stratEdges) ++ preds);
  zeroMap = listToAttrs (map (p: { name = p; value = 0; }) predSet);
  step = s: listToAttrs (map (p:
    let
      posDeps = unique (map (e: e.to) (filter (e: e.from == p && !e.neg) stratEdges));
      negDeps = unique (map (e: e.to) (filter (e: e.from == p && e.neg) stratEdges));
      base = if posDeps == [ ] && negDeps == [ ] then 0
        else builtins.foldl' (a: b: if a > b then a else b) 0
          ((map (d: s.${d} or 0) posDeps) ++ (map (d: (s.${d} or 0) + 1) negDeps));
    in { name = p; value = base; }) predSet);
  iterate = n: x: if n == 0 then x else
    let y = step x; in
    if y == x then y else iterate (n - 1) y;
  stratumMap = iterate (length predSet + 1) zeroMap;
  stable = step stratumMap == stratumMap;

  strata = sort (a: b: a.stratum < b.stratum || (a.stratum == b.stratum && a.predicate < b.predicate))
    (map (p: { predicate = p; stratum = stratumMap.${p} or 0; }) predSet);

  # Rejections: every admitted-graph-excluded rule, with its reason; and skipped rules.
  ruleRejections = concatMap (r:
    if rejectedSet ? ${r.consHead}
    then [ { rule = r.id; predicate = r.consHead; reason = "unstratified-negation"; } ]
    else [ ]) active;
  skippedIds = map (r: { rule = r.id; reason = if r.skipped then "non-atom-consequent" else "ok"; })
    (filter (r: r.skipped) named);

in
{
  inherit strata;
  unstratifiable = sort builtins.lessThan unstratifiable;
  admittedUnstratified = admittedUnstratified;
  predicates = sort builtins.lessThan preds;
  skipped = skippedIds;
  rejections = ruleRejections;
  diagnostics = {
    strata = strata;
    predicates = length preds;
    strataStable = stable;
    rulesRejected = ruleRejections;
    admittedUnstratified = admittedUnstratified;
    manualAdmission = admittedUnstratified; # admissions that actually discharged a cycle, always logged
    skipped = skippedIds;
  };
}
