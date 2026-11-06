# nix/sumo-facts.nix — the live facts exporter and its companion files.
#
# Installs:
#   bin/sumo-facts    — writes /run/sumo/facts.kif from this NixOS system
#   bin/sumo-refresh  — same exporter, used by `sumo refresh`
#   share/sumo/rules.kif, advisory.kif, tour.sh
#
# Live facts come from systemctl, nix-store, /proc and ss. The advisory and the
# optional facts file are appended under explicit `source: fixture` headers.
{ pkgs ? import <nixpkgs> { }, repo ? ../../. }:

let
  runtimePath = pkgs.lib.makeBinPath [
    pkgs.nix
    pkgs.systemd
    pkgs.iproute2
    pkgs.coreutils
    pkgs.gnused
    pkgs.gnugrep
    pkgs.gawk
    pkgs.findutils
    pkgs.bashInteractive
  ];
in
pkgs.stdenv.mkDerivation {
  pname = "sumo-facts";
  version = "0.1.0";
  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;
  nativeBuildInputs = [ pkgs.makeWrapper ];

  installPhase = ''
    mkdir -p $out/bin $out/share/sumo

    install -m 755 ${./sumo-facts.sh} $out/bin/sumo-facts
    makeWrapper $out/bin/sumo-facts $out/bin/sumo-refresh \
      --prefix PATH : ${runtimePath}

    install -m 644 ${repo + "/rules.kif"} $out/share/sumo/rules.kif
    install -m 644 ${repo + "/container/fixtures/policy.kif"} $out/share/sumo/advisory.kif
    install -m 644 ${repo + "/container/fixtures/rules.kif"} $out/share/sumo/facts-fixture.kif
    install -m 755 ${repo + "/container/tour.sh"} $out/share/sumo/tour.sh
  '';

  meta = {
    description = "SUMOnix live facts exporter for NixOS";
    platforms = pkgs.lib.platforms.linux;
  };
}
