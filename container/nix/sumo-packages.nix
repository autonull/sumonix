# nix/sumo-packages.nix — Aggregates the SUMOnix packages for the NixOS module and flake.
# `repo` is passed explicitly: callPackage would otherwise fill a bare `src`
# argument from pkgs.src (the renamed `simple-revision-control` alias).
{ pkgs ? import <nixpkgs> { }, repo ? ../../. }:

let
  callPackage = pkgs.callPackage;
in
{
  sumo-cli = callPackage ./sumo-cli.nix { inherit repo; };
  sumo-tui = callPackage ./sumo-tui.nix { src = repo + "/demo/tui"; };
  sumo-facts = callPackage ./sumo-facts.nix { inherit repo; };

  # Convenience: all packages as a list for environment.systemPackages
  all = [
    (callPackage ./sumo-cli.nix { inherit repo; })
    (callPackage ./sumo-tui.nix { src = repo + "/demo/tui"; })
    (callPackage ./sumo-facts.nix { inherit repo; })
  ];
}
