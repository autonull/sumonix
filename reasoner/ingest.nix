# Phase 3 — Horn ingestion for the current naive engine.
#
#   ingest { } -> { rules; rejected; diagnostics; }
#
# Classifies Merge.kif (plus <=> splits, forall-stripping, antecedent-or splits,
# and-consequent splits, ancestor-propagation drops and the stratifier's negative-
# cycle rejections) into rules ready for datalog.nix. Every refusal carries a
# reason; nothing is dropped silently. Merge.kif is pinned (pins.nix).
#
# Composition is the caller's choice: rules are Merge-derived only. Callers that
# also want declaration-driven rules compose
#   rules = userRules ++ ingest.rules ++ (import ./synthesize.nix { forms; }).rules
#
# Expansion order (first match wins):
#   1. (forall (vars) BODY)                          -> strip the quantifier; BODY must be an (=> ...) rule
#   2. structural consequent (not/forall/exists/=>
#      with a nested implication)                     -> quantified-or-negated-consequent
#   3. disjunctive consequent (or/xor)                -> disjunctive-head (E1, later)
#   4. predicate-variable consequent                  -> predicate-variable
#   5. nested list in consequent arguments            -> function-consequent
#   6. consequent variable unbound in antecedent      -> unbound-consequent-var
#   7. antecedent (or ...)                           -> one rule per disjunct (E4)
#   8. (and A B ..) consequent, atom-like conjuncts   -> one rule per conjunct (and-split)
#   9. (=> .. ..) consequent                          -> nested-=> (subsumed by 2)
#  10. (=> (and .. (subclass ..) ..) (instance ..))  -> ancestor-propagation (ontology handles)
#  11. (=> (subclass ..) (subclass ..))              -> ancestor-propagation (ontology handles)
#  12. (=> (equal ..) (forall ..)) etc.              -> left to rule 5/2 (rejected with their reasons)
#
# The stratifier (reasoner/stratify.nix) then removes every rule whose consequent
# predicate sits on a negative cycle, with reason `unstratified-negation`.
{ pins ? import ../pins.nix }:
let
  kif = import ../lib/kif.nix { };
  forms = kif.parse (builtins.readFile pins.merge);

  inherit (builtins) all any attrNames concatMap elem elemAt filter foldl' genList head isList isString length listToAttrs map sort tail;

  inherit (kif) show headOf flatten isVar unique subforms varsOf isKifOp count;
  concatStringsSep = builtins.concatStringsSep;
  quantifiedVars = f:
    concatMap (s:
      if isList s && (headOf s == "exists" || headOf s == "forall") && length s >= 2 && isList (elemAt s 1)
      then filter isVar (flatten (elemAt s 1))
      else [ ]) (subforms f);
  isStructural = h: elem h [ "and" "or" "not" "exists" "forall" "<=>" "=>" ];
  # Atoms of an antecedent with polarity: `not` flips; (not (not P) = P.)
  bodyWalk = neg: f:
    if !(isList f) then [ ]
    else
      let h = headOf f; in
      if h == "not" then concatMap (bodyWalk (!neg)) (tail f)
      else if isStructural h then concatMap (bodyWalk neg) (tail f)
      else if h == "" || isVar h then [ ]
      else [ { atom = f; inherit neg; } ];

  structuralConsequent = c: elem (headOf c) [ "not" "forall" "exists" "=>" ];
  disjunctiveHead = c: elem (headOf c) [ "or" "xor" ];
  predicateVariable = c: isVar (headOf c);
  argFunctionTerm = cons:
    let nested = concatMap (a: if isList a then [ a ] ++ subforms a else [ ]) (tail cons);
    in nested != [ ];
  atomLike = antVars: c: isList c && c != [ ] && !isVar (headOf c) && !isStructural (headOf c) && !argFunctionTerm c
    && all (v: elem v antVars) (varsOf c);

  # Candidate units: => forms, <=> forms (split both ways), forall-wrapped rules.
  units = concatMap (f:
    let h = headOf f; in
    if h == "forall" then
      let body = elemAt f (length f - 1); in
      if isList body && headOf body == "=>" then units body
      else [ { form = f; forallOnly = true; } ]
    else if h == "=>" then [ { form = f; } ]
    else if h == "<=>" && length f >= 3 then
      [ { form = [ "=>" (elemAt f 1) (elemAt f 2) ]; source = "iff-split"; }
        { form = [ "=>" (elemAt f 2) (elemAt f 1) ]; source = "iff-split"; } ]
    else [ ]) forms;

  isAncestorDup = f:
    let cons = elemAt f 2; ant = elemAt f 1;
        atoms = map (x: x.atom) (bodyWalk false ant);
        hasSubclass = any (a: headOf a == "subclass") atoms;
    in
    (headOf cons == "instance" && hasSubclass) || (headOf cons == "subclass" && hasSubclass);

  expand = u:
    let f = u.form; ant = elemAt f 1; cons = elemAt f 2;
        antVars = varsOf ant;
        bound = antVars ++ quantifiedVars cons;
        source = u.source or "merge-horn";
    in
    if u.forallOnly or false then [ { reject = "forall-non-rule"; declaration = show f; } ]
    else if structuralConsequent cons then [ { reject = "quantified-or-negated-consequent"; declaration = show f; } ]
    else if disjunctiveHead cons then
      # (=> A (or B C ..)) -> emit as a disjunctive rule with special marker
      [ { rule = [ "=>" ant ] ++ [ "disjunct" ] ++ (tail cons); source = "disjunctive-head"; } ]
    else if predicateVariable cons then [ { reject = "predicate-variable"; declaration = show f; } ]
    else if argFunctionTerm cons then [ { reject = "function-consequent"; declaration = show f; } ]
    else if any (v: !(elem v bound)) (varsOf cons) then [ { reject = "unbound-consequent-var"; declaration = show f; } ]
    else if headOf ant == "or" then
      # (=> (or A B ..) C)  =>  (=> A C) (=> B C) ..   (E4)
      concatMap (disj: expand { form = [ "=>" disj cons ]; source = "or-split"; }) (tail ant)
    else if headOf cons == "and" && all (atomLike antVars) (tail cons) then
      # (=> A (and B C ..))  =>  (=> A B) (=> A C) ..
      concatMap (conjunct: expand { form = [ "=>" ant conjunct ]; source = "and-split"; }) (tail cons)
    else if any (a: headOf a == "instance" && length a == 3 && isList (elemAt a 2))
        (map (x: x.atom) (bodyWalk false ant))
    then [ { reject = "reified-instance-premise"; declaration = show f; } ]
    else if isAncestorDup f then [ { reject = "ancestor-propagation"; declaration = show f; } ]
    else [ { rule = f; inherit source; } ];

  expanded = concatMap expand units;
  kept = filter (e: e ? rule) expanded;
  rejected0 = map (e: { inherit (e) reject; declaration = e.declaration; }) (filter (e: e ? reject) expanded);

  # The rules this ingestion emits, ids relative to this list (datalog derives "head#index").
  ruleList = map (e: e.rule) kept;
  strat = import ./stratify.nix { rules = ruleList; };
  rejectedIds = map (r: r.rule) strat.rejections;   # "head#index" ids, positional
  rejectSet = listToAttrs (map (r: { name = r; value = true; }) rejectedIds);
  withId = genList (i: { id = "${headOf (elemAt (elemAt ruleList i) 2)}#${toString (i + 1)}"; value = elemAt ruleList i; }) (length ruleList);
  unstratified = map (e: { declaration = show e.value; reason = "unstratified-negation"; })
    (filter (e: rejectSet ? ${e.id}) withId);
  ingestable = map (e: e.value) (filter (e: !(rejectSet ? ${e.id})) withId);

  rejected = map (e: { declaration = e.declaration; reason = e.reject; }) rejected0
    ++ unstratified;

  diagnostics = {
    ingested = length ingestable;
    rejected = length rejected;
    byReason = count (map (r: r.reason) rejected);
    sources = count (map (e: e.source) kept);
    rules = map show ingestable;
    unstratifiablePredicates = strat.unstratifiable;
  };
in
{
  rules = ingestable;
  inherit rejected;
  inherit diagnostics;
}
