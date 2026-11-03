# Typed questions over the taxonomy crosswalks, answered by rules.
#
# A question names a rule; the answer is a probability for each option and an explicit null.  The backend is rules over
# pyai/crosswalk.json, hf/tags.json and hf/anchors.kif, so a probability is 1 or 0, and a rule that has no entry for a value
# answers null, not no.  This is lookup and checking, not a trained model: nothing here learns, guesses or generates.
#
#   d = import ./decide.nix
#   d.decide {
#     state = { kind = "pyai"; field = "Dataset Modality"; value = "Code"; };
#     questions = {
#       axis  = d.Choice { ask = "axis"; options = [ "modality" "domain" "task" ]; };
#       hasHf = d.Noul { ask = "hasHfTag"; };
#     };
#   }
#   -> { axis = { probabilities = { modality = 0; domain = 1; task = 0; }; nullProbability = 0; top = "domain"; };
#        hasHf = { probabilities = { yes = 1; no = 0; }; nullProbability = 0; top = "yes"; }; }
#
# States:  { kind = "pyai"; field; value }   a value of a Pick Your AI Project field (pyai/crosswalk.json)
#          { kind = "hf"; facet; tag }       a Hugging Face tag (hf/tags.json, hf/anchors.kif)
# Asks:    pyai  axis (Choice), sumoClass (Choice), hasHfTag (Noul), hasSumoClass (Noul)
#          hf    anchorKind (Choice among exact broader new instance), sumoClass (Choice), hasAnchor (Noul)
# Not built: Score, and free-text instructions (rules cannot read them, so `ask` names the rule).
let
  inherit (builtins) attrNames elem elemAt filter fromJSON head isList length listToAttrs map mapAttrs readFile;
  kif = import ./kif.nix;
  cw = (fromJSON (readFile ./pyai/crosswalk.json)).values;
  tags = fromJSON (readFile ./hf/tags.json);
  anchors = listToAttrs (map (f: { name = "${elemAt f 1}:${elemAt f 2}"; value = { how = elemAt f 3; cls = elemAt f 4; }; })
    (filter (f: isList f && f != [ ] && head f == "hfAnchor") (kif.parse (readFile ./hf/anchors.kif))));

  # Answers.  Every answer sums to 1 over its options and the null.
  zero = options: listToAttrs (map (o: { name = o; value = 0.0; }) options);
  nothing = options: { probabilities = zero options; nullProbability = 1.0; top = null; };
  one = options: pick: { probabilities = zero options // { ${pick} = 1.0; }; nullProbability = 0.0; top = pick; };
  # A Choice whose true answer is `pick` (or null when the rules have none).
  choice = q: pick:
    if pick == null then (if q.allowNull or true then nothing q.options else throw "no rule answers and null is not allowed")
    else if !(elem pick q.options) then (if q.allowNull or true then nothing q.options else throw "'${pick}' is not among the options and null is not allowed")
    else one q.options pick;
  # A Noul whose true answer is yes, no, or null.
  noul = ans: if ans == null then nothing [ "yes" "no" ] else one [ "yes" "no" ] (if ans then "yes" else "no");

  pyai = state:
    let e = cw.${state.field}.${state.value} or null; in {
      axis = q: choice q (if e == null then null else e.axis);
      sumoClass = q: choice q (if e == null then null else if e.sumo != null then e.sumo else if e.hf != null then (anchors.${e.hf} or { cls = null; }).cls else null);
      hasHfTag = _: noul (if e == null then null else e.hf != null);
      hasSumoClass = _: noul (if e == null then null else e.sumo != null || (e.hf != null && anchors ? ${e.hf}));
    };

  hf = state:
    let
      key = "${state.facet}:${state.tag}";
      listed = tags ? ${state.facet} && elem state.tag tags.${state.facet};
      a = anchors.${key} or null;
    in {
      anchorKind = q: choice q (if a == null then null else a.how);
      sumoClass = q: choice q (if a == null then null else a.cls);
      hasAnchor = _: noul (if !listed then null else a != null);
    };

  backends = { inherit pyai hf; };
in
rec {
  Choice = args: { type = "choice"; allowNull = true; } // args;
  Noul = args: { type = "noul"; } // args;

  decide = { state, questions }:
    let
      asks = (backends.${state.kind} or (throw "unknown state kind '${state.kind}'")) state;
      answer = name: q:
        let rule = asks.${q.ask} or (throw "question '${name}': no rule for '${q.ask}' on a ${state.kind} state; try ${toString (attrNames asks)}"); in
        if (q.type == "choice") == (elem q.ask [ "axis" "sumoClass" "anchorKind" ]) then rule q
        else throw "question '${name}': '${q.ask}' is not a ${q.type}";
    in mapAttrs answer questions;
}
