# Phase 1 — Runtime Policy: test R3 (unauthorized user), R4 (world-readable secret), R5 (prohibited license)
# Usage: nix --extra-experimental-features nix-command eval --impure --expr 'import ./tests/unit/runtime-policy.nix'
let
  kif = import ../../lib/kif.nix { };
  systemForms = kif.parse (builtins.readFile ../../system.kif);
  isRule = f: builtins.isList f && f != [ ] && builtins.head f == "=>";
  systemRules = builtins.filter isRule systemForms;
  systemOntology = builtins.filter (f: !(isRule f)) systemForms;
  ontology = import ../../sumo.nix {
    forms = kif.parse (builtins.readFile ../../sumo.full/Merge.kif)
      ++ kif.parse (builtins.readFile ../../nix-domain.kif)
      ++ systemOntology;
  };
  bi = import ../../reasoner/builtins.nix { };

  # Helper: KIF-quoted string for ask patterns (for quoted strings in facts)
  q = s: "\"" + s + "\"";

  # Test case 1: R3 - unauthorized user
  factsR3 = kif.parse ''
    (instance nginx NIXService)
    (serviceState nginx running)
    (runningAs nginx "www-data")
    (declaredRunning nginx "services.nginx.enable")
    ;; authorizedUser nginx nginx  -- missing, so violation
  '';
  eR3 = import ../../datalog.nix { ontology = ontology; rules = systemRules; facts = factsR3; builtinRegistry = bi; };
  # policyViolation nginx UnauthorizedUser (both symbols)
  r3Violation = eR3.ask [ "policyViolation" "nginx" "UnauthorizedUser" ];

  # Test case 2: R3 - authorized user (no violation)
  factsR3Ok = kif.parse ''
    (instance nginx NIXService)
    (serviceState nginx running)
    (runningAs nginx nginx)
    (declaredRunning nginx "services.nginx.enable")
    (authorizedUser nginx nginx)
  '';
  eR3Ok = import ../../datalog.nix { ontology = ontology; rules = systemRules; facts = factsR3Ok; builtinRegistry = bi; };
  r3NoViolation = eR3Ok.ask [ "policyViolation" "nginx" "UnauthorizedUser" ];

  # Test case 3: R4 - world-readable secret (mode 0644)
  factsR4 = kif.parse ''
    (instance "/etc/ssl/private/key.pem" NIXSecret)
    (secretPath "/etc/ssl/private/key.pem" "services.nginx.sslKey")
    (secretMode "/etc/ssl/private/key.pem" "0644")
  '';
  eR4 = import ../../datalog.nix { ontology = ontology; rules = systemRules; facts = factsR4; builtinRegistry = bi; };
  # policyViolation "/etc/ssl/private/key.pem" WorldReadableSecret (first is quoted string)
  r4Violation = eR4.ask [ "policyViolation" (q "/etc/ssl/private/key.pem") "WorldReadableSecret" ];

  # Test case 4: R4 - world-readable secret (mode 0755)
  factsR4b = kif.parse ''
    (instance "/etc/ssh/ssh_host_rsa_key" NIXSecret)
    (secretPath "/etc/ssh/ssh_host_rsa_key" "services.openssh.hostKey")
    (secretMode "/etc/ssh/ssh_host_rsa_key" "0755")
  '';
  eR4b = import ../../datalog.nix { ontology = ontology; rules = systemRules; facts = factsR4b; builtinRegistry = bi; };
  r4bViolation = eR4b.ask [ "policyViolation" (q "/etc/ssh/ssh_host_rsa_key") "WorldReadableSecret" ];

  # Test case 5: R4 - secure secret (mode 0600, no violation)
  factsR4Ok = kif.parse ''
    (instance "/etc/ssl/private/key.pem" NIXSecret)
    (secretPath "/etc/ssl/private/key.pem" "services.nginx.sslKey")
    (secretMode "/etc/ssl/private/key.pem" "0600")
  '';
  eR4Ok = import ../../datalog.nix { ontology = ontology; rules = systemRules; facts = factsR4Ok; builtinRegistry = bi; };
  r4NoViolation = eR4Ok.ask [ "policyViolation" (q "/etc/ssl/private/key.pem") "WorldReadableSecret" ];

  # Test case 6: R5 - prohibited license (GPL-3.0-only)
  factsR5 = kif.parse ''
    (instance openssl NIXPackage)
    (packageLicense openssl "GPL-3.0-only")
    (licensePolicy "GPL-3.0-only" ProhibitedLicense)
  '';
  eR5 = import ../../datalog.nix { ontology = ontology; rules = systemRules; facts = factsR5; builtinRegistry = bi; };
  # policyViolation openssl ProhibitedLicense (both symbols)
  r5Violation = eR5.ask [ "policyViolation" "openssl" "ProhibitedLicense" ];

  # Test case 7: R5 - allowed license (Apache-2.0, no violation)
  factsR5Ok = kif.parse ''
    (instance openssl NIXPackage)
    (packageLicense openssl "Apache-2.0")
    (licensePolicy "GPL-3.0-only" ProhibitedLicense)
  '';
  eR5Ok = import ../../datalog.nix { ontology = ontology; rules = systemRules; facts = factsR5Ok; builtinRegistry = bi; };
  r5NoViolation = eR5Ok.ask [ "policyViolation" "openssl" "ProhibitedLicense" ];

  check = what: ok: if ok then true else throw "failed: ${what}";
in
if builtins.all (x: x) [
  (check "R3: unauthorized user triggers violation" (r3Violation != [ ]))
  (check "R3: authorized user does not trigger violation" (r3NoViolation == [ ]))
  (check "R4: world-readable secret (0644) triggers violation" (r4Violation != [ ]))
  (check "R4: world-readable secret (0755) triggers violation" (r4bViolation != [ ]))
  (check "R4: secure secret (0600) does not trigger violation" (r4NoViolation == [ ]))
  (check "R5: prohibited license (GPL-3.0-only) triggers violation" (r5Violation != [ ]))
  (check "R5: allowed license (Apache-2.0) does not trigger violation" (r5NoViolation == [ ]))
] then "ok" else "failed"