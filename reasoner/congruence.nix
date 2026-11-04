# T2.4 Congruence Closure: equality reasoning for all predicates.
#
#   congruence { ontology; rules; facts; forms ? [ ] } -> { rules; diagnostics; }
#
# For every predicate with known arity (from ontology domains/ranges or
# predicate-class instances), generates symmetric congruence schemas:
#   (=> (and (cong ?x ?y) (P ?x ...)) (P ?y ...))   per position
# Also generates bridging rules: (=> (equal ?x ?y) (cong ?x ?y)) and symmetry.
# The engine treats 'equal' as a built-in for term equality; 'cong' is a regular
# predicate that supports congruence closure.
#
# Every rule is attributed: source = "congruence", declaration = "<arity justification>".
{ ontology, rules, facts, forms ? [ ] }:
let
  inherit (builtins) all any attrNames attrValues concatMap elem elemAt filter foldl' genList head isList isString length listToAttrs map sort tail;
  concatStringsSep = builtins.concatStringsSep;
  toString = builtins.toString;

  headOf = f: if isList f && f != [ ] then head f else "";
  show = s: if isString s then s else "(" + concatStringsSep " " (map show s) + ")";
  count = xs: foldl' (m: x: m // { ${toString x} = (m.${toString x} or 0) + 1; }) { } xs;
  unique = xs: let s = foldl' (m: x: m // { ${toString x} = x; }) { } xs; in attrValues s;
  flatten = f: if isList f then concatMap flatten f else [ f ];
  subforms = f: if isList f then [ f ] ++ concatMap subforms (tail f) else [ ];
  isVar = s: isString s && (builtins.substring 0 1 s == "?" || builtins.substring 0 1 s == "@");
  varsOf = f: filter isVar (flatten f);

  # --- collect predicate arities from forms ---
  domainForms = filter (f: headOf f == "domain" && length f >= 4) forms;
  rangeForms = filter (f: headOf f == "range" && length f >= 4) forms;
  instanceDecls = filter (f: headOf f == "instance" && length f == 3) forms;

  predicateArity = { UnaryPredicate = 1; BinaryPredicate = 2; TernaryPredicate = 3; QuaternaryPredicate = 4; };

  classesOf = listToAttrs (map (R: { name = R; value = unique (map (f: elemAt f 2) (filter (f: elemAt f 1 == R) instanceDecls)); }) (unique (map (f: elemAt f 1) instanceDecls)));

  fromClass = R:
    let ns = filter (n: n != null) (map (c: predicateArity.${c} or null) (classesOf.${R} or [ ]));
    in if ns == [ ] then null else head (sort builtins.lessThan ns);

  toInt = s: if builtins.isInt s then s else if isString s && builtins.match "[0-9]+" s != null then builtins.fromJSON s else 0;

  maxPosition = R:
    let pos = map (f: toInt (elemAt f 2)) (filter (f: (headOf f == "domain" || headOf f == "range") && length f >= 3 && elemAt f 1 == R) (domainForms ++ rangeForms));
    in if pos == [ ] then 0 else foldl' (a: b: if a > b then a else b) 0 pos;

  # Arity from facts and rules (observed)
  allFactsAndRules1 = facts ++ concatMap (r: [ elemAt r 1 elemAt r 2 ]) rules;
  allPredicates1 = unique (concatMap (f: let h = headOf f; in if isList f && f != [ ] then [ h ] else [ ]) (filter (f: isList f && f != [ ]) allFactsAndRules1));
  predArity = p: let
    fs = filter (f: headOf f == p) facts;
    rs = filter (r: headOf (elemAt r 2) == p) rules;
    arities = unique (map (f: length f - 1) fs ++ map (r: length (elemAt r 2) - 1) rs);
  in if arities == [ ] then 0 else foldl' (a: b: if a > b then a else b) 0 arities;
  predArityObserved = listToAttrs (map (p: { name = p; value = predArity p; }) allPredicates1);

  # Arity from domains/ranges
  domainPredicates = unique (concatMap (f: [ elemAt f 1 ]) (domainForms ++ rangeForms));
  domainArity = listToAttrs (map (R:
    let pos = map (f: toInt (elemAt f 2)) (filter (f: headOf f == "domain" && length f >= 4 && elemAt f 1 == R) domainForms);
        pos2 = map (f: toInt (elemAt f 2)) (filter (f: headOf f == "range" && length f >= 4 && elemAt f 1 == R) rangeForms);
        allPos = pos ++ pos2;
    in { name = R; value = if allPos == [ ] then 0 else foldl' (a: b: if a > b then a else b) 0 allPos; })
    domainPredicates);

  arityOf = R: let c = fromClass R; d = domainArity.${R} or 0; o = predArityObserved.${R} or 0; in if c != null then c else if d > 0 then d else if o > 0 then o else 0;

  # All predicates that appear in facts or rules
  allPredicates = unique (concatMap (f: let h = headOf f; in if isList f && f != [ ] && !isVar h && !elem h [ "and" "or" "not" "exists" "forall" "=>" "<=>" "equal" "instance" "subclass" "equivalent" "domain" "range" "subrelation" "inverse" "subAttribute" "cong" ] then [ h ] else [ ]) (filter (f: isList f && f != [ ]) allFactsAndRules1));

  # --- generate congruence rules ---
  varN = n: "?v${toString n}";

  # Generate rules for a single predicate - avoid elemAt by generating vars directly
  rulesForPred = R: let
    n = arityOf R;
  in if n == null || n < 1 then [ ] else
    concatMap (pos: (let
      x = varN pos;
      y = varN n;
      # Generate vars list with y at position pos
      vars1 = genList (i: if i == pos then y else varN i) n;
      # Generate vars list with x at position pos (which is just the standard vars)
      vars2 = genList varN n;
      a = [ R ] ++ vars2;
      consequent = [ R ] ++ vars1;
      antecedent = [ "and" [ "cong" x y ] a ];
      # For reverse direction: swap x and y at position pos
      vars3 = genList (i: if i == pos then x else varN i) n;
      consequent2 = [ R ] ++ vars3;
      antecedent2 = [ "and" [ "cong" y x ] a ];
    in
    [ { declaration = "congruence ${R}/${toString (pos + 1)} (arity ${toString n})"; rules = [ [ "=>" antecedent consequent ] [ "=>" antecedent2 consequent2 ] ]; }
    ])) (genList (i: i) n);

  # Congruence predicate bridging rules - only symmetry, no transitivity to avoid deep recursion
  congBridge = [
    { declaration = "congruence cong/from-equal"; rules = [ [ "=>" [ "equal" "?x" "?y" ] [ "cong" "?x" "?y" ] ] ]; }
    { declaration = "congruence cong/symmetry"; rules = [ [ "=>" [ "cong" "?x" "?y" ] [ "cong" "?y" "?x" ] ] ]; }
  ];

  congruenceRules = congBridge ++ concatMap (R: rulesForPred R) allPredicates;

  # --- flatten and deduplicate ---
  ruleEntries = concatMap (e: e.rules) congruenceRules;
  dedupe = xs:
    let go = acc: ys:
      if ys == [ ] then acc
      else
        let s = show (head ys);
        in if elem s acc.texts then go { texts = acc.texts; out = acc.out ++ [ { rule = head ys; redundant = true; } ]; } (tail ys)
           else go { texts = acc.texts ++ [ s ]; out = acc.out ++ [ { rule = head ys; redundant = false; } ]; } (tail ys);
    in (go { texts = [ ]; out = [ ]; } xs).out;
  deduped = dedupe ruleEntries;
  kept = map (r: r.rule) (filter (r: !r.redundant) deduped);
  redundant = map (r: show r.rule) (filter (r: r.redundant) deduped);

  diagnostics = { generated = length kept; predicates = length allPredicates; arities = predArityObserved; byArity = count (map (R: toString (arityOf R)) allPredicates); redundant = length redundant; };
in
{ rules = kept; inherit diagnostics; }