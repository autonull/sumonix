# Phase 5 — Policy product: the build gate (both polarities) and the relaxation menu.
# Usage: nix --extra-experimental-features nix-command eval --impure --expr 'import ./tests/unit/relax.nix'  -> "ok"
let
  lib = import ../lib.nix { };
  kif = import ../../lib/kif.nix { };
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
    (vulnerable openssl CVE-2027-0001)
    (severity CVE-2026-9999 critical)
    (severity CVE-2027-0001 critical)
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
  check = gate.check;
  violation = check {
    goal = [ "policyViolation" "nginx" "NoCriticalRunningCVE" ];
    inherit facts ontology rules;
    passWhen = "underivable";
  };
  required = check {
    goal = [ "vulnerable" "app" "CVE-2026-9999" ];
    inherit facts ontology rules;
    passWhen = "derivable";
  };

  relax = import ../../policy/relax.nix;
  candidates = [
    { name = "ignore the 2026-9999 advisory"; dropFacts = [ [ "vulnerable" "openssl" "CVE-2026-9999" ] ]; note = "\"accepted risk: 2026-9999\" — expiry required"; }
    { name = "ignore the 2027-0001 advisory"; dropFacts = [ [ "vulnerable" "openssl" "CVE-2027-0001" ] ]; }
    { name = "drain nginx (not running)"; dropFacts = [ [ "serviceState" "nginx" "running" ] ]; }
    { name = "remove the policy rule"; dropRules = [ "policyViolation#4" ]; }
    { name = "drop an unrelated edge"; dropFacts = [ [ "dependsOn" "hello" "glibc" ] ]; }
    { name = "reclassify 2026-9999 as low"; dropFacts = [ [ "severity" "CVE-2026-9999" "critical" ] ]; }
    { name = "reclassify 2027-0001 as low"; dropFacts = [ [ "severity" "CVE-2027-0001" "critical" ] ]; }
  ];
  menu = relax {
    goal = [ "policyViolation" "nginx" "NoCriticalRunningCVE" ];
    inherit facts ontology rules candidates;
    passWhen = "underivable";
  };
  pairMenu = relax {
    goal = [ "policyViolation" "nginx" "NoCriticalRunningCVE" ];
    inherit facts ontology rules;
    passWhen = "underivable";
    candidates = builtins.filter (c: builtins.elem c.name [
      "ignore the 2026-9999 advisory" "ignore the 2027-0001 advisory"
      "reclassify 2026-9999 as low" "reclassify 2027-0001 as low" ]) candidates;
  };
  supportsMenu = relax {
    goal = [ "vulnerable" "app" "CVE-2026-9999" ];
    inherit facts ontology rules;
    passWhen = "derivable";
    candidates = [ ];
  };
  menuNames = map (m: m.name) menu.menu;
in
if builtins.all (x: x) [
  # --- gate -------------------------------------------------------------------
  (lib.check "violation is derivable; gate fails (underivable polarity)" (!violation.pass))
  (lib.check "the gate report carries the why subtree" (violation.tree != null && violation.proof != ""))
  (lib.check "a required goal is derivable; gate passes (derivable polarity)" required.pass)
  (lib.check "the required goal proof reaches the advisory" (builtins.match ".*CVE-2026-9999.*" required.proof != null))
  # --- relaxation menu ----------------------------------------------------------
  (lib.check "the menu lists exactly the true single-flip overrides"
    (menuNames == [ "drain nginx (not running)" "remove the policy rule" ]))
  (lib.check "the unrelated edge flips nothing and is not offered" (!(builtins.elem "drop an unrelated edge" menuNames)))
  (lib.check "every menu entry carries a proof sketch" (builtins.all (m: m.proof != "") menu.menu))
  (lib.check "every listed override really breaks derivability" (builtins.all (m: !m.derived) menu.menu))
  (lib.check "menu diagnostics account for the candidates" (menu.diagnostics.candidates == 7 && menu.diagnostics.flips == builtins.length menu.menu))
  # --- size-2 flips when no single flip exists ---------------------------------
  (lib.check "no single advisory flips (two independent CVEs), four pairs flip"
    (pairMenu.menu == [ ] && builtins.length pairMenu.minFlipsGroups == 4))
  # --- supports (inverse direction) --------------------------------------------
  (lib.check "a holding goal reports its load-bearing proof leaves"
    (supportsMenu.basePass && builtins.length supportsMenu.supports > 0))
  (lib.check "dropping the app->curl edge alone breaks the required goal"
    (builtins.any (s: s.fact == "(dependsOn app curl)" && s.flip) supportsMenu.supports))
  (lib.check "the policy failure proof names the violating rule" (builtins.match ".*policyViolation#4.*" violation.proof != null))
] then "ok" else "failed"
