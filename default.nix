# sumo-nix library entry point
# Usage: let sumo-nix = import <sumo-nix>; in { kif = sumo-nix.kif; sumo = sumo-nix.sumo; datalog = sumo-nix.datalog; }

{
  kif = import ./kif.nix;
  sumo = import ./sumo.nix;
  datalog = import ./datalog.nix;
  pins = import ./pins.nix;
  nixDomain = builtins.readFile ./nix-domain.kif;
}