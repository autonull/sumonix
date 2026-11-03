# mlnix eval tests/pyai.nix  ->  "ok" or a failed assertion
let
  r = import ../pyai/check.nix { merge = ../sumo.full/Merge.kif; midLevel = ../sumo.full/Mid-level-ontology.kif; };
  exp = builtins.fromJSON (builtins.readFile ../pyai/expected.json);
  check = what: ok: if ok then true else throw "failed: ${what}";
in
if builtins.all (x: x) [
  (check "no problems" (r.problems == [ ] && exp.problems == [ ]))
  (check "tally by axis matches the oracle" (r.tally == exp.tally))
  (check "values off their field's axis match" (r.offAxis == exp.offAxis))
  (check "unused Hugging Face modalities match" (r.hfUnused == exp.hfUnused))
  (check "SUMO classes per value match" (r.sumo == exp.sumo))
]
then "ok" else "failed"
