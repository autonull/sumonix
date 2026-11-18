# M3A — the resident metavisor module.
#
# Wires the pure parts (lift + drift + event IDs) into a timer-driven systemd
# unit. At build time the module lifts *this* system's configuration into
# `/etc/sumo/declared.kif`; at runtime the dumb observer writes
# `/run/sumo/observed.kif` and `tools/metavisor.sh` appends one JSON event per
# new drift/violation to `/var/lib/sumonix-metavisor/events.jsonl`.
#
# Install on any NixOS host:
#   imports = [ inputs.sumonix.nixosModules.sumonix-metavisor ];
#   services.sumonix-metavisor.enable = true;
{ config, lib, pkgs, ... }:

let
  cfg = config.services.sumonix-metavisor;

  # The declared side is lifted from the very configuration being built. The
  # lift reads only the slice paths, so this does not recurse through
  # environment.etc / systemd options.
  lifted = import (cfg.repo + "/reasoner/lift-config.nix") {
    config = config;
    systemKif = cfg.repo + "/system.kif";
  };

  observerPath = lib.makeBinPath [
    pkgs.nix
    pkgs.systemd
    pkgs.iproute2
    pkgs.coreutils
    pkgs.gnused
    pkgs.gnugrep
    pkgs.gawk
    pkgs.findutils
    pkgs.bash
  ];
in
{
  options.services.sumonix-metavisor = {
    enable = lib.mkEnableOption "the SUMOnix resident metavisor (timer + event log)";

    repo = lib.mkOption {
      type = lib.types.path;
      default = ../../.;
      description = "SUMOnix source tree used for the lift, observer and CLI.";
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.callPackage ../nix/sumo-cli.nix { repo = ../../.; };
      defaultText = lib.literalExpression "pkgs.callPackage ../nix/sumo-cli.nix { }";
      description = "The sumo CLI package that carries reasoner/ and tools/.";
    };

    interval = lib.mkOption {
      type = lib.types.ints.positive;
      default = 60;
      description = ''
        Seconds between refresh ticks. The observation TTL is twice this value,
        so one missed tick still leaves a fresh snapshot; two make the status
        `unknown` rather than claiming drift (R1).
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Build-time lift: the declared facts are a function of this system config.
    environment.etc."sumo/declared.kif".text = lifted.labeledText;

    systemd.tmpfiles.rules = [
      "d /run/sumo 0755 root root -"
      "d /run/sumo/nix-state 0777 root root -"
    ];

    systemd.services.sumonix-metavisor = {
      description = "SUMOnix metavisor refresh (observe -> drift -> event log)";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      serviceConfig = {
        Type = "oneshot";
        StateDirectory = "sumonix-metavisor";
        StateDirectoryMode = "0750";
        TimeoutStartSec = "5min";
        # Root is required for `ss -ltnp` process attribution. A non-root
        # observer stays `unknown` by design (R1).
        User = "root";
        ExecStart = "${pkgs.bash}/bin/bash ${cfg.package}/share/sumo/tools/metavisor.sh --declared /etc/sumo/declared.kif --observed /run/sumo/observed.kif --interval ${toString cfg.interval}";
        Environment = [
          "PATH=${observerPath}"
          "SUMONIX_METAVISOR_STATE=/var/lib/sumonix-metavisor"
          "SUMO_METAVISOR_INTERVAL=${toString cfg.interval}"
          "SUMO_OBSERVE_TTL=${toString (cfg.interval * 2)}"
          "SUMO_BIN=${cfg.package}/bin/sumo"
        ];
      };
    };

    systemd.timers.sumonix-metavisor = {
      description = "SUMOnix metavisor refresh timer";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "1min";
        OnUnitActiveSec = "${toString cfg.interval}s";
        AccuracySec = "1s";
        Unit = "sumonix-metavisor.service";
      };
    };
  };
}
