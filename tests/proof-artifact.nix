# Generates proof.kif — the certificate for the CVE scenario with ingestion on.
# Deterministic: same inputs => byte-identical output. Used by tests/proof-check.nix.
# Usage: nix --extra-experimental-features nix-command eval --impure --raw --expr 'import ./tests/proof-artifact.nix' > proof.kif
let
  kif = import ../kif.nix;
  text = builtins.readFile;
  facts = kif.parse ''
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
  ontology = import ../sumo.nix {
    forms = kif.parse (text ../sumo.full/Merge.kif) ++ kif.parse (text ../nix-domain.kif);
  };
  userRules = builtins.filter (f: builtins.head f == "=>") (kif.parse (text ../rules.kif));
  ingest = import ../reasoner/ingest.nix { };
  synth = import ../reasoner/synthesize.nix { forms = kif.parse (text ../sumo.full/Merge.kif); };
in
import ../reasoner/proof.nix {
  inherit ontology facts;
  rules = userRules ++ ingest.rules ++ synth.rules;
  goal = [ "policyViolation" "nginx" "NoCriticalRunningCVE" ];
}
