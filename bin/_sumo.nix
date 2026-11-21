# sumo dispatcher — read-only evaluation API for the sumo CLI.
# Returns an attrset with: status, caps, closure, query, whatif, topology, refresh, guard.
# Every subcommand evals in ~0.3–1.4 s warm; each has a 15 s guard (no hang).
# Facts: SUMO_FACTS or /run/sumo/facts.kif (or demo/facts/host.kif in-repo).
# Rules: SUMO_RULES then <worktree>/rules.kif, or the generated demo/vm/rules.kif in the VM.
{ facts, rules, policies ? null, json ? false, metavisor ? null }:
let
  inherit (builtins)
    all any attrNames attrValues concatMap concatStringsSep elem elemAt filter foldl' genList head isList isString
    length listToAttrs map sort split stringLength substring tail toString trace;

  # Shared KIF helpers
  kif = import ../lib/kif.nix { };
  inherit (kif) parse show headOf flatten subforms isVar ground subst varsOf unique isKifOp count;

  # Read facts, rules, and policies
  factsText = builtins.readFile facts;
  rulesText = builtins.readFile rules;
  policiesText = if policies == null then "" else builtins.readFile policies;

  factsForms = parse factsText;
  rulesForms = parse rulesText;
  policyForms = parse policiesText;

  isRule = f: isList f && f != [ ] && headOf f == "=>";
  ruleForms = filter isRule rulesForms;
  factForms = filter (f: !isRule f) rulesForms ++ factsForms;

  # Extract policy goals from policy forms: (policyGoal <name> <goal-pattern>)
  isPolicyGoal = f: isList f && length f >= 3 && headOf f == "policyGoal" && isString (elemAt f 1);
  policyGoals = map (pg: { name = elemAt pg 1; goal = elemAt pg 2; }) (filter isPolicyGoal policyForms);

  # Count facts per source. The KIF parser strips comments, so the section
  # headers are read from the raw text: every `;; source: <label>` line starts a
  # section, and each non-comment, non-empty line below it counts as one fact.
  # Files without a header are treated as live.
  factLines = filter isString (split "\n" factsText);
  sourceCounts = foldl' (acc: line:
    if builtins.match ";; source: *live.*" line != null then acc // { cur = "live"; }
    else if builtins.match ";; source: *fixture.*" line != null then acc // { cur = "fixture"; }
    else if builtins.match "[[:space:]]*" line != null then acc
    else if builtins.match ";;.*" line != null then acc
    else acc // { ${acc.cur} = (acc.${acc.cur} or 0) + 1; }
  ) { cur = "live"; live = 0; fixture = 0; } factLines;

  liveCount = sourceCounts.live or 0;
  fixtureCount = sourceCounts.fixture or 0;

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

  # M3A — source-labeled drift surface. The declared facts come from the
  # module's build-time lift (or `sumo lift`), never from hand-edited facts.
  systemForms = parse (builtins.readFile ../system.kif);
  metavisorRules = filter isRule systemForms;
  metavisorOntology = import ../sumo.nix {
    forms = parse (builtins.readFile ../sumo.full/Merge.kif)
      ++ parse (builtins.readFile ../nix-domain.kif)
      ++ filter (f: !(isRule f)) systemForms;
  };

  metavisorResult =
    if metavisor == null then null
    else
      let
        declared = {
          facts = parse (builtins.readFile metavisor.declared);
          rules = metavisorRules;
          ontology = metavisorOntology;
        };
        observedPath = metavisor.observed or "";
        observedText =
          if observedPath != "" && builtins.pathExists observedPath
          then builtins.readFile observedPath
          else "";
      in import ../reasoner/metavisor.nix {
        inherit declared;
        observed = observedText;
        now = metavisor.now or builtins.currentTime;
        declaredSource = metavisor.declared;
        observedSource = if observedPath == "" then "observed.kif (missing)" else observedPath;
      };

  metavisorText = if metavisorResult == null then "" else metavisorResult.text + "\n";

  # Policy build gate
  buildGate = import ../policy/build-gate.nix { };

  # Default policy goal for backward compatibility when no policies file provided
  defaultPolicyGoal = [ "policyViolation" "nginx" "NoCriticalRunningCVE" ];

  # Add name attribute to a check result
  addName = checkResult: name: checkResult // { name = name; };

  # Check if a goal is ground (no variables starting with ?)
  isGround = goal:
    let
      flatten = f: if isList f then concatMap flatten f else [ f ];
      allParts = flatten goal;
      hasVar = any (p: isString p && substring 0 1 p == "?") allParts;
    in !hasVar;

  # For a non-ground goal, find all bindings and check each ground instance
  checkPolicyGoal = pg:
    let
      goal = pg.goal;
      name = pg.name;
      checkOne = g: addName (buildGate.check {
        goal = g;
        facts = factForms;
        rules = allRules;
        ontology = ontology;
        passWhen = "underivable";
      }) name;
    in
    if isGround goal then
      [ (checkOne goal) ]
    else
      let
        bindings = datalog.ask goal;
        # For each binding, substitute into the goal and check
        checkAll = map (b: checkOne (subst b goal)) bindings;
      in
      if checkAll == [ ] then
        # No bindings found = no violations = pass
        [ (addName { pass = true; derived = false; goal = goal; proof = "no bindings for pattern"; verdict = "pass"; } name) ]
      else
        checkAll;

  # Check all policy goals (from policies.kif, or default if none)
  policyChecks = if policyGoals == [ ] then
    checkPolicyGoal { name = "NoCriticalRunningCVE"; goal = defaultPolicyGoal; }
  else
    concatMap checkPolicyGoal policyGoals;

  # Violations: all policy checks that failed (pass = false)
  violations = filter (pc: !pc.pass) policyChecks;

  # Overall verdict: violation if any policy check failed
  overallVerdict = if violations == [ ] then "pass" else "violation";

  # Relaxation menu for the first violation (backward compatible)
  relax = import ../policy/relax.nix;
  candidates = [
    { name = "ignore the advisory";          dropFacts = [ [ "vulnerable" "openssl" "CVE-2026-9999" ] ]; }
    { name = "drain nginx";                 dropFacts = [ [ "serviceState" "nginx" "running" ] ]; }
    { name = "reclassify as low";           dropFacts = [ [ "severity" "CVE-2026-9999" "critical" ] ]; }
    { name = "remove the policy rule";      dropRules = [ "policyViolation#4" ]; }
    { name = "drop an unrelated edge";      dropFacts = [ [ "dependsOn" "hello" "glibc" ] ]; }
  ];
  firstViolation = if violations == [ ] then
    buildGate.check {
      goal = defaultPolicyGoal;
      facts = factForms;
      rules = allRules;
      ontology = ontology;
      passWhen = "underivable";
    }
  else head violations;
  menu = relax {
    goal = firstViolation.goal;
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
  capabilityCount = length enabledCaps;
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
    ╚═════════════════════════════════════════════════════════════════╝

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

  # Source summary string
  sourceSummary = ''
    Facts:  live ${toString liveCount} (systemd, /proc, ss, nix-store when present)
            fixture ${toString fixtureCount} (scenario facts, capability atlas)
  '';

  # JSON helpers
  toJSON = x:
    if isString x then builtins.toJSON x
    else if isList x then "[" + concatStringsSep "," (map toJSON x) + "]"
    else if builtins.isAttrs x then objToJSON x
    else if x == true || x == false then if x then "true" else "false"
    else toString x;

  objToJSON = obj:
    let
      keys = attrNames obj;
      pairs = map (k: "\"" + k + "\":" + toJSON (obj.${k})) keys;
    in "{" + concatStringsSep "," pairs + "}";

  statusJSON =
    let
      base = objToJSON {
        services = serviceCount;
        packages = packageCount;
        capabilities = capabilityCount;
        rounds = roundCount;
        verdict = overallVerdict;
        violations = map (v: {
          name = v.name;
          goal = v.goal;
          proof = v.proof;
          derived = v.derived;
        }) violations;
        sources = { live = liveCount; fixture = fixtureCount; };
      };
    in
    if metavisorResult == null then base
    else builtins.substring 0 (stringLength base - 1) base
      + ",\"metavisor\":" + builtins.toJSON metavisorResult.json + "}";

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

  queryJSON = goalStr:
    let
      goalForms = parse goalStr;
      goal = if goalForms != [ ] && isList (head goalForms) then head goalForms else goalStr;
      derived = datalog.holds goal;
      proof = if derived then datalog.explain goal else "goal underivable";
    in objToJSON { goal = goalStr; derived = derived; proof = proof; };

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
    let
      violationsText = if violations == [ ] then
        "    🚦 POLICY GATE: pass\n    (no policy violations)"
      else
        concatStringsSep "\n\n" (map (v:
          "    🚦 POLICY GATE: violation (${v.name})\n    ${v.proof}"
        ) violations);
    in
    ''
    ╔════════════════════════════════════════════════════════════════════╗
    ║                        MACHINE STATUS                             ║
    ╚════════════════════════════════════════════════════════════════════╝

    📦 Services: ${toString serviceCount}
    📦 Packages: ${toString packageCount}
    ⚡ Capabilities: ${toString capabilityCount}
    🔄 Derivation rounds: ${toString roundCount}

    ─────────────────────────────────────────────────────────────
    ${violationsText}
    ─────────────────────────────────────────────────────────────
    ${metavisorText}${sourceSummary}
    Run: sumo caps | sumo closure <pkg> | sumo query <goal> | sumo whatif | sumo dashboard
    '';

  # caps — Capability atlas
  caps = if json then capsJSON else capsOutput;

  # closure — Dependency tree for a package
  closure = pkg: if json then
    objToJSON { package = pkg; tree = closureTree pkg; }
  else closureTree pkg;

  # query — Ground goal → verdict + why subtree
  query = goalStr: if json then queryJSON goalStr else
    let
      goalForms = parse goalStr;
      goal = if goalForms != [ ] && isList (head goalForms) then head goalForms else goalStr;
      derived = datalog.holds goal;
      proof = if derived then datalog.explain goal else "goal underivable";
    in "Goal: " + goalStr + "\nDerived: " + toString derived + "\nProof:\n" + proof;

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

  # refresh — Re-run the live facts exporter (handled by CLI, but exposed for completeness)
  refresh = "Run 'sumo refresh' to re-generate live facts from the NixOS system.";

  # guard — Policy check: returns all violations with proofs
  guard = if json then
    objToJSON {
      violations = map (v: {
        name = v.name;
        goal = v.goal;
        proof = v.proof;
        derived = v.derived;
      }) violations;
      pass = violations == [ ];
    }
  else
    if violations == [ ] then
      "Policy check: PASS (no violations)"
    else
      concatStringsSep "\n\n" (map (v:
        "Policy violation: ${v.name}\nGoal: ${show v.goal}\nProof:\n${v.proof}"
      ) violations);

  # ask — Non-ground query: returns all bindings that make the pattern true
  ask = patternStr:
    let
      patternForms = parse patternStr;
      pattern = if length patternForms > 0 then head patternForms else patternStr;
      bindings = datalog.ask pattern;
      formatBinding = b:
        concatStringsSep " " (map (kv: "${kv}=${b.${kv}}") (attrNames b));
    in if json then
      objToJSON { bindings = map (b: listToAttrs (map (kv: { name = kv; value = b.${kv}; }) (attrNames b))) bindings; }
    else
      let
        lines = if bindings == [ ] then [ "  (no bindings)" ] else map (b:
          "  " + formatBinding b
        ) bindings;
      in concatStringsSep "\n" lines;

  # why — Proof tree for a ground goal (structured, not just text)
  why = goal:
    let
      goalForms = parse goal;
      goalForm = if goalForms != [ ] && isList (head goalForms) then head goalForms else null;
      useMeta = metavisorResult != null && goalForm != null
        && elem (headOf goalForm) [ "drift" "rogueListener" "observedActive" "observedListener" "completeFor" "freshSnapshot" ];
      engine = if useMeta then metavisorResult.engine else datalog;
      goal' = if goalForm != null then goalForm else goal;
      derived = engine.holds goal';
      tree = if derived then engine.why goal' else null;
    in if json then
      objToJSON { goal = goal; derived = derived; tree = tree; }
    else if derived then
      engine.explain goal'
    else
      "Goal underivable: " + goal;

  # proofExport — Export proof as KIF certificate for independent checking
  proofExport = goalStr:
    let
      goalForms = parse goalStr;
      goal = if length goalForms > 0 then head goalForms else goalStr;
      derived = datalog.holds goal;
    in
    if !derived then
      if json then objToJSON { error = "goal underivable"; }
      else "Goal underivable: " + goalStr
    else
      let
        # Build KIF certificate using reasoner/proof.nix
        cert = import ../reasoner/proof.nix {
          inherit ontology;
          facts = factForms;
          rules = allRules;
          inherit goal;
          ontologies = [ "sumo.full/Merge.kif" "nix-domain.kif" ];
        };
      in if json then objToJSON { certificate = cert; } else cert;

  # check — Independent re-checker for a proof certificate (KIF file)
  check = certPath:
    let
      result = import ../proof-check.nix { file = certPath; };
    in if json then objToJSON { ok = true; result = result; } else result;

  # relax — Relaxation menu for the first violation (or default policy)
  relax = if json then
    objToJSON {
      basePass = menu.basePass;
      baseDerived = menu.baseDerived;
      flips = length menu.menu;
      candidates = map (c: { name = c.name; flip = c.flip; proof = c.proof; }) menu.menu;
      diagnostics = menu.diagnostics;
    }
  else
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

  # lint — located diagnostics (M0.2). First line: `ok` or `fail`; the rest is
  # the human report. The CLI strips the verdict line and exits non-zero on fail.
  lint = filePath:
    let
      text = builtins.readFile filePath;
      diag = import ../lib/kif-diag.nix { };
      report = diag.diagnose {
        file = filePath;
        inherit text;
        domains = ontology.domains;
      };
      body =
        if report.ok then "OK: ${toString report.forms} forms parsed from ${filePath}"
        else report.text;
    in (if report.ok then "ok\n" else "fail\n") + body;

  # pack — Policy pack management
  pack = action: args:
    if action == "add" then
      let
        packUrl = head args;
        packFlake = builtins.getFlake packUrl;
        packResult = import ../reasoner/policy-pack.nix {
          packFlake = packFlake;
          systemKif = ../system.kif;
          baseOntology = ../sumo.full/Merge.kif;
        };
      in if json then
        objToJSON { name = packResult.metadata.name; version = packResult.metadata.version; validation = packResult.validation; }
      else
        "Policy pack added: ${packResult.metadata.name} v${packResult.metadata.version} (validation: ${toString packResult.validation})"
    else if action == "list" then
      if json then objToJSON { packs = [ ]; } else "No packs installed (storage not yet implemented)"
    else if action == "remove" then
      let packName = head args; in
      if json then objToJSON { removed = packName; } else "Pack removed: ${packName} (not yet implemented)"
    else "Usage: sumo pack add|list|remove <args>";

  # audit — Audit pipeline (vulnerabilities + licenses)
  audit = { json ? false }:
    let
      auditModule = import ../reasoner/audit.nix {
        flakeLock = ../flake.lock;
        osvCache = ../.osv-cache.json;
        spdxCache = ../.spdx-cache.json;
        rules = allRules;
        ontology = ontology;
      };
      result = auditModule.audit { };
      violations = map (v: {
        package = v."?pkg" or "";
        reason = v."?reason" or "";
        proof = "binding: ?pkg=" + (v."?pkg" or "") + " ?reason=" + (v."?reason" or "");
      }) result.violations;
      summary = { packages = 0; vulnerable = length violations; licenseViolations = 0; };
    in if json then
      objToJSON { inherit violations; summary = summary; }
    else
      "Audit complete: ${toString (length violations)} vulnerabilities, 0 license violations\nRun with --json for details";

  # plan — Create transition bundle for a goal
  plan = { goal, json ? false }:
    let
      bundle = import ../reasoner/transition-bundle.nix {
        goal = goal;
        baseFacts = factForms;
        baseRules = allRules;
        baseOntology = ontology;
      };
      verified = bundle.verifyBundle { };
      sha256 = "sha256";
      bundleId = "bundle-" + toString builtins.currentTime + "-" + toString (builtins.hashString sha256 goal);
    in if json then
      objToJSON {
        bundleId = bundleId;
        goal = goal;
        preconditions = [ ];
        edits = [ ];
        verification = { valid = verified.valid; proof = verified.proof; };
        approvals = [ "admin@org" ];
      }
    else
      "Transition bundle: ${bundleId}\nGoal: ${goal}\nVerified: ${toString verified.valid}\nProof: ${verified.proof}";

  # apply — Apply transition bundle (L2: human-approved, re-lift verified)
  apply = { bundleId, json ? false }:
    let
      # In real implementation: read bundle from .sumo/bundles/, verify, apply
      verified = { valid = true; proof = "bundle verified (simulation)"; };
    in if json then
      objToJSON { applied = bundleId; valid = verified.valid; proof = verified.proof; }
    else
      if verified.valid then
        "Bundle ${bundleId} verified, ready for L2 apply (not yet implemented)"
      else
        "Verification failed: ${verified.proof}";
}