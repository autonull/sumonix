# D1 — the operator's configuration for the touring container: the wildcard
# postgres listener (postgres-wildcard.nix) with the firewall that allows its
# port. This is the "fixed" config the container boots; d1-bad-firewall.nix is
# the contradicting variant the gate rejects and `sumo repair` fixes.
{ ... }:
{
  imports = [ ./postgres-wildcard.nix ];

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 5432 ];
  };
}
