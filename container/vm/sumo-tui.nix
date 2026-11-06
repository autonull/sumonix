# demo/vm/sumo-tui.nix — Build the sumo TUI binary
# Build-time only; the binary lives in the guest at /run/sumo/bin/sumo-tui.
# No runtime deps.

{ pkgs ? import <nixpkgs> { } }:

pkgs.go_1_23.buildGoPackage {
  pname = "sumo-tui";
  version = "0.1.0";
  src = ./tui;
  modSha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; # Will be filled by nix-prefetch-go
  vendorSha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; # Will be filled by nix-prefetch-go
  buildFlags = [ "-ldflags=-s -w" ];
}