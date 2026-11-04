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

  # The spike runner — uses sumo-nix from local overlay
  spikeRunner = pkgs.writeScriptBin "sumo-spike" ''
    #!/usr/bin/env ${pkgs.runtimeShell}
    NIX_PATH="sumo-nix=${sumoNixVmPath}:${NIX_PATH}" ${pkgs.mlnix}/bin/mlnix eval ${./run-spike.nix}
  '';

  # Activation script: runs at boot (stage 2), generates KIF facts from live nixpkgs
  activationScript = pkgs.writeScript "generate-sumo-facts" ''
    #!/usr/bin/env ${pkgs.runtimeShell}
    ${pkgs.nix}/bin/nix eval --raw --expr '(import ${./nixpkgs-snapshot.nix} {})' > /run/sumo-facts.kif
  '';

in {
  # Minimal VM config — no flake, builds fast
  boot.loader.grub.devices = [ "/dev/vda" ];
  boot.loader.grub.efiSupport = false;
  fileSystems."/" = { device = "/dev/vda"; fsType = "ext4"; };

  # sumo-nix via nixpkgs (mlnix is in nixpkgs) or local overlay
  environment.systemPackages = [ pkgs.mlnix spikeRunner sumoNixSource ];

  # Generate facts early in boot
  boot.initrd.postDeviceCommands = lib.mkForce [ activationScript ];

  # Run spike as oneshot service after facts exist
  systemd.services.sumo-spike = {
    description = "Run sumo-nix vulnerability spike";
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
  systemd.services.getty@ttyS0.wantedBy = [ "multi-user.target" ];
  networking.useDHCP = true;
  networking.hostName = "sumo-spike-vm";
  services.openssh.enable = true;
}