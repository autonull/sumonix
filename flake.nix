{
  description = "Sumonix: SUMO reasoning over a machine's own facts";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }: {
    # NixOS module for SUMOnix integration (used by the deferred container)
    nixosModules.default = { config, lib, pkgs, ... }:
      (import ./container/nixos/sumo.nix { inherit config lib pkgs; });

    # NixOS configurations
    nixosConfigurations = {
      # Container configuration. Deferred: see container/README.md.
      sumonix-container = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          "${nixpkgs}/nixos/modules/virtualisation/lxc-container.nix"
          ./container/nixos/sumo.nix
          ({ config, pkgs, lib, ... }: {
            imports = [ ./container/container.nix ];
            _module.args.repoRoot = self.outPath;
          })
        ];
      };
    };

    # Package derivations for direct consumption
    packages.x86_64-linux = nixpkgs.lib.genAttrs [ "sumo-cli" "sumo-tui" "sumo-facts" ] (name:
      nixpkgs.lib.getAttr name {
        sumo-cli = nixpkgs.legacyPackages.x86_64-linux.callPackage ./container/nix/sumo-cli.nix { repo = self; };
        sumo-tui = nixpkgs.legacyPackages.x86_64-linux.callPackage ./container/nix/sumo-tui.nix { src = self + "/demo/tui"; };
        sumo-facts = nixpkgs.legacyPackages.x86_64-linux.callPackage ./container/nix/sumo-facts.nix { repo = self; };
      }
    );
  };
}