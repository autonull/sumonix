# Test boilerplate for sumo-nix.
# Usage: import ./tests/lib.nix { };  ->  { check; }
{ }:
let
  check = what: ok:
    if ok then true else throw "test failed: ${what}";
in
{
  inherit check;
}