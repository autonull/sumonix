# { facts, rules } -> "ok" or a failed assertion. The scenario is nix_sumo.md section 18: an advisory on openssl reaches
# curl, nginx and app (through curl), and nginx, a running service, breaks NoCriticalRunningCVE; hello is untouched.
# The same checks run on facts read from KIF text (rules.nix) and on facts that went through the dialects (kif.mlir).
{ facts, rules }:
let
  kif = import ../kif.nix;
  pins = import ../pins.nix;
  text = builtins.readFile;
  ontology = import ../sumo.nix {
    forms = kif.parse (text pins.merge) ++ kif.parse (text ../nix-domain.kif);
  };
  e = import ../datalog.nix { inherit ontology facts; inherit rules; };
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
