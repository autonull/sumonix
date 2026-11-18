# D1 scene 1/3 — the contradiction as a real NixOS module: postgres listens on
# a wildcard and the firewall allows nothing. `sumo gate` rejects it with a
# proof naming both option paths; `sumo repair` proposes the single-option fixes.
{ ... }:
{
  imports = [ ./postgres-wildcard.nix ./d1-bad-firewall.nix ];
}
