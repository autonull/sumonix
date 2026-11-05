# demo/vm/vm-minimal.nix — Minimal NixOS VM for sumonix demo
# Only includes: kernel, initrd, bash, coreutils, nix, our repo
# No openssh, no systemd services beyond essentials, no extra packages
{ config, pkgs, lib, repoRoot, ... }:

let
  repo = builtins.path {
    path = repoRoot;
    filter = path: type: !(builtins.elem (baseNameOf path)
      [ ".git" ".nix-store" ".nix-state" "result" "result-*" "vm-result" "demo/vm/result-*" ]);
  };

  nixpkgsPath = pkgs.path;

  sumoScript = pkgs.writeShellScriptBin "sumo" ''
    #!/bin/sh
    export NIX_STORE_DIR=/nix/store
    export NIX_STATE_DIR=/nix/var/nix
    export NIX_PATH="nixpkgs=${nixpkgsPath}"
    export SUMO_FACTS=/run/sumo/facts.kif
    export SUMO_RULES=/run/sumo/rules.kif
    exec ${repo}/bin/sumo "$@"
  '';

  sumoFactsScript = pkgs.writeShellScript "sumo-facts" ''
    #!/bin/sh
    set -euo pipefail
    mkdir -p /run/sumo
    cp ${repo}/demo/vm/host-facts.kif /run/sumo/facts.kif
    cp ${repo}/rules.kif /run/sumo/rules.kif
    ln -sf ${repo} /run/sumo/repo
    mkdir -p /run/sumo/bin
    ln -sf ${sumoScript} /run/sumo/bin/sumo
  '';

in
{
  # Minimal VM: no GRUB, tmpfs root, serial console only
  boot.loader.grub.enable = false;
  fileSystems."/" = { device = "tmpfs"; fsType = "tmpfs"; options = [ "size=90%" ]; };

  # Minimal resources
  virtualisation.vmVariant = {
    virtualisation.memorySize = 1024;
    virtualisation.cores = 2;
  };

  boot.kernelParams = [ "console=ttyS0" ];
  systemd.services."getty@ttyS0".wantedBy = [ "multi-user.target" ];

  # No network, no SSH - purely local demo
  networking.useDHCP = false;
  networking.hostName = "sumonix-demo";

  # Absolute minimum packages
  environment.systemPackages = with pkgs; [
    bashInteractive
    coreutils
    nix
    sumoScript
  ];

  # No nix daemon, no substituters config needed (eval only)
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # MOTD
  environment.etc."profile.d/sumo-motd.sh".text = ''
    #!/bin/sh
    cat <<'MOTDEOF'
╔══════════════════════════════════════════════════════════════╗
║  sumonix reasons about this machine.                       ║
║  Try:  sumo status   sumo caps   sumo closure openssl      ║
║        sumo query '(vulnerable nginx CVE-2026-9999)'       ║
║        sumo whatif   sumo dashboard                        ║
╚═════════════════════════════════════════════════════════════╝
MOTDEOF
    export SUMO_FACTS=/run/sumo/facts.kif
    export SUMO_RULES=/run/sumo/rules.kif
    export PATH="/run/sumo/bin:$PATH"
  '';

  # sumo-facts service
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

  # Disable unnecessary services
  systemd.services.systemd-journald.serviceConfig.Storage = "volatile";
  services.getty.autologinUser = "root";
  users.users.root.password = "";
}