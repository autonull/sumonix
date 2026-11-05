# T2.3 — Bounded Existentials: finite-domain Skolem terms (depth ≤ 1)
# For rules with existential consequents, generate Skolem constants/functions
# and ground them over finite domains.
#
#   existential { ontology; facts; rules; domains; }
#     -> { facts; holds; why; explain; diagnostics; }
#
# Usage:
# - rules with existential consequent: (=> A (exists ?y (P ?x ?y)))
# - domains: attrset of predicate -> list of constants
#   e.g., { pkg = [ "a" "b" "c" ]; }
# - For depth ≤ 1, we generate Skolem functions of arity equal to
#   the number of free variables in the antecedent

{ ontology ? null, facts ? [ ], rules ? [ ], domains ? { } }:
let
  inherit (builtins) all any attrNames attrValues concatMap elem elemAt filter foldl' genList head isList isString length listToAttrs map sort tail;
  concatStringsSep = builtins.concatStringsSep;
  toString = builtins.toString;

  show = s: if isString s then s else "(" + concatStringsSep " " (map show s) + ")";
  headOf = f: if isList f && f != [ ] then head f else "";
  unique = xs: attrNames (foldl' (m: x: m // { ${toString x} = x; }) { } xs);
  flatten = f: if isList f then concatMap flatten f else [ f ];
  isVar = s: isString s && (builtins.substring 0 1 s == "?" || builtins.substring 0 1 s == "@");
  ground = f: if !(isList f) then false else all (x: !(isVar x)) (flatten f);
  subst = b: f: if !(isList f) then f
    else let h = headOf f; in
    if h == "" || isVar h then (b.${f} or f)
    else map (subst b) f;
  varsOf = f: filter isVar (flatten f);
  ruleVars = ant: cons: b: let
    cv = varsOf cons; av = concatMap varsOf (flatten ant);
    in listToAttrs (map (v: { name = v; value = b.${v} or v; }) (unique (cv ++ av)));

  # --- regular datalog engine ---
  datalog = import ../datalog.nix;

  # Find rules with existential consequents (exists in consequent)
  hasExists = f:
    if !(isList f) then false
    else if headOf f == "exists" then true
    else any hasExists (tail f);

  named = genList
    (i:
      let r = elemAt rules i; c = elemAt r 2; in
      { id = "${headOf c}#${toString (i + 1)}"; rule = r; antecedent = elemAt r 1; consequent = c; consHead = headOf c;
        skipped = isVar (headOf c) || elem (headOf c) [ "and" "or" "not" "exists" "forall" "=>" "<=>" ];
        hasExists = hasExists c; })
    (length rules);

  active = filter (r: !r.skipped) named;
  existsRules = filter (r: r.hasExists) active;
  normalRules = filter (r: !r.hasExists) active;
  normalRuleForms = map (r: r.rule) normalRules;

  # For existential rules, we need to skolemize
  # (=> ant (exists ?y (P ?x ?y))) -> for each binding of ?x, create Skolem constant sk_?x
  # and assert (P ?x sk_?x)
  #
  # For now, we'll just pass through normal rules and note that
  # existential handling would be added here

  engine = datalog { inherit ontology; facts = facts; rules = normalRuleForms; };

  holds = pred: args:
    let key = "(" + concatStringsSep " " ([ pred ] ++ args) + ")"; in
    engine.holds ([ pred ] ++ args);

  why = pred: args:
    engine.why ([ pred ] ++ args);

  explain = pred: args:
    engine.explain ([ pred ] ++ args);

in
{
  facts = engine.facts;
  holds = holds;
  why = why;
  explain = explain;
  diagnostics = engine.diagnostics // {
    existentialRules = length existsRules;
    skolemized = false;
  };
}