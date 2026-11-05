# org/check.nix: the pages of the Pick-Your-AI repositories, taxonomized under SUMO.
#
#   import ./org/check.nix { merge; midLevel; }  ->  { pages, unclassified, kinds, processPages, byRepo, generatedProcessPages,
#                                                    present, lacks, copies, staleNames, why }
# merge and midLevel are the paths of Merge.kif and Mid-level-ontology.kif.  org/pages.json is the page list (org/extract.nix) at the
# commits of org/PINS; org/classify.nix says what each page is; org/taxonomy.kif puts the kinds under SUMO's Document; the Horn rules
# of org/rules.kif and org/rules-closed.kif (two strata) draw the conclusions, and `why` prints the proof of any one of them.
{ merge, midLevel, pages ? builtins.fromJSON (builtins.readFile ./pages.json), pins ? builtins.readFile ./PINS }:
let
  inherit (builtins) all attrNames attrValues elem elemAt filter foldl' fromJSON groupBy head isList isString length listToAttrs map mapAttrs readFile sort lessThan;
  kif = import ../lib/kif.nix { };
  engine = import ../datalog.nix;
  names = import ./names.nix;
  cls = import ./classify.nix;

  facts = import ./facts.nix { inherit pages pins; };

  taxonomy = kif.parse (readFile ./taxonomy.kif);
  isRule = f: isList f && f != [ ] && head f == "=>";
  rules1 = filter isRule (kif.parse (readFile ./rules.kif));
  rules2 = filter isRule (kif.parse (readFile ./rules-closed.kif));

  base = kif.parse (readFile merge) ++ kif.parse (readFile midLevel);
  structural = filter (f: isList f && f != [ ] && head f == "subclass" && length f == 3 && all isString f);
  onto = import ../sumo.nix { forms = structural (base ++ taxonomy); };

  s1 = engine { ontology = onto; rules = rules1; inherit facts; };
  s2 = engine { ontology = onto; rules = rules2; facts = s1.facts; };

  sortS = sort lessThan;
  uniq = xs: attrNames (listToAttrs (map (x: { name = x; value = null; }) xs));
  maxOf = foldl' (a: b: if b > a then b else a) 0;

  # What the finished facts say: one row of values for each answer.
  ask = pattern: vars: map (b: map (v: b.${v}) vars) (s2.ask pattern);

  kindOf = p: (cls.classify p.path).kind;
  repoOf = p: names.atom p.repo;

  processIds = uniq (map head (ask [ "instance" "?P" "ProcessPage" ] [ "?P" ]));
  publicRepos = map head (ask [ "publicRepo" "?R" ] [ "?R" ]);
  hasRole = ask [ "hasRole" "?R" "?Role" ] [ "?R" "?Role" ];
  lacksRole = ask [ "lacksRole" "?R" "?Role" ] [ "?R" "?Role" ];
  identical = ask [ "identicalCopy" "?A" "?B" "?Role" ] [ "?A" "?B" "?Role" ];
  divergent = ask [ "divergentCopy" "?A" "?B" "?Role" ] [ "?A" "?B" "?Role" ];
  roleOf = ask [ "roleOf" "?P" "?Role" ] [ "?P" "?Role" ];
  blobOf = listToAttrs (map (r: { name = elemAt r 0; value = elemAt r 1; }) (ask [ "blob" "?P" "?S" ] [ "?P" "?S" ]));

  expectedRoles = map head (ask [ "expectedRole" "?Role" ] [ "?Role" ]);
  comparedRoles = uniq (map (r: elemAt r 1) roleOf);
  inRole = role: rows: filter (r: elemAt r (length r - 1) == role) rows;
in
{
  pages = length pages;
  unclassified = sortS (map head (ask [ "unclassified" "?P" ] [ "?P" ]));
  kinds = mapAttrs (_: length) (groupBy kindOf (filter (p: kindOf p != null) pages));
  processPages = length processIds;
  byRepo = mapAttrs
    (_: ps: { pages = length ps; processPages = length (filter (p: elem (names.pageId p) processIds) ps); })
    (groupBy repoOf pages);
  generatedProcessPages = length (uniq (map head (ask [ "generatedProcessPage" "?P" "?M" ] [ "?P" "?M" ])));
  present = listToAttrs (map
    (role: { name = role; value = length (filter (r: elemAt r 1 == role && elem (head r) publicRepos) hasRole); })
    expectedRoles);
  lacks = listToAttrs (map (role: { name = role; value = sortS (map head (inRole role lacksRole)); }) expectedRoles);
  copies = listToAttrs (map
    (role:
      let
        ps = map head (inRole role roleOf);
        sizes = map length (attrValues (groupBy (i: blobOf.${i}) ps));
      in
      {
        name = role;
        value = {
          pages = length ps;
          distinctBlobs = length sizes;
          largestIdentical = maxOf sizes;
          identicalPairs = length (inRole role identical);
          divergentPairs = length (inRole role divergent);
        };
      })
    comparedRoles);
  staleNames = sortS (ask [ "staleName" "?P" "?N" ] [ "?P" "?N" ]);
  why = f: s2.explain f;
}
