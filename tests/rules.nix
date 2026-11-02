# mlnix eval tests/rules.nix  ->  "ok" or a failed assertion
#
# The scenario is nix_sumo.md section 18: an advisory on openssl reaches curl and nginx, and nginx, a running service,
# breaks NoCriticalRunningCVE. The expected facts are the ones that section lists; hello depends on glibc and is untouched.
let
  kif = import ../kif.nix;
  pins = import ../pins.nix;
  text = builtins.readFile;
  ontology = import ../sumo.nix {
    forms = kif.parse (text pins.merge) ++ kif.parse (text ../nix-domain.kif);
  };
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
  e = import ../datalog.nix { inherit ontology facts; rules = builtins.filter (f: builtins.head f == "=>") (kif.parse (text ../rules.kif)); };
  check = what: ok: if ok then true else throw "failed: ${what}";
  affected = builtins.sort builtins.lessThan (map (b: b."?p") (e.ask [ "vulnerable" "?p" "CVE-2026-9999" ]));
in
if builtins.all (x: x) [
  (check "the domain ontology sits under SUMO" (ontology.isSubclass "NIXService" "Process" && ontology.isSubclass "NIXBuild" "IntentionalProcess"))
  (check "every parent in nix-domain.kif is a SUMO or NIX class"
    (builtins.all (f: ontology.classes ? ${builtins.elemAt f 2}) (builtins.filter (f: builtins.head f == "subclass") (kif.parse (text ../nix-domain.kif)))))
  (check "vulnerability reaches curl, nginx, and app through curl" (affected == [ "app" "curl" "nginx" "openssl" ]))
  (check "hello is untouched" (!(e.holds [ "vulnerable" "hello" "CVE-2026-9999" ])))
  (check "nginx breaks the policy" (e.holds [ "policyViolation" "nginx" "NoCriticalRunningCVE" ]))
  (check "curl does not (not a service)" (!(e.holds [ "policyViolation" "curl" "NoCriticalRunningCVE" ])))
  (check "the proof names its rule" ((e.why [ "vulnerable" "nginx" "CVE-2026-9999" ]).rule == "vulnerable#3"))
  (check "the proof ends in asserted facts" (builtins.length (builtins.filter (l: builtins.match ".*asserted" l != null) (builtins.filter builtins.isString (builtins.split "\n" (e.explain [ "policyViolation" "nginx" "NoCriticalRunningCVE" ])))) >= 4))
]
then "ok" else "failed"
