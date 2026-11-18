# demo/container/container.nix — Minimal NixOS container configuration for SUMOnix demo.
# boot.isContainer = true; no VM-only options.
# Includes postgres (the declared unit), the metavisor module and minimal packages.
{ config, pkgs, lib, ... }:

let
  # SUMOnix packages from the repo
  sumoPackages = pkgs.callPackage ./nix/sumo-packages.nix { };

  # The repo root as a *directory* path. Interpolating a single file
  # (`${./nixos/sumo.nix}`) copies that one file to the store root and breaks
  # its relative imports; the directory keeps the tree intact.
  repo = ../.;
in {
  # D1 — the operator's declared slice: postgres on a wildcard, firewall open.
  # The contradicting variant (nixos/d1-bad-firewall.nix) lives in /etc/nixos/bad.nix.
  imports = [ ./nixos/d1-configuration.nix ];

  # Container mode: no bootloader, no kernel, no disk image
  boot.isContainer = true;
  boot.loader.grub.enable = false;
  fileSystems."/" = { fsType = "none"; device = "none"; };

  # Hostname
  networking.hostName = "sumonix-demo";

  # No DHCP, no SSH — podman exec is the login
  networking.useDHCP = false;
  services.openssh.enable = false;

  # Minimal packages: nix + bash + coreutils + iproute2 + nc + SUMO
  environment.systemPackages = with pkgs; [
    nix
    bashInteractive
    coreutils
    iproute2
    netcat-openbsd
    sumoPackages.sumo-cli
    sumoPackages.sumo-tui
    sumoPackages.sumo-facts
  ];

  # Postgres runs as a real unit here: D1 stops it and expects drift with proof.

  # M3A — the resident metavisor: observer tick, event log, journal lines. The
  # build-time gate is on, so this very config must pass it (it does).
  services.sumonix-metavisor = {
    enable = true;
    interval = 10;
  };

  # Match the flake's label (26.11). Without this, `nixos-rebuild` labels the
  # system `26.11pre-git` and relinks/fetches the whole closure instead of
  # reusing the image's store paths.
  system.nixos.versionSuffix = "";

  # `nixos-rebuild` inside the container needs a pinned nixpkgs, and the two
  # repair scenes need their modules in the same shape a user would keep them.
  nix.nixPath = [ "nixpkgs=${pkgs.path}" ];
  environment.etc."nixos/configuration.nix".text = ''
    # D1 — the rebuildable form of this system. `sumo repair` proposes option
    # edits; the tour applies the top one to a copy and rebuilds this config.
    { ... }: {
      imports = [
        <nixpkgs/nixos/modules/virtualisation/lxc-container.nix>
        ${repo}/container/nixos/sumo.nix
        ${repo}/container/nixos/metavisor.nix
        ${repo}/container/container.nix
      ];
    }
  '';
  environment.etc."nixos/bad.nix".text = ''
    # D1 scene 1/3 — the contradiction: wildcard postgres, no firewall port.
    { ... }: {
      imports = [ ${repo}/container/nixos/d1-bad.nix ];
    }
  '';

  # The legacy L0 guard keeps its fixture subject; the container itself
  # declares only postgres so the runtime loop has one unit to observe.
  systemd.tmpfiles.rules = [ ];

  # SUMOnix module integration
  services.sumonix = {
    enable = true;
    # Advisory fixture for the policy scene (nginx/CVE)
    advisoryFile = ../fixtures/policy.kif;
    # Facts fixture (pinned rules)
    factsFile = ../fixtures/rules.kif;
    # Guard unit enabled but non-failing for normal demo
    guard = {
      enable = true;
      failOnViolation = false;
    };
  };

  # Keep systemd from reporting failed units the demo does not need. Each of these
  # wants privileges or a network that a rootless container does not provide.
  security.sudo.enable = false;
  systemd.oomd.enable = false;
  services.nscd.enable = false;
  system.nssModules = lib.mkForce [ ];
  nix.channel.enable = false;
  services.dbus.enable = lib.mkForce false;
  # Units that cannot succeed in a rootless container: /run/wrappers needs a
  # privileged bind mount, nix-channel-init needs network, logind needs D-Bus.
  systemd.suppressedSystemUnits = [
    "run-wrappers.mount"
    "nix-channel-init.service"
    "systemd-logind.service"
    "suid-sgid-wrappers.service"
  ];

  # Demo user for podman exec -u demo
  users.users.demo = {
    isNormalUser = true;
    password = "demo";
    extraGroups = [ "wheel" ];
    shell = pkgs.bashInteractive;
  };

  # Nix configuration
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.trusted-users = [ "root" "demo" ];

  # State version
  system.stateVersion = "24.11";
}