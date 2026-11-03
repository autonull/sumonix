# mlnix eval tests/hf.nix  ->  "ok" or a failed assertion
# hf/expected.json is hf/oracle.py's output: its own reader and ancestor search over the same three inputs.
let
  r = import ../hf/check.nix { merge = ../sumo.full/Merge.kif; midLevel = ../sumo.full/Mid-level-ontology.kif; };
  exp = builtins.fromJSON (builtins.readFile ../hf/expected.json);
  check = what: ok: if ok then true else throw "failed: ${what}";
  # The checker must be able to say no: each variant changes one line of anchors.kif and must draw one named complaint.
  text = builtins.readFile ../hf/anchors.kif;
  variant = from: to: (import ../hf/check.nix {
    merge = ../sumo.full/Merge.kif;
    midLevel = ../sumo.full/Mid-level-ontology.kif;
    anchorsText = builtins.replaceStrings [ from ] [ to ] text;
  }).violations;
  first = vs: if vs == [ ] then "none" else builtins.head (builtins.head vs);
in
if builtins.all (x: x) [
  (check "no violations" (r.violations == [ ] && exp.violations == [ ]))
  (check "anchor counts per facet and kind match the oracle" (r.anchors == exp.anchors))
  (check "the unanchored tags match" (r.unanchored == exp.unanchored))
  (check "the new classes match" (r.new == exp.new))
  (check "a class SUMO already has, declared new, is refused" (first (variant "(hfAnchor domain medical exact MedicalScience)" "(hfAnchor domain medical new MedicalScience)") == "new class missing or already in SUMO"))
  (check "an anchor outside its group is refused" (first (variant "(hfAnchor modality text exact Text)" "(hfAnchor modality text exact Seeing)") == "outside its group"))
  (check "a tag left without an anchor is refused" (first (variant "(hfAnchor modality image exact Image)\n" "") == "tag has no anchor"))
  (check "a tag that is not in the snapshot is refused" (first (variant "(hfAnchor modality text exact Text)" "(hfAnchor modality txet exact Text)") == "no such tag"))
  (check "a class SUMO lacks, declared exact, is refused" (first (variant "(hfAnchor modality text exact Text)" "(hfAnchor modality text exact Textt)") == "class not in SUMO"))
]
then "ok" else "failed"
