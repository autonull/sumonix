# demo/container/container.nix — Minimal NixOS container configuration for SUMOnix demo.
# boot.isContainer = true; no VM-only options.
# Includes nginx, SUMOnix module, and minimal packages.
{ config, pkgs, lib, ... }:

let
  # SUMOnix packages from the repo
  sumoPackages = pkgs.callPackage ./nix/sumo-packages.nix { };
in {
  # Container mode: no bootloader, no kernel, no disk image
  boot.isContainer = true;
  boot.loader.grub.enable = false;
  fileSystems."/" = { fsType = "none"; device = "none"; };

  # Hostname
  networking.hostName = "sumonix-demo";

  # No DHCP, no SSH — podman exec is the login
  networking.useDHCP = false;
  services.openssh.enable = false;

  # Minimal packages: nginx + nix + bash + coreutils + iproute2 + SUMO
  environment.systemPackages = with pkgs; [
    nginx
    nix
    bashInteractive
    coreutils
    iproute2
    sumoPackages.sumo-cli
    sumoPackages.sumo-tui
    sumoPackages.sumo-facts
  ];

  # nginx as the real NixOS service and policy subject
  services.nginx = {
    enable = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    virtualHosts."sumonix-demo" = {
      root = "/var/www/sumonix-demo";
    };
  };

  # Create a minimal nginx site
  systemd.tmpfiles.rules = [
    "d /var/www/sumonix-demo 0755 root root -"
  ];
  environment.etc."nginx/index.html".text = ''
    <!DOCTYPE html>
    <html>
    <head><title>sumonix-demo</title></head>
    <body><h1>sumonix-demo</h1><p>nginx is running on NixOS in a container.</p></body>
    </html>
  '';
  systemd.services.nginx.serviceConfig.ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p /var/www/sumonix-demo";

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