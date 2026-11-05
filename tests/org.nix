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
  kif = import ../lib/kif.nix { };
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

  # --- dates.  The calendar against the day numbers jq works out (tests/months.json: the first of every month, 2000-01 to 2100-01).
  t = import ../org/time.nix;
  months = builtins.fromJSON (builtins.readFile ./months.json);
  pad = n: if n < 10 then "0${toString n}" else toString n;
  date = y: m: d: "${toString y}-${pad m}-${pad d}";
  monthOk = i:
    let
      y = 2000 + i / 12;
      m = i - i / 12 * 12 + 1;
      first = builtins.elemAt months i;
      len = builtins.elemAt months (i + 1) - first;
    in t.parse (date y m 1) == first && t.parse (date y m len) == first + len - 1 && t.parse (date y m (len + 1)) == null && t.monthDays y m == len;

  # The cues, on a small tree of files (tests/org-time): one line for each thing that went wrong in the real pages.
  fx = import ../org/extract.nix {
    trees = ./org-time/trees;
    src = ./org-time/src;
    pins = "fx\tPUBLIC\tmain\t0000000000000000000000000000000000000000\t6\n";
  };
  fxPage = path: builtins.head (builtins.filter (p: p.path == path) fx);
  show = items: map (i: "${i.d} ${i.cue} ${i.loc}${if i ? at then " @${i.at}" else ""}${if i ? label then " [${i.label}${if i ? priority then " ${i.priority}" else ""}]" else ""}") items;
  cues = (fxPage "cues.md").time;
  rec' = (fxPage "rec.json").time;
  big = (fxPage "big.json").time;
  at = items: loc: builtins.any (i: i.loc == loc) items;
  has = items: s: builtins.elem s (show items);
  seen = loc: at cues.to loc || at cues.from loc;

  # One line for each word of the lexicon (tests/org-time/src/fx/lexicon.md): the ends, the starts, the joining words, the as-of words.
  endCues = [ "deadline" "due" "expires" "expire" "expiry" "expiration" "until" "through" "valid to" "end" "ends" "no later than" "review by" "refresh by" "next review" "before" "cutoff" ];
  startCues = [ "effective" "start" "starts" "starting" "begin" "begins" "since" "from" "after" ];
  joiners = [ "is" "was" "are" "on" "by" "at" "the" "a" "an" "of" "for" "in" "as" "or" "set" "utc" "date" "time" "local" "day" "next" "final" "current" "to" ];
  nEnds = builtins.length endCues;
  nStarts = builtins.length startCues;
  nJoin = builtins.length joiners;
  lex = (fxPage "lexicon.md").time;
  lexEnds = builtins.genList (i: "2027-01-${pad (i + 1)} ${builtins.elemAt endCues i} L${toString (i + 1)}") nEnds
    ++ builtins.genList (i: "2027-03-${pad (i + 1)} deadline L${toString (nEnds + nStarts + i + 1)}") nJoin;
  lexStarts = builtins.genList (i: "2027-02-${pad (i + 1)} ${builtins.elemAt startCues i} L${toString (nEnds + i + 1)}") nStarts;

  # One line for each month name and each way to write a date in words (tests/org-time/src/fx/months.md).
  monthNames = [ "January" "February" "March" "April" "May" "June" "July" "August" "September" "October" "November" "December" "Jan" "Feb" "Mar" "Apr" "Jun" "Jul" "Aug" "Sep" "Sept" "Oct" "Nov" "Dec" ];
  monthNums = [ 1 2 3 4 5 6 7 8 9 10 11 12 1 2 3 4 6 7 8 9 9 10 11 12 ];
  nNames = builtins.length monthNames;
  wordsT = (fxPage "months.md").time;
  wordsExpected =
    builtins.genList (i: "2028-${pad (builtins.elemAt monthNums i)}-05 deadline L${toString (i + 1)}") nNames
    ++ builtins.genList (i: "2028-${pad (builtins.elemAt monthNums i)}-06 deadline L${toString (nNames + i + 1)}") nNames
    ++ builtins.genList (i: "${builtins.elemAt [ "2028-11-12" "2028-11-13" "2028-11-14" "2028-11-15" "2028-11-01" "2028-11-02" "2028-11-03" "2028-11-04" "2028-11-01" "2028-11-02" "2028-11-03" "2028-11-04" ] i} deadline L${toString (2 * nNames + i + 1)}") 12
    ++ [ "2099-11-05 deadline L${toString (2 * nNames + 15)}" ];

  # --- the margins, on a small world.  Seven ends from yesterday to a month and a day away, two starts, and the rest.
  it = d: cue: loc: extra: { inherit d cue loc; } // extra;
  pg = repo: path: to: from: { inherit repo path; time = { asof = null; other = 0; inherit to from; }; };
  due = today: pages: import ../org/due.nix { inherit pages today; };
  world = [
    (pg "r" "a.md"
      [ (it "2026-11-02" "deadline" "L1" { }) (it "2026-11-03" "deadline" "L2" { at = "11:00:00Z"; }) (it "2026-11-04" "until" "L3" { })
        (it "2026-11-10" "until" "L4" { }) (it "2026-11-11" "until" "L5" { }) (it "2026-12-03" "until" "L6" { }) (it "2026-12-04" "until" "L7" { })
        (it "2026-11-01" "until" "L10" { }) (it "2026-10-20" "until" "L11" { }) ]
      [ (it "2026-11-05" "effective" "L8" { }) (it "2026-10-01" "effective" "L9" { }) (it "2026-11-03" "starts" "L12" { }) ])
    { repo = "r"; path = "dateless.md"; time = null; }
    { repo = "r"; path = "no-time-field.md"; }
  ];
  d0 = due "2026-11-03" world;
  lab = repo: path: label: priority: cue: date: pg repo path [ (it date cue "/x" ({ inherit label; } // (if priority == null then { } else { inherit priority; }))) ] [ ];
  group = (due "2026-11-03" [
    (lab "r" "p2.json" "K" null "due" "2026-11-20")
    (lab "r" "p1.json" "K" "P2" "deadline" "2026-11-20")
    (lab "r" "p0.json" "K" null "deadline" "2026-11-20")
    (lab "r" "p7.json" "M" null "deadline" "2026-11-25")
    (pg "r" "p8.json" [ (it "2026-11-25" "deadline" "/x" { label = "M"; at = "09:00:00Z"; }) ] [ ])
    (lab "s" "p3.json" "K" null "deadline" "2026-11-20")
    (lab "r" "p4.json" "B" "P2" "deadline" "2026-11-09")
    (lab "r" "p5.json" "A" null "deadline" "2026-11-09")
    (lab "r" "p6.json" "C" "P1" "deadline" "2026-11-09")
  ]).ends.ahead;
  ex = pages: examples: (import ../org/due.nix { inherit pages examples; today = "2026-11-03"; }).ends.ahead;
  examplePages = map (path: pg "r" path [ (it "2026-11-05" "deadline" "L1" { }) ] [ ]) [
    "templates/examples/x.md" "a/examples/b.md" "a/tests/b.json" "a/fixtures/b.json" "a/testdata/b.json" "a/__tests__/b.json" "Packages/X/Tests/Y.json" "tests/root.json" "docs/real.md" ];
  days = today: date: (due today [ (pg "r" "a.md" [ (it date "deadline" "L1" { }) ] [ ]) ]).ends.ahead;
  realDue = import ../org/due.nix { pages = builtins.fromJSON (builtins.readFile ../org/pages.json); today = "2026-11-03"; };
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

  # The calendar.
  (check "calendar: every month of 2000..2099 has the first and last day jq gives, and no day after" (builtins.all monthOk (builtins.genList (i: i) 1200)))
  (check "calendar: days outside 2000..2099 and months and days that do not exist are not dates" (builtins.all (s: t.parse s == null) [ "1999-12-31" "2100-01-01" "2026-00-10" "2026-13-01" "2026-01-00" "2026-02-29" "2100-02-28" "abc" "" "2026-1-1" ]))
  (check "calendar: leap days of 2000 and 2028 are dates, 2100 is out of range" (t.parse "2000-02-29" != null && t.parse "2028-02-29" != null && t.parse "2027-02-29" == null))

  # The cues.
  (check "dates: the files that are not pages are not read" (map (p: p.path) fx == [ "big.json" "cues.md" "lexicon.md" "months.md" "only-dmy.md" "only-mdy.md" "rec.json" "runs/measure-2026-10-18.md" ]))
  (check "words: a page whose only dates are written in words is still read" (show (fxPage "only-mdy.md").time.to == [ "2028-01-05 deadline L1" ] && show (fxPage "only-dmy.md").time.to == [ "2028-01-06 deadline L1" ]))
  (check "lexicon: every end word, and every joining word after an end, is read" (show lex.to == lexEnds))
  (check "lexicon: every start word is read" (show lex.from == lexStarts))
  (check "lexicon: every as-of word and every data bound is read, and the breaks after a cue leave a date with no role" (lex.asof == { min = "2027-04-01"; max = "2027-06-06"; n = 40; maxLoc = "L90"; } && lex.other == 9))
  (check "words: every month name, written both ways, and the ways to write a day, are read; a day that does not exist and the year 2100 are not" (show wordsT.to == wordsExpected && wordsT.from == [ ] && wordsT.asof == null && wordsT.other == 0))
  (check "dates: ends of cues.md" (show cues.to == [
    "2026-11-03 deadline L2" "2027-03-02 deadline L3" "2026-11-30 until L4" "2026-11-30 through L5" "2027-01-06 cutoff L11" "2026-12-01 review by L15"
    "2026-12-15 next review L17" "2026-12-31 end L20" "2027-01-14 expires L22 @05:33:25Z" "2027-04-30 through L24" "2027-06-01 expires L25 @05:33:25.250+02:00" ]))
  (check "dates: starts of cues.md" (show cues.from == [ "2026-11-12 effective L5" "2026-09-01 effective L14" "2027-03-03 starts L19" ]))
  (check "dates: as-of dates of cues.md" (cues.asof == { min = "2026-10-17"; max = "2026-10-21"; n = 5; maxLoc = "L10"; }))
  (check "dates: a date with no cue is neither an end nor a start, and is counted" (cues.other == 6))
  (check "dates: a cue is a whole word, a word that ends with one is not a cue" (!(seen "L26")))
  (check "dates: the page record keeps what the tree says" (let p = fxPage "cues.md"; in builtins.removeAttrs p [ "time" ] == { repo = "fx"; path = "cues.md"; sha = "2222222222222222222222222222222222222222"; size = 1000; title = "Cue cases"; marks = [ ]; former = [ ]; named = [ ]; }))
  (check "dates: a cue is a whole word, throughput is not through" (!(seen "L6") && !(seen "L7")))
  (check "dates: a cue must be right before the date, submitted through X at D is not an end" (!(seen "L8")))
  (check "dates: a cue and a date with a word between them are not joined" (!(seen "L13")))
  (check "dates: a table cell break stops a cue" (!(seen "L9")))
  (check "dates: an observation cutoff is a data bound, a new-job cutoff is an end" (!(seen "L10") && has cues.to "2027-01-06 cutoff L11"))
  (check "dates: a version is not an end or a start" (!(seen "L12")))
  (check "dates: camelCase splits into words" (has cues.from "2026-09-01 effective L14"))
  (check "dates: review is an end only with by, or after next" (!(seen "L16") && !(seen "L21") && has cues.to "2026-12-01 review by L15" && has cues.to "2026-12-15 next review L17"))
  (check "dates: a day that does not exist and a date glued to digits are not dates" (!(seen "L18")))
  (check "dates: dates written in words are read" (has cues.from "2026-11-12 effective L5" && has cues.to "2026-11-30 through L5" && has cues.from "2027-03-03 starts L19"))
  (check "dates: a time of day beside an end is kept, with its fraction and its offset" (has cues.to "2027-01-14 expires L22 @05:33:25Z" && has cues.to "2027-06-01 expires L25 @05:33:25.250+02:00"))
  (check "dates: a JSON page is read as data, with the label and the priority of its record" (show rec'.to == [
    "2027-01-02 deadline /records/0/a~0b/deadline [tilde]" "2026-11-03 deadline /records/0/deadline_utc @11:00:00Z [X-1 P1]" "2027-01-01 deadline /records/0/tilde~1key/deadline [inner]"
    "2026-11-03 deadline /records/0/verified_deadline [X-1 P1]" "2026-12-31 end /records/0/windowEnd [X-1 P1]" "2027-02-02 deadline /records/1/deadline [second]" ]))
  (check "dates: a JSON start, and the as-of dates of a record" (show rec'.from == [ "2026-10-16 from /records/0/valid_from @12:39:46Z [X-1 P1]" "2026-11-12 effective /records/1/policy_note [second]" ]
    && rec'.asof == { min = "2026-10-18"; max = "2026-10-21"; n = 3; maxLoc = "/records/0/observation_cutoff"; }))
  (check "dates: a JSON page with a number above 2^63-1 is read line by line" (show big.to == [ "2026-11-03 deadline L3" ]))
  (check "dates: a date in a file name is kept, and a page with no date in its text has none" ((fxPage "runs/measure-2026-10-18.md").named == [ "2026-10-18" ] && (fxPage "runs/measure-2026-10-18.md").time == null))

  # The margins.
  (check "margins: ends ahead, by band" (map (i: "${toString i.days}:${i.band}") d0.ends.ahead == [ "0:today" "1:week" "7:week" "8:month" "30:month" "31:later" ]))
  (check "margins: an end that has passed is listed apart, the most recent first" (map (i: "${toString i.days}:${i.band}") d0.ends.past == [ "-1:past" "-2:past" "-14:past" ]))
  (check "margins: a start ahead is listed, a start that began is not" (map (i: "${toString i.days}:${i.band}") d0.starts.ahead == [ "0:today" "2:week" ]))
  (check "margins: a time of day on the day itself is kept, and an unknown one is null" ((builtins.head d0.ends.ahead).at == "11:00:00Z" && (builtins.elemAt d0.ends.ahead 1).at == null))
  (check "margins: an item without a record has no label and no priority, said as null" ((builtins.head d0.ends.ahead).label == null && (builtins.head d0.ends.ahead).priority == null))
  (check "margins: where says the page, the place and the kind" ((builtins.head d0.ends.ahead).where == [ { page = "r:a.md"; loc = "L2"; kind = "doc"; } ]))
  (check "margins: a page no rule classifies has kind null, said as null" ((builtins.head (due "2026-11-03" [ (pg "r" "weird/x.json" [ (it "2026-11-05" "deadline" "L1" { }) ] [ ]) ]).ends.ahead).where == [ { page = "r:weird/x.json"; loc = "L1"; kind = null; } ]))
  (check "margins: one item for a record and a date over several pages, with every cue once and every place" (let k = builtins.head (builtins.filter (i: i.label == "K" && builtins.length i.where == 3) group); in k.priority == "P2" && k.cues == [ "deadline" "due" ] && map (w: w.page) k.where == [ "r:p0.json" "r:p1.json" "r:p2.json" ]))
  (check "margins: of several pages the time of day is the one that has it" ((builtins.head (builtins.filter (i: i.label == "M") group)).at == "09:00:00Z"))
  (check "margins: the same label in another repository is another item" (builtins.length (builtins.filter (i: i.label == "K") group) == 2))
  (check "margins: on one day P1 comes before P2 before no priority" (map (i: i.label) (builtins.filter (i: i.date == "2026-11-09") group) == [ "C" "B" "A" ]))
  (check "margins: sooner comes first" (map (i: i.date) group == [ "2026-11-09" "2026-11-09" "2026-11-09" "2026-11-20" "2026-11-20" "2026-11-25" ]))
  (check "margins: examples, tests and fixtures are left out" (map (i: (builtins.head i.where).page) (ex examplePages false) == [ "r:docs/real.md" ]))
  (check "margins: and come back when asked" (builtins.length (ex examplePages true) == 9))
  (check "margins: a leap day counts" ((builtins.head (days "2028-02-28" "2028-03-01")).days == 2 && (builtins.head (days "2027-02-28" "2027-03-01")).days == 1))
  (check "margins: the new year counts" ((builtins.head (days "2026-12-31" "2027-01-01")).days == 1))
  (check "margins: a day that is not a date is refused" (!(builtins.tryEval (import ../org/due.nix { pages = [ ]; today = "2026-02-30"; }).day).success))
  (check "margins: the same pages and the same day give jq's answer" (realDue == builtins.fromJSON (builtins.readFile ../org/expected-due.json)))
  (check "margins: the two funding deadlines of 2026-11-03 are there, with record, priority and time" (let k = builtins.filter (i: i.date == "2026-11-03" && i.label != null) realDue.ends.ahead; in map (i: "${i.label} ${i.priority} ${i.at}") k == [ "NLNET-CODESUPPLY P2 11:00:00Z" "NLNET-RESTACK P3 11:00:00Z" ]))
]
then "ok" else "failed"
