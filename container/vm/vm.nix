# demo/vm/vm.nix — NixOS VM for the sumonix demo
# Boots headless, 2 cores / 2048 MB, serial console.
# Based on spike/vm.nix pattern: copies repo source, uses host nixpkgs.
# Build with: nix build -f '<nixpkgs/nixos>' vm -I nixos-config=./demo/vm/vm.nix

{ config, pkgs, lib, repoRoot, ... }:

let
  # Copy the repository source into the VM (drop VCS, local stores, build outputs)
  repo = builtins.path {
    path = repoRoot;
    filter = path: type: !(builtins.elem (baseNameOf path)
      [ ".git" ".nix-store" ".nix-state" "result" "result-*" "vm-result" "demo/vm/result-*" ]);
  };

  # Host nixpkgs path for offline eval inside VM
  nixpkgsPath = pkgs.path;

  # sumo CLI script for the VM
  sumoScript = pkgs.writeShellScriptBin "sumo" ''
    #!/bin/sh
    export NIX_STORE_DIR=/nix/store
    export NIX_STATE_DIR=/nix/var/nix
    export NIX_PATH="nixpkgs=${nixpkgsPath}"
    export SUMO_FACTS=/run/sumo/facts.kif
    export SUMO_RULES=/run/sumo/rules.kif
    exec ${repo}/bin/sumo "$@"
  '';

  # sumo-facts service: writes curated facts to /run/sumo/
  sumoFactsScript = pkgs.writeShellScript "sumo-facts" ''
    #!/bin/sh
    set -euo pipefail
    mkdir -p /run/sumo
    # Copy curated facts
    cp ${repo}/demo/vm/host-facts.kif /run/sumo/facts.kif
    # Copy rules
    cp ${repo}/rules.kif /run/sumo/rules.kif
    # Link repo for nix eval
    ln -sf ${repo} /run/sumo/repo
    # Link sumo binary
    mkdir -p /run/sumo/bin
    ln -sf ${sumoScript} /run/sumo/bin/sumo
  '';

in
{
  # Classic VM: direct kernel boot, no GRUB
  boot.loader.grub.enable = false;
  fileSystems."/" = { device = "tmpfs"; fsType = "tmpfs"; options = [ "size=90%" ]; };

  # VM resources
  virtualisation.vmVariant = {
    virtualisation.memorySize = 2048;
    virtualisation.cores = 2;
  };

  # Kernel params for serial console
  boot.kernelParams = [ "console=ttyS0" ];
  systemd.services."getty@ttyS0".wantedBy = [ "multi-user.target" ];

  # Networking
  networking.useDHCP = true;
  networking.hostName = "sumonix-demo";

  # SSH for human access
  services.openssh.enable = true;
  services.openssh.settings.PasswordAuthentication = true;

  # User: demo with autologin
  users.users.demo = {
    isNormalUser = true;
    password = "demo";
    extraGroups = [ "wheel" ];
    shell = pkgs.bashInteractive;
  };
  services.getty.autologinUser = "demo";

  # Packages in the VM
  environment.systemPackages = with pkgs; [
    nix
    bashInteractive
    coreutils
    asciinema
    sumoScript
  ];

  # Nix configuration
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.trusted-users = [ "root" "demo" ];

  # Override gnu-config to fix broken URLs (upstream savannah.gnu.org returns 404)
  nixpkgs.config.packageOverrides = pkgs: {
    gnu-config = pkgs.gnu-config.overrideAttrs (old: {
      urls = [
        "https://ftpmirror.gnu.org/gnu/config/config.guess-948ae97"
        "https://ftpmirror.gnu.org/gnu/config/config.sub-948ae97"
      ];
    });
  };

  # MOTD showing sumo commands
  environment.etc."profile.d/sumo-motd.sh".text = ''
    #!/bin/sh
    cat <<'MOTDEOF'
╔═════════════════════════════════════════════════════════════╗
║  sumonix reasons about this machine.                       ║
║  Try:  sumo status   sumo caps   sumo closure openssl      ║
║        sumo query '(vulnerable nginx CVE-2026-9999)'       ║
║        sumo whatif   sumo dashboard                        ║
╚════════════════════════════════════════════════════════════╝
MOTDEOF
    export SUMO_FACTS=/run/sumo/facts.kif
    export SUMO_RULES=/run/sumo/rules.kif
    export PATH="/run/sumo/bin:$PATH"
  '';

  # sumo-facts service: runs before getty to populate /run/sumo/
  systemd.services.sumo-facts = {
    description = "Generate sumonix facts for the demo VM";
    wantedBy = [ "multi-user.target" ];
    before = [ "getty@ttyS0.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = sumoFactsScript;
      StandardOutput = "journal+console";
      StandardError = "journal+console";
    };
  };
}