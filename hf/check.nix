# Checks hf/anchors.kif against hf/tags.json and the SUMO files.
#   import ./hf/check.nix { merge; midLevel; }  ->  { anchors, unanchored, new, violations }
{ merge, midLevel, anchorsText ? builtins.readFile ./anchors.kif }:
let
  inherit (builtins) all any attrNames concatMap elem filter foldl' fromJSON head isList isString length listToAttrs map readFile sort lessThan;
  kif = import ../lib/kif.nix { };
  snap = fromJSON (readFile ./tags.json);
  mine = kif.parse anchorsText;
  base = kif.parse (readFile merge) ++ kif.parse (readFile midLevel);
  plain = f: all isString f;
  withHead = h: fs: filter (f: isList f && f != [ ] && head f == h) fs;
  onto = import ../sumo.nix { forms = filter (f: isList f && f != [ ] && head f == "subclass" && length f == 3 && plain f) (base ++ mine); };
  inSumo = import ../sumo.nix { forms = filter (f: isList f && f != [ ] && head f == "subclass" && length f == 3 && plain f) base; };
  known = c: inSumo.parents ? ${c} || any (p: elem c p) (builtins.attrValues inSumo.parents);
  groups = listToAttrs (map (f: { name = builtins.elemAt f 1; value = builtins.elemAt f 2; }) (withHead "hfGroup" mine));
  anchors = map (f: { facet = builtins.elemAt f 1; tag = builtins.elemAt f 2; how = builtins.elemAt f 3; cls = builtins.elemAt f 4; }) (withHead "hfAnchor" mine);
  unanchored = map (f: [ (builtins.elemAt f 1) (builtins.elemAt f 2) ]) (withHead "hfUnanchored" mine);
  declared = map (f: builtins.elemAt f 1) (filter plain (withHead "subclass" mine));
  key = facet: tag: "${facet} ${tag}";
  covered = listToAttrs (map (a: { name = key a.facet a.tag; value = true; }) anchors ++ map (u: { name = key (head u) (builtins.elemAt u 1); value = true; }) unanchored);
  problems = a:
    (if !(elem a.tag snap.${a.facet}) then [ [ "no such tag" a.facet a.tag ] ] else [ ])
    ++ (if (a.how == "exact" || a.how == "broader" || a.how == "instance") && !(known a.cls) then [ [ "class not in SUMO" a.facet a.tag a.cls ] ] else [ ])
    ++ (if a.how == "new" && (!(elem a.cls declared) || known a.cls) then [ [ "new class missing or already in SUMO" a.facet a.tag a.cls ] ] else [ ])
    ++ (if a.how != "instance" && a.cls != groups.${a.facet} && !(onto.isSubclass a.cls groups.${a.facet}) then [ [ "outside its group" a.facet a.tag a.cls groups.${a.facet} ] ] else [ ]);
  parentProblems = map (f: [ "parent not in SUMO" (builtins.elemAt f 1) (builtins.elemAt f 2) ])
    (filter (f: !(known (builtins.elemAt f 2)) && !(elem (builtins.elemAt f 2) declared)) (filter plain (withHead "subclass" mine)));
  missing = concatMap (facet: map (t: [ "tag has no anchor" facet t ]) (filter (t: !(covered ? ${key facet t})) snap.${facet})) (attrNames groups);
  count = facet: how: length (filter (a: a.facet == facet && a.how == how) anchors);
in
{
  anchors = listToAttrs (map (facet: { name = facet; value = listToAttrs (map (how: { name = how; value = count facet how; }) (filter (h: count facet h > 0) [ "broader" "exact" "instance" "new" ])); }) (attrNames groups));
  unanchored = sort (a: b: lessThan (builtins.toJSON a) (builtins.toJSON b)) unanchored;
  new = sort lessThan declared;
  violations = concatMap problems anchors ++ parentProblems ++ missing;
}
