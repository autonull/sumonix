# Phase 5 — Build gate. Check a policy goal against the reasoning engine, and fail loudly with a proof.
#
#   check { goal; facts; rules; ontology ? null; passWhen ? "underivable" }
#     -> { pass; derived; goal; proof; tree; }
#
# passWhen = "underivable" (default): the gate fails iff the goal (e.g. a violation) is derivable.
# passWhen = "derivable": the gate fails iff the goal (e.g. a required property) is not derivable.
# Both polarities are checked by the same engine run; `proof` and `tree` are the 'why' subtree
# when the goal is derivable, or "underivable: ..." otherwise — the build-time version
# (mkPolicyChecked, below) prints whichever explains the verdict.
#
#   mkPolicyChecked { name ? "policy-checked"; goal; facts; rules; ontology ? null; passWhen ? "underivable"; pkgs ? null }
#     -> the derivation when the policy passes (this machine's store: build-time failure/success with the proof);
#        when no pkgs is given, evaluates now — a throw with the proof is the local gate.
{ pkgs ? null }:
let
  kif = import ../kif.nix;
  text = builtins.readFile;

  check = { goal, facts ? [ ], rules ? [ ], ontology ? null, passWhen ? "underivable" }:
    let
      engine = import ../datalog.nix { inherit ontology facts rules; };
      derived = engine.holds goal;
      pass = if passWhen == "derivable" then derived else !derived;
      proof = if derived then engine.explain goal else "goal underivable (passWhen = ${passWhen})";
      tree = engine.why goal;
    in {
      inherit pass derived goal passWhen proof tree;
      verdict = if pass then "pass" else "violation";
    };

  # Build-time gate: fails the derivation (printing the proof) when the policy does not hold,
  # or evaluates now when no pkgs is supplied — the local gate.
  mkPolicyChecked = { name ? "policy-checked", goal
    , facts ? [ ], rules ? [ ], ontology ? null, passWhen ? "underivable" }:
    let r = check { inherit goal facts rules ontology passWhen; };
    in
    if pkgs == null then
      (if r.pass then "pass" else builtins.throw "policy violation (${name}):\n${r.proof}")
    else
      pkgs.runCommand name { proofFile = builtins.toFile "proof.txt" r.proof; } (
        if r.pass
        then "echo ok > $out"
        else "cat $proofFile >&2; exit 1");

  # The CVE demo policy: nix-domain facts + user rules + ingested Merge rules + synthesis.
  cvePolicy =
    let
      cveFacts = kif.parse ''
        (instance hello NIXPackage)
        (instance curl NIXPackage)
        (instance nginx NIXPackage)
        (instance nginx NIXService)
        (instance glibc NIXPackage)
        (instance openssl NIXPackage)
        (instance app NIXPackage)
        (dependsOn curl openssl)
        (dependsOn nginx openssl)
        (dependsOn hello glibc)
        (dependsOn app curl)
        (vulnerable openssl CVE-2026-9999)
        (severity CVE-2026-9999 critical)
        (serviceState nginx running)
      '';
      cveRules = (builtins.filter (f: builtins.head f == "=>") (kif.parse (text ./../rules.kif)))
        ++ (import ../reasoner/ingest.nix { }).rules
        ++ (import ../reasoner/synthesize.nix { forms = kif.parse (text ../sumo.full/Merge.kif); }).rules;
      mergeForms = kif.parse (text ../sumo.full/Merge.kif);
      nixDomain = kif.parse (text ../nix-domain.kif);
      ontology = import ../sumo.nix { forms = mergeForms ++ nixDomain; };
    in
    check {
      goal = [ "policyViolation" "nginx" "NoCriticalRunningCVE" ];
      facts = cveFacts;
      rules = cveRules;
      ontology = ontology;
      passWhen = "underivable";
    };
in
{
  inherit check mkPolicyChecked cvePolicy;
}
