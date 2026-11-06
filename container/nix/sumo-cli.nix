# nix/sumo-cli.nix — Derivation for the sumo CLI.
#
# Installs the filtered repo tree under $out/share/sumo and a wrapper in
# $out/bin/sumo. The wrapper is needed because bin/sumo resolves ROOT as the
# parent of its own directory and expects bin/, lib/, rules.kif and the engine
# Nix files to sit side by side.
{ pkgs ? import <nixpkgs> { }, repo ? ../../. }:

pkgs.stdenv.mkDerivation {
  pname = "sumo";
  version = "0.1.0";

  src = pkgs.lib.cleanSourceWith {
    src = repo;
    filter = path: type:
      let base = baseNameOf path; in
      !(builtins.elem base [
        ".git" ".nix-store" ".nix-state" ".nix-root" ".artifacts" ".runtime" ".logs"
        "result"
      ]) && !(pkgs.lib.hasPrefix "result-" base);
  };

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    mkdir -p $out/bin $out/share
    cp -r . $out/share/sumo
    chmod +x $out/share/sumo/bin/sumo

    makeWrapper $out/share/sumo/bin/sumo $out/bin/sumo \
      --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.nix pkgs.bashInteractive pkgs.coreutils ]} \
      --set NIX_REMOTE local \
      --set NIX_STORE_DIR /nix/store \
      --set NIX_STATE_DIR /run/sumo/nix-state \
      --set NIX_PATH nixpkgs=${pkgs.path} \
      --set SUMO_FACTS /run/sumo/facts.kif \
      --set SUMO_RULES /run/sumo/rules.kif
  '';

  nativeBuildInputs = [ pkgs.makeWrapper ];

  meta = {
    description = "SUMOnix reasoning CLI";
    platforms = pkgs.lib.platforms.linux;
  };
}
