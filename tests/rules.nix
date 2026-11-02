# mlnix eval tests/rules.nix  ->  "ok" or a failed assertion
# The scenario of tests/scenario.nix, with facts and rules read from KIF text.
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
in
import ./scenario.nix {
  inherit facts;
  rules = builtins.filter (f: builtins.head f == "=>") (kif.parse (text ../rules.kif));
}
