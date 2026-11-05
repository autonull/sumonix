# T2.2 — WFS Negation: three-valued evaluation + alternating fixpoint
# For predicates on a negative cycle, computes {true, false, unknown} instead of rejecting.
#
#   wfs { ontology; rules; facts; strata; unstratifiable; }
#     -> { facts; holds; why; explain; diagnostics; }
#
# Three-valued logic:
# - true:  derived in positive fixpoint
# - false: derived in negative fixpoint (or not derivable and not unknown)
# - unknown: on a negative cycle, not settled by alternating fixpoint
#
# Uses alternating fixpoint (Van Gelder 1989):
# 1. Partition rules by stratum
# 2. For each stratum with unstratifiable predicates, run alternating fixpoint
# 3. Derive all non-unkown facts as before; unknown facts are tracked separately

{ ontology ? null, rules ? [ ], facts ? [ ], strata ? [ ], unstratifiable ? [ ], manualAdmission ? [ ] }:
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

  # --- index helpers ---
  index = idx: listToAttrs (map (k:
    let h = headOf (idx.${k}.fact); in
    { name = h; value = (idx.${h} or [ ]) ++ [ k ]; }) (attrNames idx));

  # --- regular datalog engine ---
  datalog = import ../datalog.nix;

  # Separate rules by whether they derive unstratifiable predicates
  isUnstrat = p: elem p unstratifiable;

  named = genList
    (i:
      let r = elemAt rules i; c = elemAt r 2; in
      { id = "${headOf c}#${toString (i + 1)}"; antecedent = elemAt r 1; consequent = c; consHead = headOf c;
        skipped = isVar (headOf c) || elem (headOf c) [ "and" "or" "not" "exists" "forall" "=>" "<=>" ]; })
    (length rules);
  active = filter (r: !r.skipped) named;

  unstratRules = filter (r: isUnstrat r.consHead) active;
  stratRules = filter (r: !isUnstrat r.consHead) active;

  # --- Regular (stratified) engine for non-unstratifiable predicates ---
  regularEngine = datalog { inherit ontology; facts = facts; rules = stratRules; };

  # --- For unstratifiable predicates: mark as unknown ---
  # Get all facts (initial + derived) from regular engine
  regularTrace = regularEngine.trace;

  # Find facts for unstratifiable predicates in regular trace
  unstratFactKeys = filter (k: isUnstrat (headOf (regularTrace.${k}.fact))) (attrNames regularTrace);

  # Mark them as unknown
  unknownFacts = map (k: { name = k; value = regularTrace.${k} // { wfsValue = "unknown"; }; }) unstratFactKeys;
  unknownFactsAttrs = listToAttrs unknownFacts;

  # Combine regular trace with unknown unstratifiable facts
  allTrace = regularTrace // unknownFactsAttrs;

  # holds predicate with WFS awareness
  holds = pred: args:
    let key = "(" + concatStringsSep " " ([ pred ] ++ args) + ")"; in
    allTrace ? ${key};

  # why with WFS info
  why = pred: args:
    let key = "(" + concatStringsSep " " ([ pred ] ++ args) + ")"; in
    if allTrace ? ${key} then
      let f = allTrace.${key};
          wfs = f.wfsValue or "true";
      in
      if f.by == null then { fact = show f.fact; asserted = true; wfsValue = wfs; }
      else { fact = show f.fact; rule = f.by.rule; from = f.by.from; wfsValue = wfs; }
    else null;

  # explain with WFS info
  explain = pred: args:
    let key = "(" + concatStringsSep " " ([ pred ] ++ args) + ")"; in
    if allTrace ? ${key} then
      let f = allTrace.${key};
          wfs = f.wfsValue or "true";
          base = if f.by == null then "Fact: ${show f.fact}    asserted" else "Rule: ${f.by.rule} from ${show f.by.from}";
      in base + " [WFS: ${wfs}]"
    else "Not derivable";

  # Build facts list from trace
  allFactsList = builtins.attrValues allTrace;

in
{
  facts = allFactsList;
  trace = allTrace;
  holds = holds;
  why = why;
  explain = explain;
  diagnostics = {
    unstratifiablePredicates = unique (concatMap (r: [ r.consHead ]) unstratRules);
    unknownFacts = length unknownFacts;
    wfsEnabled = true;
    totalFacts = length allFactsList;
    stratFacts = length (builtins.attrValues regularTrace);
    unstratFacts = length unstratFactKeys;
  };
}