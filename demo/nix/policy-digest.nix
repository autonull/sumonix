# Policy demo: the build gate fails with a proof — and the relaxation menu
# shows exactly which override flips the verdict.
let
  kif = import ../../kif.nix;
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
  ontology = import ../../sumo.nix {
    forms = kif.parse (text ../../sumo.full/Merge.kif) ++ kif.parse (text ../../nix-domain.kif);
  };
  userRules = builtins.filter (f: builtins.head f == "=>") (kif.parse (text ../../rules.kif));
  rules = userRules
    ++ (import ../../reasoner/ingest.nix { }).rules
    ++ (import ../../reasoner/synthesize.nix { forms = kif.parse (text ../../sumo.full/Merge.kif); }).rules;

  gate = import ../../policy/build-gate.nix { };
  violation = gate.check {
    goal = [ "policyViolation" "nginx" "NoCriticalRunningCVE" ];
    inherit facts ontology rules;
    passWhen = "underivable";
  };

  relax = import ../../policy/relax.nix;
  menu = relax {
    goal = [ "policyViolation" "nginx" "NoCriticalRunningCVE" ];
    inherit facts ontology rules;
    passWhen = "underivable";
    candidates = [
      { name = "ignore the advisory";          dropFacts = [ [ "vulnerable" "openssl" "CVE-2026-9999" ] ]; }
      { name = "drain nginx";                 dropFacts = [ [ "serviceState" "nginx" "running" ] ]; }
      { name = "reclassify as low";           dropFacts = [ [ "severity" "CVE-2026-9999" "critical" ] ]; }
      { name = "remove the policy rule";      dropRules = [ "policyViolation#4" ]; }
      { name = "drop an unrelated edge";      dropFacts = [ [ "dependsOn" "hello" "glibc" ] ]; }
    ];
  };
in
''
GATE — the build fails:
${violation.proof}

Menu — which single override flips the verdict?
${builtins.concatStringsSep "\n" (map (m: "  ✓ ${m.name}") menu.menu)}
  ✗ “drop an unrelated edge” flips nothing (correctly unlisted)
''
