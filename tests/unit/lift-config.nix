# M1 — Config lifter + gate on real NixOS configs (no fixtures).
# Usage: nix --extra-experimental-features nix-command eval --impure --expr 'import ./tests/unit/lift-config.nix'  -> "ok"
let
  pkgs = import <nixpkgs> { };
  lib = pkgs.lib;
  kif = import ../../lib/kif.nix { };
  inherit (kif) headOf;

  systemForms = kif.parse (builtins.readFile ../../system.kif);
  isRule = f: builtins.isList f && f != [ ] && builtins.head f == "=>";
  ontology = import ../../sumo.nix {
    forms = kif.parse (builtins.readFile ../../sumo.full/Merge.kif)
      ++ kif.parse (builtins.readFile ../../nix-domain.kif)
      ++ builtins.filter (f: !(isRule f)) systemForms;
  };

  lift = config: import ../../reasoner/lift-config.nix { inherit config ontology; };
  gateOf = l: import ../../reasoner/config-gate.nix { inherit (l) facts rules ontology; };

  base = {
    system.stateVersion = "24.11";
    services.postgresql.enable = true;
  };
  mk = extra: (import <nixpkgs/nixos> {
    system = "x86_64-linux";
    configuration = { imports = [ base extra ]; };
  }).config;

  badConfig = mk {
    services.postgresql.settings.listen_addresses = lib.mkForce "0.0.0.0";
    networking.firewall.allowedTCPPorts = lib.mkForce [ ];
  };
  goodConfig = mk {
    services.postgresql.settings.listen_addresses = lib.mkForce "0.0.0.0";
    networking.firewall.allowedTCPPorts = lib.mkForce [ 5432 ];
  };
  localConfig = mk { };

  bad = lift badConfig;
  good = lift goodConfig;
  local = lift localConfig;
  badGate = gateOf bad;
  goodGate = gateOf good;
  localGate = gateOf local;

  start = builtins.currentTime;
  gateForced = badGate.pass || builtins.length badGate.violations > 0;
  elapsed = builtins.currentTime - start;

  thrown = builtins.tryEval (badGate.mkChecked { name = "postgres+firewall"; });

  ambiguous = import ../../reasoner/lift-config.nix {
    config = badConfig;
    inherit ontology;
    serviceTable = {
      postgresql = { unitKey = "missing"; unit = "missing.service"; };
    };
  };

  check = what: ok: if ok then true else throw "failed: ${what}";
in
if builtins.all (x: x) [
  (check "the bad config fails the gate" (!badGate.pass))
  (check "the proof names the listener option path"
    (lib.hasInfix "services.postgresql.settings.listen_addresses" badGate.proof))
  (check "the proof names the firewall option path"
    (lib.hasInfix "networking.firewall.allowedTCPPorts" badGate.proof))
  (check "the eval-time gate throws" (!thrown.success))
  (check "the independent checker re-verifies the exported violation proof"
    (badGate.recheckOk && lib.hasInfix "independently re-checked" badGate.recheck))
  (check "allowing 5432 passes" goodGate.pass)
  (check "localhost passes" localGate.pass)
  (check "lifted facts are well typed" (bad.illTyped == [ ]))
  (check "declared and inferred facts are labeled" (bad.counts.declared > 0 && bad.counts.inferred > 0))
  (check "the port default is inferred, never declared"
    (builtins.any (f: headOf f == "portInferred") bad.facts
     && !(builtins.any (f: headOf f == "portDeclared") bad.facts)))
  (check "a real config is byte-stable"
    (bad.factsText == (lift badConfig).factsText))
  (check "an enabled service without a unit is rejected with a reason"
    (builtins.length ambiguous.ambiguous == 1))
  (check "the gate stays inside the eval budget" (elapsed < 5))
  gateForced
] then "ok" else "failed"
