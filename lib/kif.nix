# Shared KIF helpers for sumo-nix.
# Exports: parse, tokens, show, headOf, flatten, subforms, isVar, isEngineVar, ground, subst, varsOf, unique, count, isKifOp.
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

  # --- Shared KIF helpers ---
  # Show a KIF form: strings and integers render directly; lists render as parenthesized.
  show = s:
    if isString s then s
    else if typeOf s == "int" then toString s
    else "(" + concatStringsSep " " (map show s) + ")";

  # Head of a list form, empty string otherwise.
  headOf = f: if isList f && f != [ ] then head f else "";

  # Flatten a nested list structure into a flat list of atoms.
  flatten = f: if isList f then concatMap flatten f else [ f ];

  # All subforms of a form (including itself), deepest first.
  subforms = f: if isList f then [ f ] ++ concatMap subforms (tail f) else [ ];

  # Engine variables: atoms starting with "?" only.
  isEngineVar = s: isString s && substring 0 1 s == "?";

  # Reasoner variables: atoms starting with "?" or "@".
  isVar = s: isString s && (substring 0 1 s == "?" || substring 0 1 s == "@");

  # A form is ground if it contains no variables (either engine or reasoner).
  ground = s:
    if isString s then !isVar s
    else all ground s;

  # Substitute variables in a form under bindings b.
  subst = b: s:
    if isString s then
      if isVar s then b.${s} or s else s
    else map (subst b) s;

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
in
{
  inherit parse tokens show headOf flatten subforms isVar isEngineVar ground subst varsOf unique count isKifOp;
}