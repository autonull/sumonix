# Phase 0 — Measure & Verdict. Parses Merge.kif and prints a histogram of its forms as JSON.
#
# Usage:
#   nix --extra-experimental-features nix-command eval --impure --raw \
#     --expr '(import ./tests/ingest-report.nix).json' > tests/ingest-report.json
#   nix --extra-experimental-features nix-command eval --impure --json \
#     --expr '(import ./tests/ingest-report.nix).summary'
#
# The verdict gate (recorded in TODO2.b.md): Horn >= 300 & rejects enumerable => ingestion allowed;
# Horn < 100 => features.hornIngest = false, everything else proceeds.
let
  kif = import ../kif.nix;
  pins = import ../pins.nix;
  forms = kif.parse (builtins.readFile pins.merge);

  inherit (builtins) all any attrNames concatMap concatStringsSep elem filter foldl' head isList isString length listToAttrs map sort tail;

  headOf = f: if isList f && f != [ ] then head f else "";
  isVar = s: isString s && (builtins.substring 0 1 s == "?" || builtins.substring 0 1 s == "@");
  count = xs: foldl' (m: x: m // { ${x} = (m.${x} or 0) + 1; }) { } xs;
  top = name: filter (f: isList f && f != [ ] && head f == name) forms;
  unique = xs: attrNames (count xs);
  flatten = f: if isList f then concatMap flatten f else [ f ];
  subforms = f: if isList f then [ f ] ++ concatMap subforms (tail f) else [ ];
  varsOf = f: filter isVar (flatten f);
  hasHead = name: f: any (s: isList s && headOf s == name) (subforms f);

  histogram = count (map headOf forms);

  ruleForms = top "=>";
  iffForms = top "<=>";
  eqvForms = top "equivalent";
  declNamed = name: filter (f: any (s: s == name) (flatten f)) (top "instance");
  transitiveDecls = declNamed "TransitiveRelation";
  symmetricDecls = declNamed "SymmetricRelation";
  reflexiveDecls = declNamed "ReflexiveRelation";

  # A list that appears as an argument (not in head position) is a function symbol.
  argFunctionTerm = cons:
    let nested = concatMap (a: if isList a then [ a ] ++ subforms a else [ ]) (tail cons);
    in nested != [ ];

  structuralHead = h: elem h [ "not" "forall" "exists" "or" "xor" "and" "equal" "<=>" ];
  quantifiedVars = f:
    concatMap (s:
      if isList s && (headOf s == "exists" || headOf s == "forall") && length (s) >= 2 && isList (builtins.elemAt s 1)
      then filter isVar (flatten (builtins.elemAt s 1))
      else [ ]) (subforms f);

  classify = r:
    let
      ant = builtins.elemAt r 1;
      cons = builtins.elemAt r 2;
      consHead = headOf cons;
      bound = varsOf ant ++ quantifiedVars cons;
      unbound = filter (v: !(elem v bound)) (varsOf cons);
    in {
      inherit consHead ant cons;
      disjunctiveHead = consHead == "or" || consHead == "xor";
      negatedConsequent = consHead == "not";
      quantifiedConsequent = elem consHead [ "forall" "exists" ];
      predicateVariable = isVar consHead;
      nonAtomConsequent = structuralHead consHead && !(elem consHead [ "or" "xor" ]);
      functionConsequent = argFunctionTerm cons;
      unboundConsequentVar = unbound != [ ];
      hasNot = hasHead "not" ant;
      hasOr = hasHead "or" ant;
      hasExists = hasHead "exists" ant;
      hasIff = hasHead "<=>" ant;
    };

  classified = map classify ruleForms;
  isHorn = c:
    !c.disjunctiveHead && !c.negatedConsequent && !c.quantifiedConsequent
    && !c.predicateVariable && !c.functionConsequent && !c.unboundConsequentVar;
  hornCount = length (filter isHorn classified);

  # An (and A B ...) consequent splits into one Horn rule per conjunct.
  atomLike = antVars: c: isList c && c != [ ] && !(isVar (headOf c)) && !argFunctionTerm c
    && all (v: elem v antVars) (varsOf c);
  andConjuncts = r:
    let antVars = varsOf (builtins.elemAt r 1); in
    if headOf (builtins.elemAt r 2) == "and" then builtins.tail (builtins.elemAt r 2) else [ ];
  splittableAnd = filter (r:
    let cs = andConjuncts r; antVars = varsOf (builtins.elemAt r 1); in
    cs != [ ] && all (atomLike antVars) cs) ruleForms;
  andSplitYields = builtins.foldl' (n: r: n + length (andConjuncts r)) 0 splittableAnd;
  hornAfterAndSplit = hornCount + andSplitYields;

  # --- Stratifier dry-run ---------------------------------------------------
  # Edges from the consequent predicate to antecedent predicates, signed by negation.
  atomsOf = f: filter (s: isList s && s != [ ] && headOf s != "" && !isVar (headOf s)) (subforms f);
  isStructural = h: elem h [ "and" "or" "not" "exists" "forall" "<=>" ];
  bodyAtoms = ant: filter (s: !(isStructural (headOf s))) (atomsOf ant);
  negAtoms = ant:
    concatMap (s: if headOf s == "not" && isList (builtins.elemAt s 1) then [ (builtins.elemAt s 1) ] else [ ]) (subforms ant);
  posAtoms = ant: filter (s: headOf s != "not") (bodyAtoms ant);

  edges = concatMap (r:
    let c = headOf (builtins.elemAt r 2); ant = builtins.elemAt r 1; in
    (if isVar c then [ ] else map (a: { from = c; to = headOf a; neg = false; }) (posAtoms ant)
    ++ map (a: { from = c; to = headOf a; neg = true; }) (negAtoms ant))) ruleForms;
  preds = unique (concatMap (e: [ e.from e.to ]) edges);
  edgeAll = listToAttrs (map (p: { name = p; value = map (e: e.to) (filter (e: e.from == p) edges); }) preds);
  edgeRev = foldl' (m: e: m // { ${e.to} = (m.${e.to} or [ ]) ++ [ e.from ]; })
    (listToAttrs (map (q: { name = q; value = [ ]; }) preds)) edges;
  closureVia = em: p: map (e: e.key) (builtins.genericClosure { startSet = [ { key = p; } ]; operator = x: map (t: { key = t; }) (em.${x.key} or [ ]); });
  fwd = listToAttrs (map (p: { name = p; value = closureVia edgeAll p; }) preds);
  bwd = listToAttrs (map (p: { name = p; value = closureVia edgeRev p; }) preds);
  # A predicate sits on a cycle through a negative edge iff there is a negative edge u -> v
  # with P reachable from v and able to reach u.
  negEdges = filter (e: e.neg) edges;
  unstratifiable = unique (concatMap (e:
    filter (p: (elem p (fwd.${e.to} or [ ]) || p == e.to) && (elem p (bwd.${e.from} or [ ]) || p == e.from)) preds) negEdges);

  report = {
    source = pins.merge;
    ref = pins.ref;
    totalForms = length forms;
    byHead = histogram;
    implies = length ruleForms;
    impliesWithNot = builtins.length (filter (c: c.hasNot) classified);
    impliesWithOr = builtins.length (filter (c: c.hasOr) classified);
    impliesWithExists = builtins.length (filter (c: c.hasExists) classified);
    impliesWithIff = builtins.length (filter (c: c.hasIff) classified);
    iff = length iffForms;
    equivalent = length eqvForms;
    transitiveRelationDecls = length transitiveDecls;
    symmetricRelationDecls = length symmetricDecls;
    reflexiveRelationDecls = length reflexiveDecls;
    horn = hornCount;
    hornAfterAndSplit = hornAfterAndSplit;
    splittableAndConsequents = builtins.length splittableAnd;
    andSplitYields = andSplitYields;
    disjunctiveHead = builtins.length (filter (c: c.disjunctiveHead) classified);
    negatedConsequent = builtins.length (filter (c: c.negatedConsequent) classified);
    quantifiedConsequent = builtins.length (filter (c: c.quantifiedConsequent) classified);
    predicateVariable = builtins.length (filter (c: c.predicateVariable) classified);
    functionConsequent = builtins.length (filter (c: c.functionConsequent) classified);
    unboundConsequentVar = builtins.length (filter (c: c.unboundConsequentVar) classified);
    verdict =
      if hornCount >= 300 then "ingestible"
      else if hornCount >= 100 then "marginal"
      else "reject";
    stratifierDryRun = {
      predicates = length preds;
      unstratifiablePredicates = sort builtins.lessThan unstratifiable;
      unstratifiableCount = length unstratifiable;
    };
  };
in
{
  inherit report;
  json = builtins.toJSON report;
  summary = {
    inherit (report) totalForms implies horn disjunctiveHead functionConsequent verdict;
    unstratifiable = report.stratifierDryRun.unstratifiableCount;
  };
}
