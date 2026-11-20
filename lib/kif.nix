# Shared KIF helpers for sumo-nix.
# Exports: parse, tokens, show, headOf, flatten, subforms, isVar, isEngineVar, ground, subst, varsOf, unique, count, isKifOp, FactMeta, FactEnvelope.
# Type-aware `show` (isString → s, isInt → toString s, else the list) so one `show` serves
# relax.nix / soft-rules.nix and future predicates (gzip-1.13 would have rendered as gzip
# with the string-only body: that is allowed only as an unused variant).
{ }:
let
  inherit (builtins)
    all any attrNames concatMap elem elemAt filter foldl' genList head isList isString
    length listToAttrs map sort tail substring toString typeOf split;

  concatStringsSep = builtins.concatStringsSep;

  # --- KIF parser (from original kif.nix) ---
  tokenPattern = ''([()]|"([^"\\]|\\.)*"|;[^
]*|[^ 	
()";]+)'';

  tokens = text:
    filter (t: substring 0 1 t != ";")
      (map head (filter isList (split tokenPattern text)));

  reverse = xs: let n = length xs; in genList (i: elemAt xs (n - 1 - i)) n;

  step = st: t:
    let
      r =
        if t == "(" then { cur = [ ]; up = [ st.cur ] ++ st.up; }
        else if t == ")" then
          if st.up == [ ] then throw "kif: unbalanced ')'"
          else { cur = [ (reverse st.cur) ] ++ head st.up; up = tail st.up; }
        else { cur = [ t ] ++ st.cur; up = st.up; };
    in builtins.seq r.cur (builtins.seq r.up r);

  parse = text:
    let end = foldl' step { cur = [ ]; up = [ ]; } (tokens text); in
    if end.up != [ ] then throw "kif: unclosed '('" else reverse end.cur;

  # Default FactMeta for backward compatibility
  defaultMeta = {
    sourceClass = "fixture";
    sourceId = "legacy";
    observedAt = 0;
    expiresAt = 0;
    snapshotId = "";
    contentHash = "";
    confidence = 1.0;
    provenance = [ ];
  };

  # Create a FactEnvelope from a fact and optional meta
  makeEnvelope = fact: meta:
    { fact = fact; meta = if meta == null then defaultMeta else meta; };

  # Get fact from envelope (or bare fact)
  getFact = x:
    if isList x then x
    else if x ? fact then x.fact
    else x;

  # Get meta from envelope (or default)
  getMeta = x:
    if isList x then defaultMeta
    else if x ? meta then x.meta
    else defaultMeta;

  # Check if x is an envelope
  isEnvelope = x: isList x == false && x ? fact && x ? meta;

  # --- Shared KIF helpers ---
  # Show a KIF form: strings and integers render directly; lists render as parenthesized.
  # If envelope has meta, emit: (fact) { meta: { ... } }
  show = x:
    let
      fact = getFact x;
      meta = getMeta x;
      factStr =
        if isString fact then fact
        else if typeOf fact == "int" then toString fact
        else "(" + concatStringsSep " " (map (y: show (makeEnvelope y null)) fact) + ")";
      metaStr =
        "meta: { " + concatStringsSep ", " (map (k:
          let v = meta.${k}; in
          k + ": " + (if isString v then "\"" + v + "\"" else if typeOf v == "int" || typeOf v == "float" then toString v else if isList v then "[" + concatStringsSep " " (map (z: "\"" + z + "\"") v) + "]" else toString v)
        ) (attrNames meta)) + " }";
    in factStr + " { " + metaStr + " }";

  # Show fact only (without meta) - for internal use
  showFact = f:
    if isString f then f
    else if typeOf f == "int" then toString f
    else "(" + concatStringsSep " " (map showFact f) + ")";

  # Head of a list form, empty string otherwise.
  headOf = f:
    let realFact = getFact f; in
    if isList realFact && realFact != [ ] then head realFact else "";

  # Flatten a nested list structure into a flat list of atoms.
  flatten = f:
    let realFact = getFact f; in
    if isList realFact then concatMap flatten realFact else [ realFact ];

  # All subforms of a form (including itself), deepest first.
  subforms = f:
    let realFact = getFact f; in
    if isList realFact then [ realFact ] ++ concatMap subforms (tail realFact) else [ ];

  # Engine variables: atoms starting with "?" only.
  isEngineVar = s: isString s && substring 0 1 s == "?";

  # Reasoner variables: atoms starting with "?" or "@".
  isVar = s: isString s && (substring 0 1 s == "?" || substring 0 1 s == "@");

  # A form is ground if it contains no variables (either engine or reasoner).
  ground = s:
    let realFact = getFact s; in
    if isString realFact then !isVar realFact
    else all ground realFact;

  # Substitute variables in a form under bindings b.
  subst = b: s:
    let realFact = getFact s; in
    if isString realFact then
      if isVar realFact then b.${realFact} or realFact else realFact
    else map (subst b) realFact;

  # Variables appearing in a form (both ? and @).
  varsOf = f: filter isVar (flatten f);

  # Deduplicate a list of strings/ints using attribute-set keys (hash-name dedupe).
  unique = xs:
    attrNames (foldl' (m: x:
      if isString x || typeOf x == "int" then m // { ${toString x} = x; } else m
    ) { } xs);

  # Count occurrences of each element in a list.
  count = xs: foldl' (m: x: m // { ${x} = (m.${x} or 0) + 1; }) { } xs;

  # Check if a symbol is a KIF structural operator.
  isKifOp = h: elem h [ "and" "or" "not" "exists" "forall" "<=>" "=>" ];

  # FactMeta schema (documentation)
  FactMeta = {
    sourceClass = "string";  # "declared" | "inferred" | "observed" | "fixture" | "derived"
    sourceId = "string";
    observedAt = "int";
    expiresAt = "int";
    snapshotId = "string";
    contentHash = "string";
    confidence = "float";
    provenance = "list";
  };

  # FactEnvelope: { fact: list; meta: FactMeta }
  FactEnvelope = {
    fact = "list";
    meta = FactMeta;
  };
in
{
  inherit parse tokens show showFact headOf flatten subforms isVar isEngineVar ground subst varsOf unique count isKifOp;
  inherit FactMeta FactEnvelope defaultMeta makeEnvelope getFact getMeta isEnvelope;
}