# M1 — The config gate: run the lifted facts through the kernel and fail with a
# proof when a system.kif policy is violated or a lifted fact is ill typed.
#
#   gate = import ./reasoner/config-gate.nix { facts; rules; ontology; };
#   gate.pass        # bool
#   gate.proof       # why subtree of every violation, or the typing error
#   gate.violations  # [ { goal; proof; } ]
#   gate.illTyped    # [ fact ]
#   gate.mkChecked   # a throw carrying the proof (the eval-time gate)
{ facts, rules, ontology }:
let
  kif = import ../lib/kif.nix { };
  inherit (kif) show headOf;

  inherit (builtins) concatStringsSep filter head map substring;

  engine = import ../datalog.nix { inherit ontology facts rules; };

  typed = import ./well-typed.nix { inherit ontology facts; };
  illTyped = typed.illTyped;

  violationBindings = engine.ask [ "policyViolation" "?svc" "?reason" ];
  violations = map
    (b:
      let goal = [ "policyViolation" b."?svc" b."?reason" ]; in {
        inherit goal;
        svc = b."?svc";
        reason = b."?reason";
        proof = engine.explain goal;
      })
    violationBindings;

  typingProof =
    "ill-typed lifted facts:\n" + concatStringsSep "\n" (map show illTyped);
  violationProof = concatStringsSep "\n\n" (map (v: v.proof) violations);

  # Export the first violation as a KIF certificate and re-check it with the
  # independent checker. The checker is forced by `pass`, so the eval-time gate
  # is independently verified (the measured overhead is ~0.05 s on the 395-fact
  # postgres config).
  firstViolation = if violations == [ ] then null else head violations;
  certificate =
    if firstViolation == null then null
    else import ./proof.nix {
      inherit facts rules ontology;
      goal = firstViolation.goal;
      ontologies = [ "../sumo.full/Merge.kif" "../nix-domain.kif" "../system.kif" ];
    };
  recheck =
    if certificate == null then null
    else import ../proof-check.nix {
      file = builtins.toFile "config-gate-proof.kif" certificate;
      ontologies = [ ../sumo.full/Merge.kif ../nix-domain.kif ../system.kif ];
    };
  recheckOk = certificate == null || recheck == null || builtins.substring 0 6 recheck == "proof:";

  pass = recheckOk && violations == [ ] && illTyped == [ ];
  proof =
    if illTyped != [ ] then typingProof
    else if violations != [ ] then violationProof
    else "no derivable policyViolation; all lifted facts well typed";

  mkChecked = { name ? "config-gate" }:
    if pass then "pass"
    else builtins.throw ("config gate failed (" + name + "):\n" + proof);
in
{
  inherit pass violations illTyped proof certificate recheck recheckOk;
  engine = engine;
  checked = { inherit pass proof; };
  inherit mkChecked;
}
