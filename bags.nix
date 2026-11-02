# Canned option bags for SUMO, and the help screens to compose them.
#
#   b = import ./bags.nix { }
#   b.help.top                  the front screen
#   b.help.bag "transport"      one bag
#   b.compose [ "military" "tests-spatial" ]     -> a plan, or the reason there is none
#
# Two kinds of bag, both read from the files of ontologyportal/sumo that this repository pins:
#   macro sets  groups of the knowledge-base files of ./sumo.full (a bag is a list of files to load together)
#   test bags   groups of the test files of ./sumo.tests, by the category the file declares
# A bag may need other bags. `compose` adds what is needed, in order, and says what it added.
{ root ? ./. }:
let
  inherit (builtins) attrNames concatLists concatStringsSep elem filter foldl' head length listToAttrs map
    readFile sort lessThan genericClosure substring stringLength;

  pinned = dir:
    map (l: (builtins.filter builtins.isString (builtins.split " +" l)))
      (filter (l: l != "" && substring 0 1 l != "#") (filter builtins.isString (builtins.split "\n" (readFile (root + "/${dir}/PINS")))));
  kbFiles = map (x: builtins.elemAt x 1) (pinned "sumo.full");
  tqFiles = map (x: builtins.elemAt x 1) (filter (x: builtins.match ".*\\.kif\\.tq" (builtins.elemAt x 1) != null) (pinned "sumo.tests"));

  # Macro sets. `other` is every pinned file no other set names, so the sets partition the corpus.
  named = {
    core = {
      doc = "The upper ontology and the mid-level ontology. Everything else builds on these.";
      files = [ "Merge.kif" "Mid-level-ontology.kif" ];
      needs = [ ];
    };
    life = {
      doc = "Bodies, animals, plants, medicine, viruses, arteries.";
      files = [ "Anatomy.kif" "Animals.kif" "Medicine.kif" "Trees.kif" "VirusProteinAndCellPart.kif" "arteries.kif" ];
      needs = [ "core" ];
    };
    things = {
      doc = "Made objects: cars, appliances, computers, engineering, catalogue goods.";
      files = [ "Objects.kif" "Cars.kif" "HouseholdAppliances.kif" "ComputerInput.kif" "ComputingBrands.kif" "SimpleFacts/CarBrands.kif" "engineering.kif" "Catalog.kif" ];
      needs = [ "core" ];
    };
    transport = {
      doc = "Transport, its detail, and the airports of the world.";
      files = [ "Transportation.kif" "TransportDetail.kif" "WorldAirports.kif" ];
      needs = [ "core" ];
    };
    hospitality = {
      doc = "Food, dining and hotels.";
      files = [ "Food.kif" "Dining.kif" "Hotel.kif" "mappings/HotelDetail.kif" ];
      needs = [ "core" ];
    };
    military = {
      doc = "Military devices, persons and processes, naval modelling, weapons of mass destruction, simulation.";
      files = [ "Military.kif" "MilitaryDevices.kif" "MilitaryPersons.kif" "MilitaryProcesses.kif" "NavalModeling.kif" "WMD.kif" "ModSim.kif" ];
      needs = [ "core" ];
    };
    society = {
      doc = "Government, law, justice, economy, finance, people, media, sport, music, communication, language, emotion.";
      files = [ "Government.kif" "Law.kif" "Justice.kif" "Economy.kif" "FinancialOntology.kif" "People.kif" "TransnationalIssues.kif"
        "ClimateStatecraft.kif" "WeatherStatecraft.kif" "Sports.kif" "Music.kif" "Media.kif" "Communications.kif" "Biography.kif"
        "Facebook.kif" "Languages.kif" "emotion.kif" "mappings/FOAFmap.kif" "mappings/ISCOgroups.kif" "mappings/DHS_Taxonomy.kif" ];
      needs = [ "core" ];
    };
    geography = {
      doc = "Places, countries, regions, weather and geologic time.";
      files = [ "Geography.kif" "CountriesAndRegions.kif" "mondial.kif" "Weather.kif" "GeochronologicTimes.kif" ];
      needs = [ "core" ];
    };
    english = {
      doc = "How terms read in English and in other languages (format files). Needs no logic; it is for output.";
      files = [ "english_format.kif" "domainEnglishFormat.kif" "NameTermFormat.kif" "Translations/arabic_format.kif"
        "Translations/chinese_format.kif" "Translations/french_format.kif" "Translations/japanese_format.kif"
        "Translations/portuguese_format.kif" "Translations/spanish_format.kif" "Translations/relations-ro-sgml.kif" "Translations/relations-ro.kif" ];
      needs = [ "core" ];
    };
  };
  taken = concatLists (map (n: named.${n}.files) (attrNames named));
  macro = named // {
    other = {
      doc = "The remaining pinned files: networking, industry codes, quality of service, capabilities, experimental terms.";
      files = filter (f: !(elem f taken)) kbFiles;
      needs = [ "core" ];
    };
  };

  # Test bags: the files of ./sumo.tests that declare a category, grouped by it. The rest go in `tests-all`.
  categoryOf = f:
    let m = builtins.match ".*\\(category +([a-z]+)\\).*" (builtins.replaceStrings [ "\n" ] [ " " ] (readFile (root + "/sumo.tests/${f}")));
    in if m == null then null else head m;
  cats = listToAttrs (map (f: { name = f; value = categoryOf f; }) tqFiles);
  catNames = sort lessThan (builtins.attrNames (listToAttrs (map (c: { name = c; value = 1; }) (filter (c: c != null) (builtins.attrValues cats)))));
  tests =
    listToAttrs (map
      (c: {
        name = "tests-${c}";
        value = {
          doc = "The SUMO test files of category ${c}: facts, rules, a query and its expected answer. Run by tq.nix on the Horn solver.";
          files = [ ];
          tests = filter (f: cats.${f} == c) tqFiles;
          needs = [ "core" ];
        };
      })
      catNames)
    // {
      tests-all = {
        doc = "Every test file of ./sumo.tests, including those that declare no category.";
        files = [ ];
        tests = tqFiles;
        needs = [ "core" ];
      };
    };

  bags = listToAttrs (map (n: { name = n; value = { name = n; tests = [ ]; } // macro.${n}; }) (attrNames macro))
    // listToAttrs (map (n: { name = n; value = { name = n; } // tests.${n}; }) (attrNames tests));

  # The bags a plan needs, each after what it needs. A bag asked for twice or needed twice appears once.
  order = names:
    let
      visit = seen: n:
        if elem n seen then seen
        else if !(bags ? ${n}) then throw "no bag called ${n}; run help.top for the list"
        else (foldl' visit seen bags.${n}.needs) ++ [ n ];
    in foldl' visit [ ] names;

  nonEmpty = xs: if xs == [ ] then "(none)" else concatStringsSep ", " xs;
  count = n: word: "${toString n} ${word}${if n == 1 then "" else "s"}";
  pad = w: s: s + concatStringsSep "" (builtins.genList (_: " ") (if stringLength s >= w then 1 else w - stringLength s));
in
rec {
  inherit bags;
  names = sort lessThan (attrNames bags);

  # compose [ names ] -> { bags, added, files, tests, load }
  #   bags   all bags of the plan, needs first
  #   added  the bags that were not asked for but are needed
  #   files  the knowledge-base files to load, in order (the paths under ./sumo.full)
  #   tests  the test files to run
  compose = asked:
    let
      all = order asked;
      files = concatLists (map (n: bags.${n}.files) all);
      tests' = concatLists (map (n: bags.${n}.tests) all);
    in {
      bags = all;
      added = filter (n: !(elem n asked)) all;
      inherit files;
      tests = tests';
      load = map (f: root + "/sumo.full/${f}") files;
    };

  # Which bags can join the plan without bringing anything new: those whose needs the plan already has.
  matches = asked:
    let have = order asked; in
    filter (n: !(elem n have) && builtins.all (d: elem d have) bags.${n}.needs) names;

  help = rec {
    top = ''
      sumo-nix: canned bags of SUMO knowledge and tests, and a way to put them together.

      A bag is a named list of files from ontologyportal/sumo, pinned by SHA-256 in sumo.full/PINS and sumo.tests/PINS.
        macro sets   ${nonEmpty (filter (n: bags.${n}.tests == [ ] && bags.${n}.files != [ ]) names)}
        test bags    ${nonEmpty (filter (n: bags.${n}.tests != [ ]) names)}

      Commands (bin/sumo-nix):
        help                 this screen
        help bag NAME        the files of one bag, and what it needs
        help compose         how bags combine
        help tq              how the SUMO test files are run, and what the verdicts mean
        bags                 one line per bag
        compose NAME...      the plan for these bags: what is added, what is loaded
        match NAME...        the bags that fit onto this plan with nothing new needed
        tq [NAME...]         run the test files of these test bags (default: tests-all)
    '';

    compose = ''
      Composing bags.

        compose core transport tests-general

      A bag lists the bags it needs. Every macro set needs core. The plan is the asked bags, each after what it needs, once.
      Bags that you did not ask for and the plan added are reported as "added", so nothing is loaded without you seeing it.
      A name that is not a bag is an error, not a skip.

      A macro set adds knowledge-base files. A test bag adds test files. A plan can hold both: load the macro sets, run the tests.
      "match" lists the bags that join a plan for free, because the plan already holds what they need. Start from core and
      grow the plan one match at a time.
    '';

    tq = ''
      Running the SUMO test files.

      Each file of sumo.tests ends in .kif.tq: facts, rules, a (query F), and an (answer yes|no). tq.nix reads the file and
      runs it on the Horn solver, with the class, relation and domain axioms of Merge.kif loaded.

        pass         the solver and the answer agree
        open         the answer is yes and the solver does not derive it. The file needs an axiom of Merge.kif that
                     is not a Horn rule. A gap in this solver, not a fault in SUMO.
        fail         the answer is no and the solver derives the query
        unsupported  the file needs more than Horn logic: <=>, forall, or, a row variable (@), an existential or compound
                     consequent, or a typed language (minLang tff or thf). It is not run, so there is no verdict.
    '';

    bag = name:
      let b = bags.${name} or (throw "no bag called ${name}; run help.top for the list"); in ''
        ${name}: ${b.doc}
          needs   ${nonEmpty b.needs}
          files   ${count (length b.files) "file"}${if b.files == [ ] then "" else "\n" + concatStringsSep "\n" (map (f: "            " + f) b.files)}
          tests   ${count (length b.tests) "test file"}${if b.tests == [ ] then "" else "\n" + concatStringsSep "\n" (map (f: "            " + f) b.tests)}
      '';
  };

  list = concatStringsSep "\n" (map (n: "${pad 16 n}${pad 14 (count (length bags.${n}.files) "file")}${pad 14 (count (length bags.${n}.tests) "test")}${nonEmpty bags.${n}.needs}") names) + "\n";

  plan = asked:
    let p = compose asked; in ''
      plan     ${concatStringsSep " " p.bags}
      added    ${nonEmpty p.added}
      load     ${count (length p.files) "file"}
      tests    ${count (length p.tests) "test file"}
    '';

  matchLine = asked: nonEmpty (matches asked) + "\n";
}
