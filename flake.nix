{
  description = "Sumonix demo VM";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }: {
    nixosConfigurations.demo = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ({ config, pkgs, lib, ... }: {
          imports = [ ./demo/vm/vm.nix ];
          _module.args.repoRoot = self.outPath;
        })
      ];
    };
  };
}