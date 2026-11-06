# nixos/sumo.nix — NixOS module for SUMOnix integration.
# Provides: services.sumonix.enable, services.sumonix.repo, services.sumonix.factsFile,
#           services.sumonix.advisoryFile, services.sumonix.guard.enable,
#           services.sumonix.guard.failOnViolation
# Exports nixosModules.default from flake.nix.
{ config, lib, pkgs, ... }:

let
  cfg = config.services.sumonix;
  # The SUMOnix packages from the repo
  sumoPackages = pkgs.callPackage ../nix/sumo-packages.nix { };
in {
  options.services.sumonix = {
    enable = lib.mkEnableOption "SUMOnix reasoning and policy services";

    repo = lib.mkOption {
      type = lib.types.path;
      default = ../../.;
      description = "SUMOnix source tree (bin/, lib/, sumo.full/, facts, rules).";
    };

    factsFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Optional fixture facts file. Live facts are always generated from this system.";
    };

    advisoryFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Labelled advisory fixture, e.g. the CVE used by the policy scene.";
    };

    guard = {
      enable = lib.mkEnableOption "SUMOnix policy guard unit";
      failOnViolation = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Make the guard unit fail when a policy violation is derived.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # Install SUMO CLI and TUI
    environment.systemPackages = [
      sumoPackages.sumo-cli
      sumoPackages.sumo-tui
      sumoPackages.sumo-facts
    ];

    # sumo-facts service: generates live facts from NixOS system
    systemd.services.sumo-facts = {
      description = "Generate SUMOnix facts from this NixOS system";
      wantedBy = [ "multi-user.target" ];
      after = [ "nginx.service" ];
      before = [ "sumonix-guard.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${sumoPackages.sumo-facts}/bin/sumo-facts";
        # Environment for fixture files
        Environment = let
          advisoryDefault = sumoPackages.sumo-facts + "/share/sumo/advisory.kif";
          factsDefault = sumoPackages.sumo-facts + "/share/sumo/facts-fixture.kif";
          advisoryFile =
            if cfg.advisoryFile != null then toString cfg.advisoryFile else advisoryDefault;
          factsFile =
            if cfg.factsFile != null then toString cfg.factsFile else factsDefault;
        in [
          "ADVISORY_FILE=${advisoryFile}"
          "FACTS_FIXTURE=${factsFile}"
          "RULES_SRC=/run/sumo/rules.kif"
        ];
      };
    };

    # sumonix-guard service: runs policy check, exits 1 on violation
    systemd.services.sumonix-guard = lib.mkIf cfg.guard.enable {
      description = "SUMOnix policy guard";
      wantedBy = [ "multi-user.target" ];
      after = [ "sumo-facts.service" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${sumoPackages.sumo-cli}/bin/sumo guard";
        # Exit 1 means "policy violation". Treat it as success only when
        # the demo is not configured to fail the unit.
        SuccessExitStatus = lib.optional (!cfg.guard.failOnViolation) 1;
      };
    };

    # /run/sumo holds the generated facts and the Nix state directory used by
    # `nix eval` inside the guest. tmpfiles creates it; the state dir must be
    # writable by any user that runs `sumo`.
    systemd.tmpfiles.rules = [
      "d /run/sumo 0755 root root -"
      "d /run/sumo/nix-state 0777 root root -"
    ];

    # MOTD for the demo user
    environment.etc."sumo-motd".text = ''
      SUMO is reasoning about this NixOS system.
      Facts: live NixOS state + labelled nixpkgs/CVE fixture.
      Try: sumo status   sumo caps   sumo closure openssl
           sumo query '(vulnerable nginx CVE-2026-9999)'
           sumo whatif   sumo dashboard
    '';

    # Profile.d script to show MOTD and set env vars
    environment.etc."profile.d/sumo-motd.sh".text = ''
      export SUMO_FACTS=/run/sumo/facts.kif
      export SUMO_RULES=/run/sumo/rules.kif
      cat /etc/sumo-motd
    '';
  };
}
