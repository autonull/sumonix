# D1 scene 1/3 — the strict-firewall half. A real NixOS module: importing it
# with `postgres-wildcard.nix` yields a config the gate rejects with a proof
# naming both option paths. Nothing here is a hand-written fact.
{ lib, ... }:
{
  networking.firewall = {
    enable = true;
    allowedTCPPorts = lib.mkForce [ ];
  };
}
