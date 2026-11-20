# M2-lite — Drift, rogue listeners, and stale/partial observation.
# Usage: nix --extra-experimental-features nix-command eval --impure --expr 'import ./tests/unit/drift.nix'  -> "ok"
let
  pkgs = import <nixpkgs> { };
  lib = pkgs.lib;
  kif = import ../../lib/kif.nix { };
  inherit (kif) parse;

  systemForms = kif.parse (builtins.readFile ../../system.kif);
  isRule = f: builtins.isList f && f != [ ] && builtins.head f == "=>";
  ontology = import ../../sumo.nix {
    forms = kif.parse (builtins.readFile ../../sumo.full/Merge.kif)
      ++ kif.parse (builtins.readFile ../../nix-domain.kif)
      ++ builtins.filter (f: !(isRule f)) systemForms;
  };
  lift = config: import ../../reasoner/lift-config.nix { inherit config ontology; };
  drift = import ../../reasoner/drift.nix;

  config = (import <nixpkgs/nixos> {
    system = "x86_64-linux";
    configuration = {
      imports = [ { system.stateVersion = "24.11"; services.postgresql.enable = true; } ];
    };
  }).config;
  declared = lift config;

  attesting = ''
    (snapshot "s1" "1000")
    (attests "s1" "sha256:aaaa" "2000" "exporter-test")
    (completeFor unitActive "s1")
    (completeFor listener "s1")
  '';
  active = attesting + ''(observedActive "postgresql.service" "s1")'' + "\n";
  rogue = attesting + ''(observedListener "nc" "0.0.0.0" "9999" "s1")'' + "\n";
  partial = ''
    (snapshot "s1" "1000")
    (attests "s1" "sha256:aaaa" "2000" "exporter-test")
    (completeFor unitActive "s1")
  '';

  d1 = drift { declared = declared; observed = attesting; now = 1500; };
  d2 = drift { declared = declared; observed = active; now = 1500; };
  d3 = drift { declared = declared; observed = rogue; now = 1500; };
  d4 = drift { declared = declared; observed = attesting; now = 2500; };
  d5 = drift { declared = declared; observed = partial; now = 1500; };

  check = what: ok: if ok then true else throw "failed: ${what}";
in
if builtins.all (x: x) [
  (check "a declared-running unit missing from a fresh snapshot is drift"
    (d1.status == "drift" && builtins.length d1.drift == 1))
  (check "the drift proof shows the declared fact and the fresh attestation"
    (lib.hasInfix "declaredRunning" d1.proof && lib.hasInfix "completeFor" d1.proof && lib.hasInfix "unitActive" d1.proof))
  (check "an observed active unit is not drift" (d2.status == "pass" && d2.drift == [ ]))
  (check "a listener with no enabled declared owner is a violation"
    (d3.status == "violation" && builtins.length d3.rogue == 1))
  (check "the rogue proof names the observed listener"
    (lib.hasInfix "observedListener" d3.proof))
  (check "a stale attestation drops the facts and claims nothing"
    (d4.status == "unknown" && d4.drift == [ ] && d4.rogue == [ ]))
  (check "the stale status says why" (lib.hasInfix "no fresh" d4.unknownReason))
  (check "a partial observation claims nothing"
    (d5.status == "unknown" && d5.drift == [ ] && d5.rogue == [ ]))
  (check "the partial status says why" (lib.hasInfix "partial" d5.unknownReason))
  (check "the exporter label survives" (builtins.length d1.sources.exporters == 1))
  (check "the declared facts are still there" (d1.sources.declared > 0))
] then "ok" else "failed"
