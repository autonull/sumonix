# The declared half of the D1 scenario: postgres listening on a wildcard.
#
# nixpkgs 26.11 defaults `listen_addresses` to localhost, so the demo pins the
# wildcard explicitly — the contradiction is the firewall, not a fake default.
{ lib, ... }:
{
  services.postgresql = {
    enable = true;
    settings.listen_addresses = lib.mkForce "0.0.0.0";
  };
}
