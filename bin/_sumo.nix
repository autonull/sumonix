# sumo dispatcher — read-only evaluation API for the sumo CLI.
# Returns an attrset with: status, caps, closure, query, whatif, topology.
# Every subcommand evals in ~0.3–1.4 s warm; each has a 15 s guard (no hang).
# Facts: SUMO_FACTS or /run/sumo/facts.kif (or demo/vm/facts.kif in-repo).
# Rules: SUMO_RULES then <worktree>/rules.kif, or the generated demo/vm/rules.kif in the VM.
{ facts, rules, json ? false }:
let
  inherit (builtins)
    all any attrNames attrValues concatMap concatStringsSep elem elemAt filter foldl' genList head isList isString
    length listToAttrs map sort split substring tail toString trace;

  # Shared KIF helpers
  kif = import ../lib/kif.nix { };
  inherit (kif) parse show headOf flatten subforms isVar ground subst varsOf unique isKifOp count;

  # Read facts and rules
  factsText = builtins.readFile facts;
  rulesText = builtins.readFile rules;

  factsForms = parse factsText;
  rulesForms = parse rulesText;

  isRule = f: isList f && f != [ ] && headOf f == "=>";
  ruleForms = filter isRule rulesForms;
  factForms = filter (f: !isRule f) rulesForms ++ factsForms;

  # SUMO ontology + NIX domain
  ontology = import ../sumo.nix {
    forms = parse (builtins.readFile ../sumo.full/Merge.kif) ++ parse (builtins.readFile ../nix-domain.kif);
  };

  # User rules + ingested Merge rules + synthesized rules
  userRules = ruleForms;
  ingested = import ../reasoner/ingest.nix { };
  synthesized = import ../reasoner/synthesize.nix { forms = parse (builtins.readFile ../sumo.full/Merge.kif); };
  allRules = userRules ++ ingested.rules ++ synthesized.rules;

  # Core datalog engine
  datalog = import ../datalog.nix { inherit ontology; facts = factForms; rules = allRules; };

  # Policy build gate
  buildGate = import ../policy/build-gate.nix { };
  policyGoal = [ "policyViolation" "nginx" "NoCriticalRunningCVE" ];

  violation = buildGate.check {
    goal = policyGoal;
    facts = factForms;
    rules = allRules;
    ontology = ontology;
    passWhen = "underivable";
  };

  # Relaxation menu
  relax = import ../policy/relax.nix;
  candidates = [
    { name = "ignore the advisory";          dropFacts = [ [ "vulnerable" "openssl" "CVE-2026-9999" ] ]; }
    { name = "drain nginx";                 dropFacts = [ [ "serviceState" "nginx" "running" ] ]; }
    { name = "reclassify as low";           dropFacts = [ [ "severity" "CVE-2026-9999" "critical" ] ]; }
    { name = "remove the policy rule";      dropRules = [ "policyViolation#4" ]; }
    { name = "drop an unrelated edge";      dropFacts = [ [ "dependsOn" "hello" "glibc" ] ]; }
  ];
  menu = relax {
    goal = policyGoal;
    facts = factForms;
    rules = allRules;
    ontology = ontology;
    passWhen = "underivable";
    inherit candidates;
  };

  # Capability discovery (spike/run-spike.nix pattern)
  capabilityDatalog = import ../datalog.nix {
    inherit ontology;
    facts = parse (builtins.readFile ../demo/facts/nixpkgs.kif) ++ parse (builtins.readFile ../spike/capability-rules.kif) ++ parse (builtins.readFile ../spike/capabilities.kif);
    rules = builtins.filter isRule (parse (builtins.readFile ../spike/capability-rules.kif) ++ parse (builtins.readFile ../spike/capabilities.kif));
  };

  sortBy = field: sort (a: b: a.${field} < b.${field});

  directComps = sortBy "?pkg" (capabilityDatalog.ask [ "canCompose" "?pkg" "?capA" "?capB" ]);
  enabledCaps = sortBy "?pkg" (capabilityDatalog.ask [ "enablesCapability" "?pkg" "?cap" ]);
  synergyRaw = sortBy "?pkg" (capabilityDatalog.ask [ "synergy" "?pkg" "?cap1" "?cap2" "?cap3" ]);

  synergyKey = row:
    row."?pkg" + " " + concatStringsSep "+"
      (sort builtins.lessThan [ row."?cap1" row."?cap2" row."?cap3" ]);
  synergies = attrValues (listToAttrs (map (row: {
    name = synergyKey row;
    value = row // { caps = sort builtins.lessThan [ row."?cap1" row."?cap2" row."?cap3" ]; };
  }) synergyRaw));

  # Counts for status
  serviceCount = length (filter (f: headOf f == "instance" && length f == 3 && elemAt f 2 == "NIXService") factForms);
  packageCount = length (filter (f: headOf f == "instance" && length f == 3 && elemAt f 2 == "NIXPackage") factForms);
  capabilityCount = length (filter (f: headOf f == "providesCapability") factForms);
  roundCount = length (attrNames datalog.trace);

  # Format functions
  formatDirect = row: "  🔗 " + row."?pkg" + " composes " + row."?capA" + " + " + row."?capB";
  formatEnabled = row: "  ✨ " + row."?pkg" + " enables " + row."?cap" + " via dependency closure";
  formatSynergy = row:
    "  🚀 " + row."?pkg" + " synergy: " + concatStringsSep " + " row.caps;

  section = rows: lines:
    if rows == [ ] then "  (none derived)"
    else concatStringsSep "\n" (map lines rows);

  capsOutput = ''
    ╔════════════════════════════════════════════════════════════════╗
    ║           SUMO-NIX CAPABILITY DISCOVERY                         ║
    ║       "What novel capabilities can I compose?"                  ║
    ╚════════════════════════════════════════════════════════════════╝

    📦 DIRECT COMPOSITIONS (${toString (length directComps)}) — package + immediate deps:
    ${section directComps formatDirect}

    🌐 ENABLED CAPABILITIES (${toString (length enabledCaps)}) — via transitive dependency closure:
    ${section enabledCaps formatEnabled}

    💡 SYNERGIES (${toString (length synergies)}) — 3+ capabilities combining:
    ${section synergies formatSynergy}

    ─────────────────────────────────────────────────────────────
    ✨ Your nixpkgs is a capability goldmine.
  '';

  # Closure/tree for a package
  closureTree = pkg:
    let
      depPairs = filter (f:
        headOf f == "dependsOn" && length f == 3 && elemAt f 1 == pkg) factForms;
      deps = unique (map (f: elemAt f 2) depPairs);
      recurse = seen: pkgs:
        if pkgs == [ ] then ""
        else concatStringsSep "\n" (map (dep:
          let children = filter (f:
                headOf f == "dependsOn" && length f == 3 && elemAt f 1 == dep) factForms;
              childDeps = unique (map (f: elemAt f 2) children);
              rest = recurse (seen ++ [ dep ]) (filter (d: !(elem d seen)) childDeps);
          in "  " + dep + (if rest != "" then "\n  │\n  └─ " + rest else "")
        ) pkgs);
    in pkg + "\n" + recurse [ ] deps;

  # JSON helpers
  toJSON = x:
    if isString x then "\"" + escapeJSON x + "\""
    else if isList x then "[" + concatStringsSep "," (map toJSON x) + "]"
    else if builtins.isAttrs x then objToJSON x
    else if x == true || x == false then if x then "true" else "false"
    else toString x;

  # Escape string for JSON
  escapeJSON = s:
    let
      # Recursive character-by-character escaping
      escapeRec = i: acc:
        if i >= length (split "" s) then acc
        else
          let
            c = substring i 1 s;
            escaped =
              if c == "\"" then "\\\""
              else if c == "\\" then "\\\\"
              else if c == "\n" then "\\n"
              else if c == "\r" then "\\r"
              else if c == "\t" then "\\t"
              else c;
          in escapeRec (i + 1) (acc + escaped);
      len = length (split "" s);
    in escapeRec 0 "";

  objToJSON = obj:
    let
      keys = attrNames obj;
      pairs = map (k: "\"" + k + "\":" + toJSON (obj.${k})) keys;
    in "{" + concatStringsSep "," pairs + "}";

  statusJSON = objToJSON {
    services = serviceCount;
    packages = packageCount;
    capabilities = capabilityCount;
    rounds = roundCount;
    verdict = violation.verdict;
    proof = violation.proof;
  };

  capsJSON = objToJSON {
    directCompositions = length directComps;
    enabledCapabilities = length enabledCaps;
    synergies = length synergies;
  };

  whatifJSON = objToJSON {
    basePass = menu.basePass;
    baseDerived = menu.baseDerived;
    flips = length menu.menu;
    candidates = map (c: { name = c.name; flip = c.flip; proof = c.proof; }) menu.menu;
  };

  queryJSON = goal:
    let
      derived = datalog.holds goal;
      proof = if derived then datalog.explain goal else "goal underivable";
    in objToJSON { goal = goal; derived = derived; proof = proof; };

in {
  # Topology/help layout (for dashboard h/?)
  topology = {
    screens = [
      { id = "status"; title = "Machine Status"; desc = "Services, packages, capabilities, rounds, policy verdict"; }
      { id = "caps"; title = "Capability Atlas"; desc = "Direct compositions, enabled capabilities, synergies"; }
      { id = "closure"; title = "Package Closure"; desc = "Dependency tree for a package"; }
      { id = "query"; title = "Query Goal"; desc = "Ground goal → verdict + why subtree"; }
      { id = "whatif"; title = "What-If Analysis"; desc = "One counterfactual from the proof"; }
      { id = "dashboard"; title = "Dashboard"; desc = "TUI: services, capabilities, policy proof, charts"; }
    ];
    keys = [
      { key = "h"; action = "Show this topology (help)"; }
      { key = "?"; action = "Show this topology (help)"; }
      { key = "q"; action = "Quit dashboard"; }
      { key = "Tab"; action = "Navigate panes (dashboard)"; }
      { key = "Arrows"; action = "Scroll proof / resize panes (dashboard)"; }
    ];
  };

  # status — Machine overview
  status = if json then statusJSON else
    ''
    ╔════════════════════════════════════════════════════════════════════╗
    ║                        MACHINE STATUS                             ║
    ╚════════════════════════════════════════════════════════════════════╝

    📦 Services: ${toString serviceCount}
    📦 Packages: ${toString packageCount}
    ⚡ Capabilities: ${toString capabilityCount}
    🔄 Derivation rounds: ${toString roundCount}

    ─────────────────────────────────────────────────────────────
    🚦 POLICY GATE: ${violation.verdict}
    ${violation.proof}
    ─────────────────────────────────────────────────────────────
    Run: sumo caps | sumo closure <pkg> | sumo query <goal> | sumo whatif | sumo dashboard
    '';

  # caps — Capability atlas
  caps = if json then capsJSON else capsOutput;

  # closure — Dependency tree for a package
  closure = pkg: if json then
    objToJSON { package = pkg; tree = closureTree pkg; }
  else closureTree pkg;

  # query — Ground goal → verdict + why subtree
  query = goal: if json then queryJSON goal else
    let
      derived = datalog.holds goal;
      proof = if derived then datalog.explain goal else "goal underivable";
    in "Goal: " + goal + "\nDerived: " + toString derived + "\nProof:\n" + proof;

  # whatif — One counterfactual from the proof
  whatif = if json then whatifJSON else
    let
      flips = menu.menu;
      flipLines = concatStringsSep "\n" (map (m: "  ✓ " + m.name) flips);
      noFlipLines = concatStringsSep "\n" (map (m: "  ✗ " + m.name + " (flips nothing)") (filter (m: !m.flip) menu.results));
      baseVerdict = if menu.basePass then "PASS" else "VIOLATION";
      flipSection = if flips == [ ] then "  (none)" else flipLines;
    in
    "Base verdict: " + baseVerdict + "\n\nSingle flips that change the verdict:\n" + flipSection + "\n\nOther candidates:\n" + noFlipLines;

  # proof — Internal: proof subtree for a goal
  proof = goal: datalog.why goal;
}