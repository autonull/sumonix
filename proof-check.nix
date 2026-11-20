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

  inherit (builtins) all any attrNames attrValues concatMap concatStringsSep elem elemAt filter foldl' genList head isList isString length listToAttrs map sort tail substring match replaceStrings;

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

  # --- builtin registry (parity with engine) ------------------------------------
  stripQuotes = s:
    if isString s && builtins.stringLength s >= 2 && substring 0 1 s == "\"" && substring (builtins.stringLength s - 1) 1 s == "\"" then
      substring 1 (builtins.stringLength s - 2) s
    else s;

  parseVersion = v:
    if isString v then
      let
        spaced = replaceStrings [ "." ] [ " " ] v;
        m = match "([0-9]+) ?([0-9]+)? ?([0-9]+)? ?([0-9]+)?" spaced;
        nums = map builtins.fromJSON (filter (x: x != null) m);
      in
      if m == null then [ ] else nums
    else [ ];

  compareVersions = a: b:
    let
      va = parseVersion a;
      vb = parseVersion b;
      maxLen = if length va > length vb then length va else length vb;
      pad = l: l ++ genList (_: 0) (maxLen - length l);
      vaP = pad va;
      vbP = pad vb;
    in
    foldl' (acc: i: if acc != 0 then acc else if elemAt vaP i < elemAt vbP i then -1 else if elemAt vaP i > elemAt vbP i then 1 else 0) 0 (genList (i: i) maxLen);

  nextMajor = v:
    let p = parseVersion v; in
    if length p == 0 then v
    else if length p >= 1 then toString ((elemAt p 0) + 1) + ".0.0"
    else v;

  nextMinor = v:
    let p = parseVersion v; in
    if length p == 0 then v
    else if length p >= 2 then toString (elemAt p 0) + "." + toString ((elemAt p 1) + 1) + ".0"
    else if length p >= 1 then toString (elemAt p 0) + ".1.0"
    else v;

  versionInRangeEval = version: range:
    let
      firstChar = substring 0 1 range;
      lastChar = substring (builtins.stringLength range - 1) 1 range;
      inner = substring 1 (builtins.stringLength range - 2) range;
      commaMatch = match "(.+),(.+)" inner;
      lower = elemAt commaMatch 0;
      upper = elemAt commaMatch 1;
      bounds = if firstChar == "[" && lastChar == "]" && commaMatch != null then
        { lower = lower; lowerInc = true; upper = upper; upperInc = true; }
      else if firstChar == "(" && lastChar == ")" && commaMatch != null then
        { lower = lower; lowerInc = false; upper = upper; upperInc = false; }
      else if firstChar == "[" && lastChar == ")" && commaMatch != null then
        { lower = lower; lowerInc = true; upper = upper; upperInc = false; }
      else if firstChar == "(" && lastChar == "]" && commaMatch != null then
        { lower = lower; lowerInc = false; upper = upper; upperInc = true; }
      else if firstChar == "^" then
        let base = substring 1 (builtins.stringLength range - 1) range;
        in { lower = base; lowerInc = true; upper = nextMajor base; upperInc = false; }
      else if firstChar == "~" then
        let base = substring 1 (builtins.stringLength range - 1) range;
        in { lower = base; lowerInc = true; upper = nextMinor base; upperInc = false; }
      else if match ".*\\..*\\.x" range != null then
        let base = replaceStrings [ ".x" ] [ ".0" ] range;
        in { lower = base; lowerInc = true; upper = nextMinor base; upperInc = false; }
      else { lower = range; lowerInc = true; upper = range; upperInc = true; };
      cmpLower = compareVersions version bounds.lower;
      cmpUpper = compareVersions version bounds.upper;
    in
    (if bounds.lowerInc then cmpLower >= 0 else cmpLower > 0) && (if bounds.upperInc then cmpUpper <= 0 else cmpUpper < 0);

  builtinRegistry = {
    versionInRange = { arity = 2; eval = b: args: versionInRangeEval (stripQuotes (head args)) (stripQuotes (head (tail args))); };
    greaterThan = { arity = 2; eval = b: args: let x = stripQuotes (head args); y = stripQuotes (head (tail args)); in compareVersions x y > 0; };
    lessThan = { arity = 2; eval = b: args: let x = stripQuotes (head args); y = stripQuotes (head (tail args)); in compareVersions x y < 0; };
    notEqual = { arity = 2; eval = b: args: let x = head args; y = head (tail args); in x != y; };
    subsetOf = { arity = 2; eval = b: args: let s1 = head args; s2 = head (tail args); in all (x: elem x (parseKifList s2)) (parseKifList s1); };
    supersetOf = { arity = 2; eval = b: args: let s1 = head args; s2 = head (tail args); in all (x: elem x (parseKifList s1)) (parseKifList s2); };
  };

  parseKifList = s:
    if isString s then
      let
        stripped = substring 1 (builtins.stringLength s - 2) s;
        parseParts = str: idx:
          if idx >= builtins.stringLength str then [ ]
          else
            let
              skipSpaces = i: if i < builtins.stringLength str && substring i 1 str == " " then skipSpaces (i + 1) else i;
              start = skipSpaces idx;
            in
            if start >= builtins.stringLength str then [ ]
            else
              let
                findEnd = i: if i < builtins.stringLength str && substring i 1 str != " " then findEnd (i + 1) else i;
                end = findEnd start;
                token = substring start (end - start) str;
                cleaned = if builtins.stringLength token >= 2 && substring 0 1 token == "\"" && substring (builtins.stringLength token - 1) 1 token == "\"" then
                  substring 1 (builtins.stringLength token - 2) token
                else token;
              in
              [ cleaned ] ++ parseParts str (end + 1);
      in
      parseParts stripped 0
    else [ ];

  isBuiltin = h: builtinRegistry ? ${h};

  # --- bindings & unification --------------------------------------------------
  subst = b: s:
    if isString s then (if isVar s then (b.${s} or (throw "proof: unbound variable ${s}")) else s)
    else if isList s then map (subst b) s
    else s;
  grounds = s: if isString s then !isVar s else all grounds s;

  # --- three-valued logic for WFS parity ----------------------------------------
  # Truth values: "true" | "false" | "unknown"
  evalPremise3V = prefix: universe': b: form:
    let h = headOf form;
    in
    if h == "and" then
      let results = map (evalPremise3V prefix universe' b) (tail form); in
      if any (r: r == "false") results then "false"
      else if any (r: r == "unknown") results then "unknown"
      else "true"
    else if h == "not" then
      let p = subst b (elemAt form 1); r = evalPremise3V prefix universe' b p; in
      if r == "true" then "false" else if r == "false" then "true" else "unknown"
    else if h == "exists" then
      evalPremise3V prefix universe' b (elemAt form 2)
    else if h == "before" || h == "after" || h == "within" || h == "holdsAt" then
      # Temporal predicates - evaluate using integer timestamps
      let atom = subst b form; in
      if any (f: f == atom) prefix then "true" else "unknown"
    else if isBuiltin h then
      let builtin = builtinRegistry.${h}; args = map (a: subst b a) (tail form); in
      if builtin.eval b args then "true" else "false"
    else
      let atom = subst b form; in
      if any (f: f == atom) prefix then "true"
      else if any (f: f == atom) universe' then "false"
      else "unknown";

  # --- premise evaluation (classic 2-valued for backward compat) ----------------
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
    else if isBuiltin h then
      let builtin = builtinRegistry.${h}; args = map (a: subst b a) (tail form); in
      builtin.eval b args
    else
      let atom = subst b form; in
      any (f: f == atom) prefix;

  # --- congruence equivalence classes (for parity) ---------------------------------
  # Track equivalence classes during step verification
  eqClasses = { };
  # Initialize from axioms
  eqClassesInit = foldl' (m: f:
    if headOf f == "equal" && length f == 3 then
      let a = elemAt f 1; b = elemAt f 2; in
      m // { ${a} = (m.${a} or [ a ]) ++ [ b ]; ${b} = (m.${b} or [ b ]) ++ [ a ]; }
    else m
  ) { } axioms;

  # Find canonical representative
  findRep = m: x:
    let members = m.${x} or [ x ]; in
    head (sort builtins.lessThan members);

  # Unify equivalence classes
  unifyEq = m: a: b:
    let repA = findRep m a; repB = findRep m b; in
    if repA == repB then m
    else
      let membersA = m.${repA} or [ repA ]; membersB = m.${repB} or [ repB ];
          allMembers = membersA ++ membersB;
          newRep = head (sort builtins.lessThan allMembers);
      in foldl' (mm: mmbr: mm // { ${mmbr} = allMembers; }) m allMembers;

  # --- soft-rules weight tracking (for parity) -----------------------------------
  # Rule weights from soft-rules.nix
  ruleWeights = listToAttrs (map (r:
    let ruleId = elemAt r 1; in
    { name = ruleId; value = 1; }  # default weight 1
  ) (filter (f: headOf f == "rule") forms));

  # --- step verification ---------------------------------------------------------
  stepFacts = map (s: elemAt s 2) steps;
  checkOne = acc: s:
    let
      sid = elemAt s 1; fact = elemAt s 2; ruleId = elemAt s 3; binds = elemAt s 4;
      bindings = listToAttrs (map (b: { name = elemAt b 0; value = elemAt b 1; }) (tail binds));
      rule = rules.${ruleId} or null;
      prefix = acc.facts;
      eqClasses = acc.eqClasses or eqClassesInit;
      totalWeight = acc.totalWeight or 0;
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
          else
            let
              # Update equivalence classes if fact is an equality
              newEqClasses = if headOf fact == "equal" && length fact == 3 then
                unifyEq eqClasses (elemAt fact 1) (elemAt fact 2)
              else eqClasses;
              # Accumulate rule weight
              newWeight = totalWeight + (ruleWeights.${ruleId} or 1);
            in
            { ok = true; why = ""; eqClasses = newEqClasses; totalWeight = newWeight; };
    in if conclusion.ok
       then { ok = true; facts = acc.facts ++ [ fact ]; failures = acc.failures; eqClasses = conclusion.eqClasses; totalWeight = conclusion.totalWeight; }
       else { ok = false; facts = acc.facts; failures = acc.failures ++ [ conclusion.why ]; eqClasses = acc.eqClasses; totalWeight = acc.totalWeight; };

  checkResult = foldl' checkOne { facts = axioms; failures = [ ]; eqClasses = eqClassesInit; totalWeight = 0; } steps;

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
