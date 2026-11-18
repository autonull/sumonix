# M4-lite — Repair, verified honestly.
#
#   repair = import ./reasoner/repair.nix { base; patched; candidates; };
#   repair.ranked     # verified candidates, ranked by `rank`
#   repair.rejected   # [ { name; reason; } ] — multi-path, uncontrolled, still failing
#   repair.best       # the top verified candidate, or null
#
# `base` is a lift result (facts/rules/ontology). `patched` is `edit -> lift`:
# the caller re-lifts a *real* patched config (extendModules / a fresh
# nixosSystem with the edit module). Facts are never hand-edited: every verdict
# comes from the re-lifted config, and the gate re-runs there.
#
# A candidate is { name; rank; edits = [ { optionPath; value; } ]; }.
# Exactly one edit is accepted (a single option path), and that path must
# control at least one declared fact. Rejected candidates carry a reason.
{ base, patched, candidates ? null }:
let
  kif = import ../lib/kif.nix { };
  inherit (kif) show headOf;

  inherit (builtins)
    any concatStringsSep deepSeq elem elemAt filter fromJSON head isString
    length listToAttrs map sort stringLength substring toJSON tryEval;

  gateOf = l: import ./config-gate.nix { inherit (l) facts rules ontology; };

  baseGate = gateOf base;

  q = s:
    let esc = builtins.replaceStrings [ "\\" "\"" "\n" ] [ "\\\\" "\\\"" " " ] (toString s);
    in "\"" + esc + "\"";

  unquote = s:
    if isString s && substring 0 1 s == "\"" && substring (stringLength s - 1) 1 s == "\""
    then substring 1 (stringLength s - 2) s
    else s;

  showValue = v: toJSON v;

  factsOf = x: base.facts;

  controlledBy = optionPath:
    let path = q optionPath; in
    filter (f: elem path f) base.facts;

  currentAllowedPorts =
    map (f: fromJSON (unquote (elemAt f 1)))
      (filter (f: headOf f == "firewallTcpAllowed") base.facts);

  currentValue = optionPath:
    let fs = controlledBy optionPath; in
    if fs == [ ] then "(unset)"
    else if optionPath == "networking.firewall.allowedTCPPorts" then showValue currentAllowedPorts
    else if any (f: headOf f == "declaredService" || headOf f == "declaredRunning") fs then "true"
    else if any (f: headOf f == "listenerDeclared" || headOf f == "listenerInferred") fs then
      (let f = head (filter (x: headOf x == "listenerDeclared" || headOf x == "listenerInferred") fs);
       in showValue (unquote (elemAt f 2)))
    else if any (f: headOf f == "portDeclared" || headOf f == "portInferred") fs then
      (let f = head (filter (x: headOf x == "portDeclared" || headOf x == "portInferred") fs);
       in showValue (fromJSON (unquote (elemAt f 2))))
    else "(see proof)";

  diffOf = edit:
    "--- a/configuration.nix\n"
    + "+++ b/configuration.nix\n"
    + "@@ " + edit.optionPath + " @@\n"
    + "-  " + edit.optionPath + " = " + currentValue edit.optionPath + ";\n"
    + "+  " + edit.optionPath + " = " + showValue edit.value + ";";

  showSet = fs: listToAttrs (map (f: { name = show f; value = f; }) fs);
  factDiff = before: after:
    let
      b = showSet before;
      a = showSet after;
    in {
      removed = filter (n: !(a ? ${n})) (builtins.attrNames b);
      added = filter (n: !(b ? ${n})) (builtins.attrNames a);
    };

  # The default candidates for a NoFirewallAllowance violation: allow the port
  # (rank 1) or disable the service (rank 3). The caller may supply candidates
  # (e.g. bind the listener to localhost) instead.
  defaultCandidates =
    if baseGate.violations == [ ] then [ ]
    else
      let
        v = head baseGate.violations;
        svc = elemAt v.goal 1;
        reason = elemAt v.goal 2;
        portFacts = filter
          (f: (headOf f == "portInferred" || headOf f == "portDeclared") && elemAt f 1 == svc)
          base.facts;
        port = if portFacts == [ ] then null else fromJSON (unquote (elemAt (head portFacts) 2));
        enableFact = head (filter
          (f: headOf f == "declaredService" && elemAt f 1 == svc)
          base.facts);
        enablePath = unquote (elemAt enableFact 2);
        ports = if port == null then currentAllowedPorts else
          currentAllowedPorts ++ (if elem port currentAllowedPorts then [ ] else [ port ]);
      in
      if reason != "NoFirewallAllowance" then [ ]
      else
        (if port == null then [ ] else [
          {
            name = "allow port " + toString port + " in the firewall";
            rank = 1;
            edits = [ { optionPath = "networking.firewall.allowedTCPPorts"; value = ports; } ];
          }
        ]) ++ [
          {
            name = "disable " + unquote svc;
            rank = 3;
            edits = [ { optionPath = enablePath; value = false; } ];
          }
        ];

  chosen = if candidates != null then candidates else defaultCandidates;

  attempt = c:
    let
      edits = c.edits or [ ];
      oneEdit = length edits == 1;
      edit = if oneEdit then head edits else null;
      fs = if oneEdit then controlledBy edit.optionPath else [ ];
      controlled = fs != [ ];
      result =
        if !oneEdit || !controlled then null
        else
          let
            pl = patched edit;
            pg = gateOf pl;
            p = tryEval (deepSeq pg pg);
          in
          if !p.success then null
          else { inherit pl; pg = p.value; };
      verified = result != null && result.pg.pass;
    in
    if !oneEdit then
      { inherit (c) name rank; verified = false; reason = "multi-path edit (exactly one option path required)"; }
    else if !controlled then
      { inherit (c) name rank; verified = false; reason = "no declared fact controlled by " + edit.optionPath; }
    else if result == null then
      { inherit (c) name rank; verified = false; reason = "re-lift failed (unknown option or eval error)"; }
    else {
      inherit (c) name rank;
      inherit verified;
      edits = [ edit ];
      diff = diffOf edit;
      proof = result.pg.proof;
      factDiff = factDiff base.facts result.pl.facts;
      gate = result.pg;
      reason = if verified then "" else "still violates: " + result.pg.proof;
    };

  attempts = map attempt chosen;
  ranked = sort
    (a: b: a.rank < b.rank || (a.rank == b.rank && a.name < b.name))
    (filter (c: c.verified) attempts);
in
{
  inherit attempts ranked baseGate;
  rejected = filter (c: !c.verified) attempts;
  best = if ranked == [ ] then null else head ranked;
  count = {
    candidates = length attempts;
    verified = length ranked;
    rejected = length (filter (c: !c.verified) attempts);
  };
  checked = { inherit (baseGate) pass proof; };
}
