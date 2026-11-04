# NixOS VM for the sumo-nix capability discovery spike. No flake required.
#
# Build on a host with a writable /nix/store and kernel namespaces (or CI):
#   nix build -f '<nixpkgs/nixos>' vm -I nixos-config=./spike/vm.nix
# or via spike/demo.sh. The classic VM direct-boots the kernel; no GRUB needed.
{ config, pkgs, lib, ... }:

let
  # Copy only the repository source into the VM; drop VCS, local stores and build outputs.
  repoRoot = builtins.path {
    path = ../.;
    filter = path: type: !(builtins.elem (baseNameOf path)
      [ ".git" ".nix-store" ".nix-state" "result" "vm-result" ]);
  };

  # nixpkgs source of the host building the VM, so nixpkgs eval works offline inside the VM.
  nixpkgsPath = pkgs.path;

  spike = pkgs.writeShellScript "sumo-spike" ''
    set -euo pipefail
    export NIX_PATH="nixpkgs=${nixpkgsPath}"
    echo "Generating facts from live nixpkgs..."
    ${pkgs.nix}/bin/nix --extra-experimental-features 'nix-command' eval --raw --impure \
      --expr '(import ${repoRoot}/spike/nixpkgs-snapshot.nix {})' > /run/sumo-facts.kif
    echo "Running capability discovery..."
    ${pkgs.nix}/bin/nix --extra-experimental-features 'nix-command' eval --raw --impure \
      --expr '(import ${repoRoot}/spike/run-spike.nix {})'
  '';
in
{
  # The classic VM direct-boots the kernel (no GRUB); these satisfy eval-time assertions only.
  boot.loader.grub.enable = false;
  fileSystems."/" = { device = "tmpfs"; fsType = "tmpfs"; };

  # Guest resources for nixpkgs + SUMO evaluation (vmVariant declares these options)
  virtualisation.vmVariant = {
    virtualisation.memorySize = 4096;
    virtualisation.cores = 4;
  };

  environment.systemPackages = [ pkgs.nix ];

  # Generate facts from live nixpkgs and run the spike as a oneshot service at boot
  systemd.services.sumo-spike = {
    description = "Run sumo-nix capability discovery spike";
    after = [ "local-fs.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = spike;
      StandardOutput = "journal+console";
      StandardError = "journal+console";
    };
  };

  boot.kernelParams = [ "console=ttyS0" ];
  systemd.services."getty@ttyS0".wantedBy = [ "multi-user.target" ];
  networking.useDHCP = true;
  networking.hostName = "sumo-spike-vm";
  services.openssh.enable = true;
}
