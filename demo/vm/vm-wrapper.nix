{ pkgs ? import <nixpkgs> { }, repoRoot ? "/home/me/sumonix", configFile ? ./vm.nix }:
let
  nixos = import <nixpkgs/nixos> {
    specialArgs = { inherit repoRoot; };
  };
in
nixos.vm