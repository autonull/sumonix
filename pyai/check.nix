# Pick Your AI's taxonomy fields against Hugging Face's tags and SUMO.
#   import ./pyai/check.nix { merge; midLevel; }  ->  { problems, tally, offAxis, hfUnused, sumo }
# fields.json: the four taxonomy fields of the datasets repo's Project, at a pinned commit.
# crosswalk.json: for each value, the kind of thing it says (axis), and the HF tag or SUMO class with the same meaning.
{ merge, midLevel }:
let
  inherit (builtins) all attrNames concatMap elem elemAt filter fromJSON genList head isList isString length listToAttrs map readFile sort lessThan;
  kif = import ../lib/kif.nix { };
  fields = (fromJSON (readFile ./fields.json)).fields;
  cw = (fromJSON (readFile ./crosswalk.json)).values;
  tags = fromJSON (readFile ../hf/tags.json);
  anchorForms = kif.parse (readFile ../hf/anchors.kif);
  anchors = listToAttrs (map (f: { name = "${elemAt f 1}:${elemAt f 2}"; value = { how = elemAt f 3; cls = elemAt f 4; }; })
    (filter (f: isList f && f != [ ] && head f == "hfAnchor") anchorForms));
  base = kif.parse (readFile merge) ++ kif.parse (readFile midLevel);
  onto = import ../sumo.nix { forms = filter (f: isList f && f != [ ] && head f == "subclass" && length f == 3 && all isString f) (base ++ anchorForms); };
  known = c: onto.parents ? ${c} || any' (p: elem c p) (builtins.attrValues onto.parents);
  any' = builtins.any;
  primary = { "Dataset Modality" = "modality"; "Dataset Category" = "role"; "Access Classification" = "access"; "License/Rights Status" = "substance"; };
  entry = f: v: cw.${f}.${v};
  hfRefs = concatMap (f: filter (r: r != null) (map (v: (entry f v).hf) fields.${f})) (attrNames fields);
  sortS = sort lessThan;
  count = f: axis: length (filter (v: (entry f v).axis == axis) fields.${f});
  axesOf = f: sortS (attrNames (listToAttrs (map (v: { name = (entry f v).axis; value = 1; }) fields.${f})));
  sumoOf = f: v:
    let e = entry f v; in
    if e.sumo != null then e.sumo
    else if e.hf != null then (anchors.${e.hf} or { cls = null; }).cls
    else null;
in
{
  problems =
    concatMap (f:
      (map (v: [ "value has no crosswalk entry" f v ]) (filter (v: !(cw.${f} ? ${v})) fields.${f}))
      ++ (map (v: [ "crosswalk entry for a value the field lacks" f v ]) (filter (v: !(elem v fields.${f})) (attrNames cw.${f}))))
      (attrNames fields)
    ++ map (r: [ "hf tag not in the snapshot" r ])
      (filter (r: let p = builtins.match "([a-z]+):(.*)" r; in p == null || !(tags ? ${head p}) || !(elem (elemAt p 1) tags.${head p})) hfRefs)
    ++ map (r: [ "hf tag has no SUMO anchor" r ]) (filter (r: !(anchors ? ${r})) hfRefs)
    ++ concatMap (f: concatMap (v: let c = (entry f v).sumo; in if c != null && !(known c) then [ [ "SUMO class missing" f v c ] ] else [ ]) fields.${f}) (attrNames fields);
  tally = listToAttrs (map (f: { name = f; value = listToAttrs (map (a: { name = a; value = count f a; }) (axesOf f)); }) (attrNames fields));
  offAxis = listToAttrs (map (f: { name = f; value = filter (v: let a = (entry f v).axis; in a != primary.${f} && a != "planning") fields.${f}; }) (attrNames fields));
  # Hugging Face modality tags that no Pick Your AI value stands for.
  hfUnused = sortS (filter (t: !(elem "modality:${t}" hfRefs)) tags.modality);
  sumo = listToAttrs (map (f: { name = f; value = listToAttrs (map (v: { name = v; value = sumoOf f v; }) (filter (v: sumoOf f v != null) fields.${f})); }) (attrNames fields));
}
