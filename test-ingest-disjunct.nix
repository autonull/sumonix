# Test ingestion of disjunctive heads
let
  kif = import ./kif.nix;
  ingest = import ./reasoner/ingest.nix { };

  forms = kif.parse ''
    (=> (and (p ?x) (q ?y)) (or (r ?x) (s ?y)))
  '';
in
ingest