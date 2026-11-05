# mlnix eval tests/bags.nix  ->  "ok" or a failed assertion
# bags.expected.json is bags-oracle.py's output (its own reader, its own categories, its own list of non-Horn files).
let
  root = ../.;
  b = import ../bags.nix { inherit root; };
  tq = import ../tq.nix { ontology = (import ../lib/kif.nix { }).parse (builtins.readFile ../sumo.full/Merge.kif); };
  exp = builtins.fromJSON (builtins.readFile ./bags.expected.json);
  inherit (builtins) all any attrNames elem filter length;
  sort = builtins.sort builtins.lessThan;
  check = what: ok: if ok then true else throw "failed: ${what}";
  macro = filter (n: b.bags.${n}.files != [ ]) b.names;
  allFiles = builtins.concatLists (map (n: b.bags.${n}.files) macro);
  dups = filter (f: length (filter (g: g == f) allFiles) > 1) allFiles;
  results = map (f: tq.run (tq.read (../sumo.tests + "/${f}"))) b.bags.tests-all.tests;
  verdict = v: filter (r: r.verdict == v) results;
  p = b.compose [ "military" "tests-spatial" ];
  flat = builtins.replaceStrings [ "\n" ] [ " " ];
  mentions = text: s: builtins.match (".*" + s + ".*") (flat text) != null;
in
if builtins.all (x: x) [
  (check "the macro sets cover the pinned corpus: ${toString (length allFiles)} of ${toString exp.kb}" (length allFiles == exp.kb))
  (check "no file is in two macro sets" (dups == [ ]))
  (check "every file of a macro set exists" (all (f: builtins.pathExists (../sumo.full + "/${f}")) allFiles))
  (check "test bag sizes follow the declared categories"
    (length b.bags.tests-general.tests == exp.categories.general && length b.bags.tests-spatial.tests == exp.categories.spatial
      && length b.bags.tests-modal.tests == exp.categories.modal && length b.bags.tests-all.tests == exp.tq))
  (check "the unsupported files are the oracle's" (sort (map (r: r.name) (verdict "unsupported")) == sort exp.unsupported))
  (check "no test file fails" (verdict "fail" == [ ]))
  (check "every supported file passes or is open" (length (verdict "pass") + length (verdict "open") == exp.tq - length exp.unsupported))
  (check "ten files pass (a regression guard: raise it when the solver improves)" (length (verdict "pass") == 10))
  (check "compose adds core, first" (p.bags == [ "core" "military" "tests-spatial" ] && p.added == [ "core" ]))
  (check "compose lists the files to load, core first" (builtins.head p.files == "Merge.kif" && length p.load == length p.files))
  (check "compose does not repeat a bag" ((b.compose [ "core" "military" "core" ]).bags == [ "core" "military" ]))
  (check "an unknown bag is an error" (!(builtins.tryEval (builtins.deepSeq (b.compose [ "nonesuch" ]) true)).success))
  (check "match offers a bag only when its needs are in the plan" (!(elem "military" (b.matches [ ])) && elem "military" (b.matches [ "core" ])))
  (check "match leaves out what the plan holds" (!(elem "core" (b.matches [ "core" ]))))
  (check "the front screen names every bag" (all (n: mentions b.help.top n) b.names))
  (check "a bag screen lists every file of the bag" (all (f: mentions (b.help.bag "society") f) b.bags.society.files))
  (check "the list has a line per bag" (length (filter (l: l != "") (builtins.filter builtins.isString (builtins.split "\n" b.list))) == length b.names))
]
then "ok" else "failed"
