# T2.1 — Disjunctive Heads: branch enumeration + per-branch fixpoint.
# Usage: ./nix-eval.sh --expr 'import ./tests/unit/disjunctive.nix'  -> "ok"
let
  kif = import ../../kif.nix;
  datalog = import ../../datalog.nix;
  ingest = import ../../reasoner/ingest.nix { };

  facts = kif.parse ''
    (p a)
    (q b)
  '';

  # Test disjunctive head using the ingestion pipeline
  # First, let's check what ingestion produces for a disjunctive rule
  # We need to feed a form that gets converted to disjunct
  # But since we can't easily add a single form to the ingestion (it parses the whole Merge.kif),
  # let's manually construct the parsed form that ingestion would produce
  rules = kif.parse ''
    (=> (and (p ?x) (q ?y)) (disjunct (r ?x) (s ?y)))
  '';

  # Test that the engine derives both (r a) and (s b) from the disjunction
  e = datalog { ontology = null; facts = facts; rules = rules; };

  check = what: ok: if ok then true else throw "failed: ${what}";
in
if builtins.all (x: x) [
  (check "disjunctive head derives first disjunct" (e.holds [ "r" "a" ]))
  (check "disjunctive head derives second disjunct" (e.holds [ "s" "b" ]))
  (check "proof includes disjunct choice" (builtins.match ".*disjunct.*" (e.explain [ "r" "a" ]) != null))
] then "ok" else "failed"