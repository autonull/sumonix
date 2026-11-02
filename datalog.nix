# Forward chaining over KIF Horn rules, with a proof for every derived fact (nix_sumo.md, sections 5.3, 14, 29).
#
#   engine { ontology; rules; facts; } -> { facts, holds, ask, why }
#
# rules are the top-level (=> antecedent consequent) forms; facts are ground forms. An antecedent may use and,
# exists, not (negation as failure: keep it out of a cycle), equal, and (instance X Class), which holds for an
# instance of any subclass of Class by the ontology. A rule whose consequent keeps a variable is refused.
{ ontology, rules, facts }:
let
  inherit (builtins) all any attrNames concatMap concatStringsSep elem elemAt filter foldl' genList head isList isString length mapAttrs substring tail;

  isVar = s: isString s && substring 0 1 s == "?";
  show = s: if isString s then s else "(" + concatStringsSep " " (map show s) + ")";

  # Match pattern p against ground f under bindings b: new bindings or null.
  unify = b: p: f:
    if isString p then
      if isVar p then
        if b ? ${p} then (if b.${p} == f then b else null) else b // { ${p} = f; }
      else if p == f then b else null
    else if isList f && length p == length f then
      foldl' (acc: i: if acc == null then null else unify acc (elemAt p i) (elemAt f i)) b (genList (i: i) (length p))
    else null;

  subst = b: s: if isString s then (if isVar s then b.${s} or s else s) else map (subst b) s;

  ground = s: if isString s then !isVar s else all ground s;

  headOf = p: if isList p && p != [ ] then head p else "";

  # What a round looks like to a premise: the facts, by relation and by relation with its first argument.
  index = idx:
    let entries = builtins.attrValues idx; in {
      inherit idx entries;
      byHead = builtins.groupBy (e: headOf e.fact) entries;
      byFirst = builtins.groupBy (e: headOf e.fact + " " + toString (elemAt e.fact 1)) (filter (e: isList e.fact && length e.fact > 1 && isString (elemAt e.fact 1)) entries);
    };

  # The entries that can match premise p under bindings b: the one fact when p is ground, else the narrowest group.
  candidates = ix: b: p:
    let q = subst b p; h = headOf q; in
    if ground q then (if ix.idx ? ${show q} then [ ix.idx.${show q} ] else [ ])
    else if isString h && h != "" && !(isVar h) then
      (if length q > 1 && isString (elemAt q 1) && !(isVar (elemAt q 1))
       then ix.byFirst."${h} ${elemAt q 1}" or [ ]
       else ix.byHead.${h} or [ ])
    else ix.entries;

  # Solutions of premise p from state s = { b = bindings; used = keys of the facts it rests on }.
  step = ix: s: p:
    let h = headOf p; in
    if h == "and" then foldl' (sols: q: concatMap (t: step ix t q) sols) [ s ] (tail p)
    else if h == "exists" then step ix s (elemAt p 2)
    else if h == "not" then (if step ix s (elemAt p 1) == [ ] then [ s ] else [ ])
    else if h == "equal" then
      (let a = subst s.b (elemAt p 1); c = subst s.b (elemAt p 2); in if a == c then [ s ] else [ ])
    else if h == "instance" && ontology != null && length p == 3 && !(isVar (subst s.b (elemAt p 2))) then
      let c = subst s.b (elemAt p 2); in
      concatMap
        (e:
          let f = e.fact; b = unify s.b (elemAt p 1) (elemAt f 1); in
          if headOf f == "instance" && length f == 3 && ontology.isSubclass (elemAt f 2) c && b != null
          then [ { inherit b; used = s.used ++ [ e.key ]; } ] else [ ])
        (ix.byHead.instance or [ ])
    else
      concatMap
        (e:
          let b = unify s.b p e.fact; in
          if b == null then [ ] else [ { inherit b; used = s.used ++ [ e.key ]; } ])
        (candidates ix s.b p);

  # Each rule, with a name from its consequent and its place among the rules.
  named = genList
    (i:
      let r = elemAt rules i; c = elemAt r 2; in
      { id = "${headOf c}#${toString (i + 1)}"; antecedent = elemAt r 1; consequent = c; })
    (length rules);

  # Every fact the rules give from idx that idx does not hold yet, with the rule and the facts it rests on.
  # (listToAttrs keeps the first of equal names: the first rule and solution that gave a fact.)
  derive = idx:
    let ix = index idx; in
    builtins.listToAttrs (concatMap
      (r:
        concatMap
          (s:
            let f = subst s.b r.consequent; k = show f; in
            if !(ground f) then throw "rule ${r.id}: the consequent keeps a variable (${k})"
            else if idx ? ${k} then [ ]
            else [ { name = k; value = { key = k; fact = f; by = { rule = r.id; from = s.used; }; }; } ])
          (step ix { b = { }; used = [ ]; } r.antecedent))
      named);

  fix = idx: let new = derive idx; in if new == { } then idx else fix (idx // new);

  closure = fix (builtins.listToAttrs (map (f: { name = show f; value = { key = show f; fact = f; by = null; }; }) facts));

  proof = k:
    let e = closure.${k}; in
    if e.by == null then { fact = show e.fact; asserted = true; }
    else { fact = show e.fact; rule = e.by.rule; from = map proof e.by.from; };

  lines = depth: p:
    let pad = concatStringsSep "" (genList (_: "  ") depth); in
    [ (pad + p.fact + (if p ? asserted then "    asserted" else "    by " + p.rule)) ] ++ concatMap (lines (depth + 1)) (p.from or [ ]);
in
{
  facts = map (e: e.fact) (builtins.attrValues closure);
  holds = f: closure ? ${show f};
  # The bindings that make a pattern true: ask [ "dependsOnTransitive" "?x" "openssl" ] -> [ { "?x" = "curl"; } .. ]
  ask = pattern: map (s: s.b) (step (index closure) { b = { }; used = [ ]; } pattern);
  # The proof of a fact: a tree, and the same as indented lines.
  why = f: if closure ? ${show f} then proof (show f) else null;
  explain = f: concatStringsSep "\n" (lines 0 (proof (show f)));
}
