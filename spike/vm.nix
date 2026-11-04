{ config, pkgs, lib, ... }:

let
  # Path to the sumo-nix repository (host path, copied into VM)
  sumoNixHostPath = "/home/me/sumonix";
  sumoNixVmPath = "/etc/sumo-nix";

  # Copy sumo-nix source into VM image
  sumoNixSource = pkgs.runCommand "sumo-nix-source" { } ''
    mkdir -p $out
    cp -r ${sumoNixHostPath}/* $out/
    # Ensure pins.nix.merge points to the copied Merge.kif
    sed -i 's|\./sumo\.full|'"${sumoNixVmPath}"'/sumo.full|g' $out/pins.nix
  '';

  # The spike runner — uses sumo-nix modules directly via nix eval
  spikeRunner = pkgs.writeScriptBin "sumo-spike" ''
    #!/usr/bin/env ${pkgs.runtimeShell}
    # Generate facts first
    ${pkgs.nix}/bin/nix eval --raw --expr '(import ${./nixpkgs-snapshot.nix} {})' > /run/sumo-facts.kif
    # Run spike using nix eval directly
    ${pkgs.nix}/bin/nix eval --raw --expr '(import ${./run-spike.nix} {})'
  '';

in {
  # Minimal VM config — no flake, builds fast
  boot.loader.grub.devices = [ "/dev/vda" ];
  boot.loader.grub.efiSupport = false;
  fileSystems."/" = { device = "/dev/vda"; fsType = "ext4"; };

  # sumo-nix source copied into VM
  environment.systemPackages = [ spikeRunner sumoNixSource ];

  # Run spike as oneshot service after facts exist
  systemd.services.sumo-spike = {
    description = "Run sumo-nix capability discovery spike";
    after = [ "local-fs.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${spikeRunner}";
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