# Declaration-driven Horn synthesis: rules generated from SUMO's own declarations.
#
#   synthesize { forms; } -> { rules; rejected; diagnostics; }
#
# rules are (=> ...) forms, ready for datalog.nix. Every declaration that cannot
# yield a safe rule is refused with a reason, never dropped silently.
#
# Declarations handled:
#   (instance R TransitiveRelation)  =>  (=> (and (R ?a ?b) (R ?b ?c)) (R ?a ?c))   (binary R only)
#   (instance R SymmetricRelation)   =>  (=> (R ?a ?b) (R ?b ?a))                   (binary R)
#   (instance R ReflexiveRelation)   =>  (=> (instance ?x D) (R ?x ?x))            (D = position-1 domain; else rejected)
#   (subrelation R S)                =>  (=> (R v1 .. vn) (S v1 .. vn))            (arity from predicate class, else domain/range positions)
#   (inverse R S)                    =>  (=> (R ?a ?b) (S ?b ?a)) and (=> (S ?a ?b) (R ?b ?a))
#   (subAttribute A B)               =>  (=> (A ?x) (B ?x))                        (attributes applied unary)
#
# Exact-duplicate synthesized rules are kept once; the rest are listed under `redundant`.
# `equivalent` forms are consumed by the ontology layer (sumo.nix), not turned into rules.
{ forms ? [ ] }:
let
  inherit (builtins) all any attrNames concatMap elem elemAt filter foldl' genList head isList isString length listToAttrs map sort tail;

  headOf = f: if isList f && f != [ ] then head f else "";
  show = s: if isString s then s else "(" + concatStringsSep " " (map show s) + ")";
  concatStringsSep = builtins.concatStringsSep;
  count = xs: foldl' (m: x: m // { ${x} = (m.${x} or 0) + 1; }) { } xs;
  unique = xs: attrNames (count xs);
  top = name: filter (f: isList f && f != [ ] && head f == name) forms;
  isIntStr = s: isString s && builtins.match "[0-9]+" s != null;
  toInt = s: if builtins.isInt s then s else if isIntStr s then builtins.fromJSON s else 0;

  instanceDecls = top "instance";
  domainForms = top "domain";
  rangeForms = top "range";

  # R -> all its classes, from (instance R Class) forms.
  classesOf = listToAttrs (map
    (R: { name = R; value = unique (map (f: elemAt f 2) (filter (f: elemAt f 1 == R) instanceDecls)); })
    (unique (map (f: elemAt f 1) instanceDecls)));

  # Arity: from the predicate-class instances, else from the highest declared domain/range position.
  predicateArity = { UnaryPredicate = 1; BinaryPredicate = 2; TernaryPredicate = 3; QuaternaryPredicate = 4; };
  fromClass = R:
    let ns = filter (n: n != null) (map (c: predicateArity.${c} or null) (classesOf.${R} or [ ]));
    in if ns == [ ] then null else head (sort builtins.lessThan ns);
  maxPosition = R:
    let pos = map (f: toInt (elemAt f 2))
      (filter (f: (head f == "domain" || head f == "range") && length f >= 3 && elemAt f 1 == R) (domainForms ++ rangeForms));
    in if pos == [ ] then 0 else builtins.foldl' (a: b: if a > b then a else b) 0 pos;
  arityOf = R:
    let c = fromClass R; p = maxPosition R;
    in if c != null then c else if p > 0 then p else null;

  # The position-1 domain class of R, if declared.
  domain1 = R:
    let ds = filter (f: head f == "domain" && length f >= 4 && elemAt f 1 == R && toInt (elemAt f 2) == 1) domainForms;
    in if ds == [ ] then null else elemAt (head ds) 3;

  varN = n: "?v${toString n}";
  args = n: genList varN n;
  atom = R: n: [ R ] ++ args n;

  read = decl:
    let h = headOf decl; showDecl = show decl; in
    if h == "instance" then
      let R = elemAt decl 1; c = elemAt decl 2; in
      if c == "TransitiveRelation" then
        let n = arityOf R; in
        if n == null then [ { declaration = showDecl; rejected = "unknown-arity"; } ]
        else if n != 2 then [ { declaration = showDecl; rejected = "non-binary-transitive"; } ]
        else [ { declaration = showDecl;
                 rules = [ [ "=>" [ "and" [ R "?a" "?b" ] [ R "?b" "?c" ] ] [ R "?a" "?c" ] ] ]; } ]
      else if c == "SymmetricRelation" then
        let n = arityOf R; in
        if n != null && n != 2 then [ { declaration = showDecl; rejected = "non-binary-symmetric"; } ]
        else [ { declaration = showDecl; rules = [ [ "=>" [ R "?a" "?b" ] [ R "?b" "?a" ] ] ]; } ]
      else if c == "ReflexiveRelation" then
        let d = domain1 R; in
        if d == null then [ { declaration = showDecl; rejected = "reflexive-no-domain"; } ]
        else [ { declaration = showDecl; rules = [ [ "=>" [ "instance" "?x" d ] [ R "?x" "?x" ] ] ]; } ]
      else [ ]
    else if h == "subrelation" then
      let R = elemAt decl 1; S = elemAt decl 2; n = arityOf R; m = arityOf S; in
      if n == null then [ { declaration = showDecl; rejected = "unknown-arity"; } ]
      else if m != null && m != n then [ { declaration = showDecl; rejected = "arity-mismatch"; } ]
      else [ { declaration = showDecl; rules = [ [ "=>" (atom R n) (atom S n) ] ]; } ]
    else if h == "inverse" then
      let R = elemAt decl 1; S = elemAt decl 2; n = arityOf R; m = arityOf S; in
      if n != null && n != 2 then [ { declaration = showDecl; rejected = "non-binary-inverse"; } ]
      else if m != null && m != 2 then [ { declaration = showDecl; rejected = "arity-mismatch"; } ]
      else
        [ { declaration = showDecl;
            rules = [ [ "=>" [ R "?a" "?b" ] [ S "?b" "?a" ] ]
                    [ "=>" [ S "?a" "?b" ] [ R "?b" "?a" ] ] ]; } ]
    else if h == "subAttribute" then
      let A = elemAt decl 1; B = elemAt decl 2; in
      [ { declaration = showDecl; rules = [ [ "=>" [ A "?x" ] [ B "?x" ] ] ]; } ]
    else if h == "domainSubclass" || h == "rangeSubclass" then
      [ { declaration = showDecl; rejected = "typing-declaration"; } ]
    else
      [ { declaration = showDecl; rejected = "unsupported-declaration"; } ];

  relevant = concatMap top
    [ "instance" "subrelation" "inverse" "subAttribute"
      "successorAttribute" "contraryAttribute" "exhaustiveAttribute"
      "domainSubclass" "rangeSubclass" ];
  classified = concatMap read relevant;
  rejected = map (c: { declaration = c.declaration; reason = c.rejected; }) (filter (c: c ? rejected) classified);
  rules0 = concatMap (c: c.rules or [ ]) classified;

  # Refuse exact duplicates; the first synthesis wins, the rest are reported redundant.
  dedupe = xs:
    let go = acc: ys:
      if ys == [ ] then acc
      else
        let s = show (head ys);
        in if elem s acc.texts then go { texts = acc.texts; out = acc.out ++ [ { rule = head ys; redundant = true; } ]; } (tail ys)
           else go { texts = acc.texts ++ [ s ]; out = acc.out ++ [ { rule = head ys; redundant = false; } ]; } (tail ys);
    in (go { texts = [ ]; out = [ ]; } xs).out;
  deduped = dedupe rules0;
  kept = map (r: r.rule) (filter (r: !r.redundant) deduped);
  redundant = map (r: show r.rule) (filter (r: r.redundant) deduped);

in
{
  rules = kept;
  inherit rejected;
  diagnostics = {
    synthesized = length kept;
    rejected = length rejected;
    redundant = length redundant;
    byReason = count (map (r: r.reason) rejected);
    rules = map show kept;
  };
}
