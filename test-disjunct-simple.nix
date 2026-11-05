let
  kif = import ./kif.nix;
  datalog = import ./datalog.nix;

  facts = kif.parse ''
    (p a)
    (q b)
  '';

  rules = [ [ "=>" [ "and" [ "p" "?x" ] [ "q" "?y" ] ] [ "disjunct" [ "r" "?x" ] [ "s" "?y" ] ] ];

  e = datalog { ontology = null; facts = facts; rules = rules; };
in
e.holds [ "r" "a" ]