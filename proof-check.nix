# proof-check.nix — independent re-checker for reasoner/proof.nix certificates.
#
#   nix --extra-experimental-features nix-command eval --impure --expr \
#       '(import ./proof-check.nix { file = ./proof.kif; })'   -> "proof: N steps, independently re-checked ✓"
#
# The proof file may name ontologies as strings (an audit trail); the checker loads the
# ontologies passed as `ontologies` — you choose which files are authoritative.
#
# Shares no code with the engine (datalog.nix, sumo.nix, reasoner/*.nix). The parser
# (kif.nix) is the only import; everything else — unification, class subsumption
# re-derivation, premise evaluation — is reimplemented here and fails loudly.
#
# Per step (in file order):
#   1. the rule id must resolve to a rule in the certificate, verbatim;
#   2. the rule's variables must all be supplied by the step's bindings;
#   3. the bindings must ground the antecedent;
#   4. the antecedent must hold: positive and existential premises against the
#      prefix (axioms + earlier steps), NAF against the complete universe;
#   5. the consequent, under the same bindings, must be exactly the step's fact.
# Every fact in the universe must be an axiom or a step conclusion, and the goal
# must name a step proving it.
{ file ? ./proof.kif, ontologies ? [ ./sumo.full/Merge.kif ./nix-domain.kif ] }:
let
  kif = import ./kif.nix;
  forms = kif.parse (builtins.readFile file);

  inherit (builtins) all any attrNames attrValues concatMap concatStringsSep elem elemAt filter foldl' genList head isList isString length listToAttrs map sort tail substring;

  headOf = f: if isList f && f != [ ] then head f else "";
  isVar = s: isString s && substring 0 1 s == "?";
  show = s: if isString s then s else "(" + concatStringsSep " " (map show s) + ")";
  unique = xs: attrNames (listToAttrs (map (n: { name = n; value = null; }) xs));

  # --- certificate partition --------------------------------------------------
  ontPaths = ontologies; # the checker loads ontologies you pass, not the ones named in the cert
  rules = listToAttrs (map (f: { name = elemAt f 1; value = elemAt f 2; }) (filter (f: headOf f == "rule") forms));
  axioms = map (f: elemAt f 1) (filter (f: headOf f == "fact") forms);
  steps = filter (f: headOf f == "step") forms;
  goalForms = filter (f: headOf f == "goal") forms;

  # --- class subsumption, re-derived from the pinned ontologies (independent) --
  ontForms = concatMap (p: kif.parse (builtins.readFile (toString p))) ontPaths;
  out = name: filter (f: isList f && f != [ ] && head f == name) ontForms;
  subclassTriples = filter (f: length f == 3 && isString (elemAt f 1) && isString (elemAt f 2)) (out "subclass");
  nodes = unique (concatMap (f: [ (elemAt f 1) (elemAt f 2) ]) subclassTriples);
  parentsOf = listToAttrs (map (c: { name = c; value = map (f: elemAt f 2) (filter (f: elemAt f 1 == c) subclassTriples); }) nodes);
  ancestorsOf = c: map (e: e.key) (builtins.genericClosure { startSet = [ { key = c; } ]; operator = x:
    map (p: { key = p; }) (parentsOf.${x.key} or [ ]); }) ;
  equivForms = filter (f: length f == 3 && isString (elemAt f 1) && isString (elemAt f 2)) (out "equivalent");
  eqAdj = foldl' (m: f:
      m // { ${elemAt f 1} = (m.${elemAt f 1} or [ ]) ++ [ (elemAt f 2) ];
             ${elemAt f 2} = (m.${elemAt f 2} or [ ]) ++ [ (elemAt f 1) ]; })
    { } equivForms;
  eqNodes = unique (concatMap (f: [ (elemAt f 1) (elemAt f 2) ]) equivForms);
  eqComponent = n: map (e: e.key) (builtins.genericClosure { startSet = [ { key = n; } ]; operator = x: map (t: { key = t; }) (eqAdj.${x.key} or [ ]); });
  eqRep = listToAttrs (map (n: { name = n; value = head (sort builtins.lessThan (eqComponent n)); }) eqNodes);
  rep = c: eqRep.${c} or c;
  isSubclass = c: a:
    rep c == rep a || any (x: rep x == rep a) (ancestorsOf (rep c));

  universe = axioms ++ map (s: elemAt s 2) steps;
  universeSet = listToAttrs (map (f: { name = show f; value = null; }) universe);

  instancesOf = x:
    map (f: elemAt f 2) (filter (f: headOf f == "instance" && length f == 3 && elemAt f 1 == x) universe);
  instanceHolds = x: c:
    isString x && isString c && any (d: isSubclass d c) (instancesOf x);

  # --- bindings & unification --------------------------------------------------
  subst = b: s:
    if isString s then (if isVar s then (b.${s} or (throw "proof: unbound variable ${s}")) else s)
    else if isList s then map (subst b) s
    else s;
  grounds = s: if isString s then !isVar s else all grounds s;

  # --- premise evaluation --------------------------------------------------------
  evalPremise = prefix: universe': b: form:
    let h = headOf form;
    in
    if h == "and" then all (evalPremise prefix universe' b) (tail form)
    else if h == "exists" then evalPremise prefix universe' b (elemAt form 2)
    else if h == "not" then
      let p = subst b (elemAt form 1); in
      if !(grounds p) then throw "proof: unsafe (unbound variable) in NAF premise ${show p}"
      else !(universeSet ? ${show p})
    else if h == "equal" then subst b (elemAt form 1) == subst b (elemAt form 2)
    else if h == "instance" && length form == 3 && isString (subst b (elemAt form 2)) then
      instanceHolds (subst b (elemAt form 1)) (subst b (elemAt form 2))
    else
      let atom = subst b form; in
      any (f: f == atom) prefix;

  # --- step verification ---------------------------------------------------------
  stepFacts = map (s: elemAt s 2) steps;
  checkOne = acc: s:
    let
      sid = elemAt s 1; fact = elemAt s 2; ruleId = elemAt s 3; binds = elemAt s 4;
      bindings = listToAttrs (map (b: { name = elemAt b 0; value = elemAt b 1; }) (tail binds));
      rule = rules.${ruleId} or null;
      prefix = acc.facts;
      conclusion = if rule == null then { ok = false; why = "rule ${ruleId} not in certificate"; }
        else
          let ant = elemAt rule 1; cons = elemAt rule 2;
          in
          if !(evalPremise prefix universe bindings ant)
          then { ok = false; why = "step ${sid}: antecedent does not hold"; }
          else if subst bindings cons != fact
          then { ok = false; why = "step ${sid}: bindings do not yield the claimed fact ${show fact}"; }
          else if !(grounds fact)
          then { ok = false; why = "step ${sid}: the fact is not ground"; }
          else { ok = true; why = ""; };
    in if conclusion.ok
       then { ok = true; facts = acc.facts ++ [ fact ]; failures = acc.failures; }
       else { ok = false; facts = acc.facts; failures = acc.failures ++ [ conclusion.why ]; };

  checkResult = foldl' checkOne { facts = axioms; failures = [ ]; } steps;

  goal = if goalForms == [ ] then null else head goalForms;
  goalFact = if goal == null then null else elemAt goal 1;
  goalStepId = if goal == null then null else elemAt goal 2;
  goalStepOk = if goalStepId == null then false
    else any (s: elemAt s 1 == goalStepId && elemAt s 2 == goalFact) steps;

  universeOk = length universe == length checkResult.facts && checkResult.facts != [ ];
  completeOk = universeOk && checkResult.ok;

  diagnostics = { inherit universeOk; steps = length steps; axioms = length axioms; };
in
if goal == null then throw "proof: certificate has no goal"
else if checkResult.failures != [ ] then throw (concatStringsSep "; " checkResult.failures)
else if !universeOk then throw "proof: the universe does not match the certified facts (missing steps or extra facts)"
else if !goalStepOk then throw "proof: the goal step does not prove the goal fact"
else "proof: ${toString (length steps)} steps, independently re-checked ✓"
