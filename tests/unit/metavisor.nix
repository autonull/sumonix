# M3A — source-labeled operator surface + module wiring.
# Usage: nix --extra-experimental-features nix-command eval --impure --expr 'import ./tests/unit/metavisor.nix'  -> "ok"
let
  pkgs = import <nixpkgs> { };
  lib = pkgs.lib;
  kif = import ../../lib/kif.nix { };
  inherit (kif) parse;

  systemForms = parse (builtins.readFile ../../system.kif);
  isRule = f: builtins.isList f && f != [ ] && builtins.head f == "=>";
  ontology = import ../../sumo.nix {
    forms = parse (builtins.readFile ../../sumo.full/Merge.kif)
      ++ parse (builtins.readFile ../../nix-domain.kif)
      ++ builtins.filter (f: !(isRule f)) systemForms;
  };

  lift = config: import ../../reasoner/lift-config.nix { inherit config ontology; };
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
  rogue = attesting + ''(observedActive "postgresql.service" "s1")'' + "\n" + ''(observedListener "nc" "0.0.0.0" "9999" "s1")'' + "\n";

  mv = observed: import ../../reasoner/metavisor.nix {
    inherit declared observed;
    now = 1500;
    declaredSource = "test/declared.kif";
    observedSource = "test/observed.kif";
  };

  d = mv attesting;
  p = mv active;
  r = mv rogue;
  s = mv attesting; # same observation: the signature must be stable

  check = what: ok: if ok then true else throw "failed: ${what}";
in
if builtins.all (x: x) [
  (check "a missing unit is drift" (d.status == "drift" && builtins.length d.drift == 1))
  (check "each event carries a stable proof ID"
    (builtins.length d.events == 1
     && builtins.match "sha256:[0-9a-f]+" (builtins.head d.events).proofId != null
     && (builtins.head d.events).kind == "drift"))
  (check "the proof ID is a hash of that proof"
    ((builtins.head d.events).proofId == "sha256:" + builtins.hashString "sha256" (builtins.head d.drift).proof))
  (check "the journal line names the unit and proof ID"
    (builtins.length d.journal == 1
     && lib.hasInfix "\tdrift unit=postgresql.service" (builtins.head d.journal)
     && lib.hasInfix "sha256:" (builtins.head d.journal)))
  (check "the human section labels both sources"
    (lib.hasInfix "declared: test/declared.kif" d.text
     && lib.hasInfix "observed: test/observed.kif" d.text))
  (check "the human section prints the proof, not just the verdict"
    (lib.hasInfix "declaredRunning" d.text && lib.hasInfix "completeFor unitActive" d.text))
  (check "the JSON section is serializable and source-labeled"
    (let j = builtins.toJSON d.json; in
     lib.hasInfix "\"proofId\"" j && lib.hasInfix "\"declaredPath\"" (builtins.toJSON d.json.sources)))
  (check "an observed active unit passes with no events"
    (p.status == "pass" && p.events == [ ] && p.journal == [ ]))
  (check "a rogue listener is a violation with a proof ID"
    (r.status == "violation"
     && builtins.length r.events == 1
     && (builtins.head r.events).kind == "violation"
     && lib.hasInfix "observedListener" r.text))
  (check "the same observation has the same signature" (d.signature == s.signature))
  (check "a stale observation claims nothing and says why"
    (let u = mv ''
          (snapshot "s1" "1000")
          (attests "s1" "sha256:aaaa" "1200" "exporter-test")
          (completeFor unitActive "s1")
          (completeFor listener "s1")
        '';
     in u.status == "unknown" && u.events == [] && lib.hasInfix "no fresh" u.unknownReason))

  # Module wiring: the same code must install on a plain NixOS host.
  (let m = (import <nixpkgs/nixos> {
     system = "x86_64-linux";
     configuration = {
       imports = [ ../../container/nixos/metavisor.nix ];
       system.stateVersion = "24.11";
       services.postgresql.enable = true;
       services.sumonix-metavisor.enable = true;
     };
   }).config;
   in check "the module installs a persistent state directory and timer"
     (m.systemd.services.sumonix-metavisor.serviceConfig.StateDirectory == "sumonix-metavisor"
      && m.systemd.timers.sumonix-metavisor.timerConfig.OnUnitActiveSec == "60s"))
  (let m = (import <nixpkgs/nixos> {
     system = "x86_64-linux";
     configuration = {
       imports = [ ../../container/nixos/metavisor.nix ];
       system.stateVersion = "24.11";
       services.postgresql.enable = true;
       services.sumonix-metavisor.enable = true;
     };
   }).config;
   in check "the module lifts the live config into declared.kif"
     (lib.hasInfix "declaredService" m.environment.etc."sumo/declared.kif".text
      && lib.hasInfix "services.postgresql" m.environment.etc."sumo/declared.kif".text))
  (let m = (import <nixpkgs/nixos> {
     system = "x86_64-linux";
     configuration = {
       imports = [ ../../container/nixos/metavisor.nix ];
       system.stateVersion = "24.11";
       services.sumonix-metavisor.enable = true;
     };
   }).config;
   in check "the service runs the observer tick with the CLI wrapper"
     (lib.hasInfix "tools/metavisor.sh" m.systemd.services.sumonix-metavisor.serviceConfig.ExecStart
      && lib.hasInfix "SUMO_BIN=" (builtins.concatStringsSep "\n" m.systemd.services.sumonix-metavisor.serviceConfig.Environment)))
] then "ok" else "failed"
