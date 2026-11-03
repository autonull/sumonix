# mlnix eval tests/decide.nix  ->  "ok" or a failed assertion
# tests/decide.expected.json is tests/decide-oracle.py's output.
let
  d = import ../decide.nix;
  exp = builtins.fromJSON (builtins.readFile ./decide.expected.json);
  inherit (builtins) all attrNames filter hasAttr head match split;
  check = what: ok: if ok then true else throw "failed: ${what}";
  axes = [ "modality" "domain" "task" "origin" "role" "access" "substance" "workflow" "event" "planning" "composite" ];
  classesOf = exp: filter (c: c != null) (map (k: exp.${k}.sumo) (attrNames exp));
  halves = key: filter builtins.isString (split "\\|" key);
  pyai = key: q: (d.decide {
    state = { kind = "pyai"; field = head (halves key); value = builtins.elemAt (halves key) 1; };
    questions = { inherit q; };
  }).q;
  hfq = key: q:
    let p = match "([a-z]+):(.*)" key; in (d.decide { state = { kind = "hf"; facet = head p; tag = builtins.elemAt p 1; }; questions = { inherit q; }; }).q;
  sums = a: (builtins.foldl' (s: x: s + x) 0.0 (builtins.attrValues a.probabilities)) + a.nullProbability == 1.0;
  pk = attrNames exp.pyai;
  hk = attrNames exp.hf;
  axisQ = d.Choice { ask = "axis"; options = axes; };
  sumoQ = key: d.Choice { ask = "sumoClass"; options = classesOf exp.pyai ++ classesOf exp.hf; };
  yes = a: a.top == "yes";
in
if builtins.all (x: x) [
  (check "axis of every Project value" (all (k: (pyai k axisQ).top == exp.pyai.${k}.axis) pk))
  (check "has an HF tag, for every Project value" (all (k: yes (pyai k (d.Noul { ask = "hasHfTag"; })) == exp.pyai.${k}.hasHf) pk))
  (check "SUMO class of every Project value" (all (k: (pyai k (sumoQ k)).top == exp.pyai.${k}.sumo) pk))
  (check "has a SUMO class, for every Project value" (all (k: yes (pyai k (d.Noul { ask = "hasSumoClass"; })) == exp.pyai.${k}.hasSumo) pk))
  (check "anchor kind of every HF tag" (all (k: (hfq k (d.Choice { ask = "anchorKind"; options = [ "exact" "broader" "new" "instance" ]; })).top == exp.hf.${k}.kind) hk))
  (check "SUMO class of every HF tag" (all (k: (hfq k (d.Choice { ask = "sumoClass"; options = classesOf exp.pyai ++ classesOf exp.hf; })).top == exp.hf.${k}.sumo) hk))
  (check "has an anchor, for every HF tag" (all (k: yes (hfq k (d.Noul { ask = "hasAnchor"; })) == exp.hf.${k}.hasAnchor) hk))
  (check "each answer sums to 1" (all (k: sums (pyai k axisQ)) pk && all (k: sums (hfq k (d.Noul { ask = "hasAnchor"; }))) hk))
  # The point of the null: a rule that knows nothing says null, not no.
  (check "a value the crosswalk lacks is null, not no" (let a = (d.decide { state = { kind = "pyai"; field = "Dataset Modality"; value = "Telepathy"; }; questions.q = d.Noul { ask = "hasHfTag"; }; }).q; in a.top == null && a.nullProbability == 1.0))
  (check "a tag outside the snapshot is null, not no" (let a = hfq "task:telepathy" (d.Noul { ask = "hasAnchor"; }); in a.top == null && a.nullProbability == 1.0))
  (check "a listed tag with no anchor is no" (let a = hfq "task:any-to-any" (d.Noul { ask = "hasAnchor"; }); in a.top == "no" && a.nullProbability == 0.0))
  (check "a true axis outside the options is null" ((pyai "Dataset Modality|Text" (d.Choice { ask = "axis"; options = [ "domain" "task" ]; })).top == null))
  (check "a true axis outside the options is an error when null is refused" (!(builtins.tryEval (builtins.deepSeq (pyai "Dataset Modality|Text" (d.Choice { ask = "axis"; options = [ "domain" ]; allowNull = false; })) true)).success))
  (check "an unknown ask is an error, not null" (!(builtins.tryEval (builtins.deepSeq (pyai "Dataset Modality|Text" (d.Noul { ask = "isGood"; })) true)).success))
  (check "a Noul asked as a Choice is an error" (!(builtins.tryEval (builtins.deepSeq (pyai "Dataset Modality|Text" (d.Choice { ask = "hasHfTag"; options = [ "yes" ]; })) true)).success))
]
then "ok" else "failed"
