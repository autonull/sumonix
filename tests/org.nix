# mlnix eval tests/org.nix  ->  "ok" or a failed assertion
#
# The pages of the Pick-Your-AI repositories (org/pages.json, at the commits of org/PINS) taxonomized under SUMO, against a reading
# done again in jq (org/expected.jq, org/oracle.jq): kinds, process pages, pages declared generated, standard files each
# repository has or lacks, copies of those files, and former team names still in use.
let
  r = import ../org/check.nix { merge = ../sumo.full/Merge.kif; midLevel = ../sumo.full/Mid-level-ontology.kif; };
  exp = builtins.fromJSON (builtins.readFile ../org/expected.json);
  check = what: ok: if ok then true else throw "failed: ${what}";

  # Every class named in (pageAbout CLASS SUMO-CLASS) must be a class of the SUMO files.
  kif = import ../kif.nix;
  forms = kif.parse (builtins.readFile ../sumo.full/Merge.kif) ++ kif.parse (builtins.readFile ../sumo.full/Mid-level-ontology.kif);
  onto = import ../sumo.nix { forms = builtins.filter (f: builtins.isList f && f != [ ] && builtins.head f == "subclass" && builtins.length f == 3 && builtins.all builtins.isString f) forms; };
  about = builtins.filter (f: builtins.isList f && f != [ ] && builtins.head f == "pageAbout") (kif.parse (builtins.readFile ../org/taxonomy.kif));
  known = c: onto.parents ? ${c};

  # A small world for the rules alone. Two repositories, a default one and one that is not; the same retired team name in a doc, a
  # dated receipt, an evidence file and in the register that documents the renames.
  mk = repo: path: sha: former: { inherit repo path sha former; size = 1; title = null; marks = [ ]; };
  small = import ../org/check.nix {
    merge = ../sumo.full/Merge.kif;
    midLevel = ../sumo.full/Mid-level-ontology.kif;
    pins = "github\tPUBLIC\tmain\t0000000000000000000000000000000000000000\t1\nwork\tPUBLIC\tmain\t1111111111111111111111111111111111111111\t1\nplay\tPUBLIC\tmain\t2222222222222222222222222222222222222222\t1\n";
    pages = [
      (mk ".github" "CONTRIBUTING.md" "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" [ ])
      (mk ".github" "docs/NAMING.md" "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" [ "Mobile Devices" ])
      (mk "work" "docs/SETUP.md" "cccccccccccccccccccccccccccccccccccccccc" [ "Mobile Devices" ])
      (mk "work" "planning/X_RECEIPT.json" "dddddddddddddddddddddddddddddddddddddddd" [ "Mobile Devices" ])
      (mk "work" "evidence/x.json" "eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee" [ "Mobile Devices" ])
      (mk "work" "CONTRIBUTING.md" "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" [ ])
      (mk "work" "docs/support.md" "ffffffffffffffffffffffffffffffffffffffff" [ ])
      (mk "work" "weird/x.json" "9999999999999999999999999999999999999999" [ ])
    ];
  };
in
if builtins.all (x: x) [
  (check "page count" (r.pages == exp.pages))
  (check "no page is left unclassified, or the same ones are" (r.unclassified == exp.unclassified))
  (check "kinds" (r.kinds == exp.kinds))
  (check "process pages, by subclass reasoning" (r.processPages == exp.processPages))
  (check "pages and process pages of each repository" (r.byRepo == exp.byRepo))
  (check "process pages that say they were generated" (r.generatedProcessPages == exp.generatedProcessPages))
  (check "repositories that have each standard file" (r.present == exp.present))
  (check "repositories that lack each standard file" (r.lacks == exp.lacks))
  (check "copies of the standard files" (r.copies == exp.copies))
  (check "former team names still in use" (r.staleNames == exp.staleNames))
  (check "every SUMO class a page kind is about exists" (builtins.all (f: known (builtins.elemAt f 2)) about))
  (check "a proof exists for a stale name" (builtins.length r.staleNames == 0 || builtins.stringLength (r.why [ "staleName" (builtins.elemAt (builtins.head r.staleNames) 0) (builtins.elemAt (builtins.head r.staleNames) 1) ]) > 0))

  # The rules alone, on the small world.
  (check "small: only the doc is stale; the receipt, the evidence file and the register are not" (small.staleNames == [ [ "work:docs/SETUP.md" "mobile-devices" ] ]))
  (check "small: a page no rule matches is said to be unknown" (small.unclassified == [ "work:weird/x.json" ]))
  (check "small: a repository inherits a standard file the default repository has" (small.lacks.ContributingGuide == [ ]))
  (check "small: no repository inherits a file the default repository lacks" (small.lacks.SecurityPolicy == [ "github" "play" "work" ]))
  (check "small: the default repository does not give itself a file it lacks" (small.lacks.SupportGuide == [ "github" "play" ]))
  (check "small: two repositories with the same file are identical copies" (small.copies.ContributingGuide == { pages = 2; distinctBlobs = 1; largestIdentical = 2; identicalPairs = 2; divergentPairs = 0; }))
  (check "small: one page in a role has no copy" (small.copies.SupportGuide == { pages = 1; distinctBlobs = 1; largestIdentical = 1; identicalPairs = 0; divergentPairs = 0; }))
  (check "small: a CODEOWNERS file is not inherited" (small.lacks.CodeOwnersFile == [ "github" "play" "work" ]))
]
then "ok" else "failed"
