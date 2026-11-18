# M4-lite — Verified repair: one option edit per candidate, re-lifted and re-gated.
# Usage: nix --extra-experimental-features nix-command eval --impure --expr 'import ./tests/unit/repair.nix'  -> "ok"
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

  baseModule = {
    system.stateVersion = "24.11";
    services.postgresql.enable = true;
    services.postgresql.settings.listen_addresses = lib.mkForce "0.0.0.0";
    networking.firewall.allowedTCPPorts = lib.mkForce [ ];
  };
  mk = extra: (import <nixpkgs/nixos> {
    system = "x86_64-linux";
    configuration = { imports = [ baseModule extra ]; };
  }).config;

  base = lift (mk { });
  patched = edit: lift (mk ({ ... }:
      lib.setAttrByPath (lib.splitString "." edit.optionPath) (lib.mkOverride 10 edit.value)));

  candidates = [
    {
      name = "allow 5432 in the firewall";
      rank = 1;
      edits = [ { optionPath = "networking.firewall.allowedTCPPorts"; value = [ 5432 ]; } ];
    }
    {
      name = "bind postgresql to localhost";
      rank = 2;
      edits = [ { optionPath = "services.postgresql.settings.listen_addresses"; value = "localhost"; } ];
    }
    {
      name = "disable postgresql";
      rank = 3;
      edits = [ { optionPath = "services.postgresql.enable"; value = false; } ];
    }
    {
      name = "multi-path";
      rank = 9;
      edits = [
        { optionPath = "services.postgresql.enable"; value = false; }
        { optionPath = "networking.firewall.enable"; value = true; }
      ];
    }
    {
      name = "invalid value";
      rank = 8;
      edits = [ { optionPath = "networking.firewall.allowedTCPPorts"; value = "not-a-list"; } ];
    }
  ];

  baseGate = import ../../reasoner/config-gate.nix { inherit (base) facts rules ontology; };
  repair = import ../../reasoner/repair.nix { inherit base patched candidates; };
  defaultRepair = import ../../reasoner/repair.nix { inherit base patched; };

  ranked = repair.ranked;
  byName = name: builtins.head (builtins.filter (c: c.name == name) repair.attempts);

  check = what: ok: if ok then true else throw "failed: ${what}";
in
if builtins.all (x: x) [
  (check "the base config violates before repair" (!baseGate.pass))
  (check "at least three candidates verify" (repair.count.verified >= 3))
  (check "every ranked candidate carries its re-lifted proof"
    (builtins.all (c: c.verified && c.gate.pass && c.proof != "") ranked))
  (check "every ranked candidate carries a one-path option diff"
    (builtins.all (c: builtins.length c.edits == 1) ranked))
  (check "the diff names the edited option path"
    (builtins.all (c: lib.hasInfix (builtins.head c.edits).optionPath c.diff) ranked))
  (check "the allow-port candidate ranks first" (repair.best.name == "allow 5432 in the firewall"))
  (check "the allow-port edit adds a firewall fact"
    (let c = byName "allow 5432 in the firewall"; in
     builtins.length c.factDiff.added == 1 && builtins.any (x: lib.hasInfix "firewallTcpAllowed" x) c.factDiff.added))
  (check "binding localhost removes the wildcard listener"
    (let c = byName "bind postgresql to localhost"; in
     builtins.any (x: lib.hasInfix "listenerDeclared" x) c.factDiff.removed))
  (check "disabling postgres removes its declared facts"
    (let c = byName "disable postgresql"; in
     builtins.any (x: lib.hasInfix "declaredService" x) c.factDiff.removed))
  (check "a multi-path edit is rejected with a reason"
    (lib.hasInfix "multi-path" (byName "multi-path").reason))
  (check "an invalid value is rejected because the re-lift fails"
    (lib.hasInfix "re-lift failed" (byName "invalid value").reason))
  (check "default repair derives the firewall and disable candidates"
    (defaultRepair.count.verified >= 2
     && builtins.any (c: lib.hasInfix "allow port" c.name) defaultRepair.ranked
     && builtins.any (c: lib.hasInfix "disable" c.name) defaultRepair.ranked))
] then "ok" else "failed"
