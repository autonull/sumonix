# Crosswalk demo: typed questions over the PyAI ↔ HF ↔ SUMO crosswalk.
# Every answer is 0/1 plus an explicit null — never a guess.
let
  d = import ../../decide.nix;
  lines = r: builtins.concatStringsSep "\n" (map (item:
    let q = item.value;
    in "    ${item.name}: ${if q.top == null then "unknown (null probability ${toString q.nullProbability})" else "${q.top}"}")
    (builtins.sort (a: b: a.name < b.name)
      (builtins.attrValues (builtins.mapAttrs (name: value: { inherit name value; }) r))));
  q = {
    axis = d.Choice { ask = "axis"; options = [ "modality" "domain" "task" "workflow" "access" "license" "role" ]; };
    sumoClass = d.Choice { ask = "sumoClass"; options = [ "Text" "Image" "Document" "Process" "ContentDevelopment" ]; };
    anchorKind = d.Choice { ask = "anchorKind"; options = [ "exact" "broader" "new" "instance" ]; };
    hasAnchor = d.Noul { ask = "hasAnchor"; };
    hasHfTag = d.Noul { ask = "hasHfTag"; };
  };
  r1 = d.decide { state = { kind = "pyai"; field = "Dataset Modality"; value = "Text"; };
                  questions = { q1 = q.axis; q2 = q.sumoClass; q3 = q.hasHfTag; }; };
  r2 = d.decide { state = { kind = "hf"; facet = "modality"; tag = "text"; };
                  questions = { q4 = d.Noul { ask = "hasAnchor"; }; q5 = q.anchorKind; q6 = q.sumoClass; }; };
  r3 = d.decide { state = { kind = "hf"; facet = "task"; tag = "any-to-any"; };
                  questions = { q7 = d.Noul { ask = "hasAnchor"; }; q8 = q.anchorKind; }; };
in ''

A PyAI field: “Dataset Modality = Text” — which axis is it, and what does it mean?
${lines r1}

The same question about the HF tag  modality:text — anchored?
${lines r2}

A deliberately hard one:  task:any-to-any  (“input and output vary”) — the crosswalk answers… “I don't know”, on purpose:
${lines r3}
''
