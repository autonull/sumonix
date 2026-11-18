# M0.2 — located KIF diagnostics.
#
#   diag = import ./lib/kif-diag.nix { };
#   diag.diagnose { file = "facts.kif"; text = builtins.readFile "facts.kif"; domains = ontology.domains; }
#   # => { ok; forms; errors; warnings; text; }
#
# The scanner tracks tokens with 1-based line/column positions, so a syntax
# error reads `file:line:col: error: ...` and never a Nix stack trace. Unknown
# predicates are reported only when a near-miss exists (a typo), so legitimate
# extension predicates stay silent.
{ }:
let
  inherit (builtins)
    abs attrNames concatMap concatStringsSep elem elemAt filter foldl' genList
    head isList isString length sort split stringLength substring;

  kif = import ./kif.nix { };
  inherit (kif) parse;

  tokenPattern = "([()]|\"([^\"\\\\]|\\\\.)*\"|;[^\n]*|[^ \t\n()\";]+)";

  # Structural and declaration heads that are not relations with domains.
  structural = [
    "and" "or" "not" "exists" "forall" "<=>" "=>" "equal"
    "instance" "subclass" "domain" "range" "disjoint" "equivalent"
    "policyGoal" "rule"
  ];

  hasQuote = s: length (split "\"" s) > 1;
  quoteAt = s: stringLength (head (split "\"" s));
  min2 = a: b: if a < b then a else b;
  absDiff = a: b: let d = a - b; in if d < 0 then -d else d;

  scanLine = lineNo: st0: line:
    let
      parts = split tokenPattern line;
      step = st: part:
        if isString part then
          if hasQuote part then
            st // {
              errors = st.errors ++ [ {
                inherit (st) line;
                col = st.col + quoteAt part;
                msg = "unterminated string literal";
              } ];
              col = st.col + stringLength part;
              pending = null;
            }
          else st // { col = st.col + stringLength part; }
        else
          let tok = head part; in
          if tok == "(" then
            st // {
              stack = st.stack ++ [ { inherit (st) line; col = st.col; } ];
              pending = { inherit (st) line; col = st.col; };
              col = st.col + 1;
            }
          else if tok == ")" then
            if st.stack == [ ] then
              st // {
                errors = st.errors ++ [ { inherit (st) line; col = st.col; msg = "unbalanced ')'"; } ];
                pending = null;
                col = st.col + 1;
              }
            else
              st // {
                stack = genList (i: elemAt st.stack i) (length st.stack - 1);
                pending = null;
                col = st.col + 1;
              }
          else if substring 0 1 tok == ";" then
            st // { col = st.col + stringLength tok; pending = null; }
          else
            let headPos = st.pending; in
            st // {
              col = st.col + stringLength tok;
              pending = null;
              heads = st.heads ++ (if headPos == null then [ ] else [ ({ head = tok; } // headPos) ]);
            };
    in
    foldl' step (st0 // { line = lineNo; col = 1; pending = null; }) parts;

  scan = text:
    let
      lines = filter isString (split "\n" text);
      step = st: line: (scanLine st.n st line) // { n = st.n + 1; };
      final = foldl' step {
        n = 1;
        line = 1;
        col = 1;
        stack = [ ];
        pending = null;
        heads = [ ];
        errors = [ ];
      } lines;
      inner = if final.stack == [ ] then null else elemAt final.stack (length final.stack - 1);
      unclosed = if inner == null then [ ] else [ { inherit (inner) line col; msg = "unclosed '('"; } ];
    in {
      errors = final.errors ++ unclosed;
      heads = final.heads;
    };

  charAt = s: i: substring i 1 s;

  # Levenshtein distance, used only for typo suggestions.
  lev = a: b:
    let
      n = stringLength a;
      m = stringLength b;
      initial = genList (j: j) (m + 1);
      row = i: prev:
        foldl' (acc: j:
          if j == 0 then [ i ]
          else
            let
              del = elemAt acc (j - 1) + 1;
              ins = elemAt prev j + 1;
              sub = elemAt prev (j - 1) + (if charAt a (i - 1) == charAt b (j - 1) then 0 else 1);
            in acc ++ [ (min2 del (min2 ins sub)) ]
        ) [ ] (genList (j: j) (m + 1));
      rows = foldl' (prev: i: row i prev) initial (genList (i: i + 1) n);
    in elemAt rows m;

  # Candidate set: same first letter and length within one, which covers the
  # common typos (missing/extra/substituted/swapped characters).
  suggestFor = names: h:
    let
      len = stringLength h;
      first = charAt h 0;
      cands = filter
        (k: stringLength k > 1 && first == charAt k 0 && absDiff len (stringLength k) <= 1)
        names;
      scored = map (k: { inherit k; d = lev h k; }) cands;
      best = filter (c: c.d <= 2) scored;
      ranked = sort (x: y: x.d < y.d || (x.d == y.d && x.k < y.k)) best;
    in if ranked == [ ] then null else (head ranked).k;

  declaredHere = forms:
    map
      (f: elemAt f 1)
      (filter (f: isList f && length f >= 2 && head f == "domain") forms);

  at = file: lineNo: col: msg:
    "${file}:${toString lineNo}:${toString col}: ${msg}";

  headWarnings = { file, heads, known }:
    concatMap
      (h:
        if elem h.head known then [ ]
        else
          let s = suggestFor known h.head; in
          if s == null then [ ]
          else [ (at file h.line h.col "warning: unknown predicate '${h.head}' (did you mean '${s}'?)") ])
      heads;

  diagnose = { file ? "kif", text, domains ? { } }:
    let
      scanResult = scan text;
      parsed = if scanResult.errors == [ ] then parse text else [ ];
      ontologyKnown = attrNames domains;
      known = structural ++ ontologyKnown ++ declaredHere parsed;
      errors = map
        (e: at file e.line e.col ("error: " + e.msg))
        scanResult.errors;
      warnings =
        if scanResult.errors == [ ] then
          headWarnings { inherit file; heads = scanResult.heads; inherit known; }
        else [ ];
      all = errors ++ warnings;
    in {
      ok = all == [ ];
      inherit errors warnings all;
      forms = length parsed;
      text = concatStringsSep "\n" all;
    };
in
{
  inherit diagnose scan lev;
}
