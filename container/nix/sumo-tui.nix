# nix/sumo-tui.nix — the dashboard TUI, built from demo/tui with buildGoModule.
# vendorHash is left as lib.fakeHash: set it from the build error once, or run
# `nix build .#sumo-tui` and copy the reported hash.
{ pkgs ? import <nixpkgs> { }, src ? ../../demo/tui }:

pkgs.buildGoModule {
  pname = "sumo-tui";
  version = "0.1.0";
  inherit src;
  vendorHash = "sha256-/PkD+tnmiA127i6Q0lHd/u8HZJk1BqHKKVuMWm1Z+sg=";
  ldflags = [ "-s" "-w" ];
  meta = {
    description = "SUMOnix dashboard TUI";
    platforms = pkgs.lib.platforms.linux;
  };
}
