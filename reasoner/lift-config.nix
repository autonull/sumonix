# M1 — Config lifter: a pure `nixosConfigurations.host.config` -> KIF facts.
#
#   lift = import ./reasoner/lift-config.nix { config = nixosConfigurations.host.config; }
#   lift.facts      # ground KIF forms; every declared fact carries its option path
#   lift.rules      # system.kif rules (1-2 of v0)
#   lift.ontology   # SUMO + NIX domain + system.kif signatures
#   lift.illTyped   # facts that fail the well-typedness gate (must be empty)
#
# The lifter reads a slice only: services (known table), the firewall,
# users.users and environment.systemPackages. It never reads the whole option
# tree, never guesses a port, and marks every port/listener default `inferred`
# with the option path it comes from. An enabled service without an unambiguous
# systemd unit emits `(ambiguousJoin <service> <reason>)` instead of a guess.
#
# Pass `ontology` (built once from Merge.kif + nix-domain.kif + system.kif) to
# reuse the parse across lifts; otherwise the lifter builds it itself.
{ config
, ontology ? null
, systemKif ? ../system.kif
, serviceTable ? null
}:
let
  kif = import ../lib/kif.nix { };
  inherit (kif) parse show showFact headOf makeEnvelope defaultMeta getFact;

  inherit (builtins)
    attrNames attrValues concatMap concatStringsSep elem elemAt filter
    isAttrs isList isString length listToAttrs map tail toString currentTime hashString;

  # Quote a value as a KIF string atom (the parser keeps the quotes in the atom).
  q = s:
    let esc = builtins.replaceStrings [ "\\" "\"" "\n" ] [ "\\\\" "\\\"" " " ] (toString s);
    in "\"" + esc + "\"";

  # Create FactMeta for a fact
  # sourceClass: "declared" | "inferred" | "observed" | "fixture" | "derived"
  makeMeta = sourceClass: sourceId: fact:
    let
      now = currentTime;
      factStr = show fact;
      contentHash = "sha256:" + hashString "sha256" factStr;
    in {
      sourceClass = sourceClass;
      sourceId = sourceId;
      observedAt = now;
      expiresAt = 0;  # config facts don't expire
      snapshotId = "";
      contentHash = contentHash;
      confidence = if sourceClass == "declared" then 1.0 else 0.8;
      provenance = [ ];
    };

  # Wrap a fact with appropriate meta based on its predicate
  wrapFact = fact:
    let
      h = headOf fact;
      meta =
        if elem h [ "declaredService" "declaredRunning" "portDeclared" "listenerDeclared"
                     "firewallEnabled" "firewallTcpAllowed" "firewallUdpAllowed"
                     "packageVersion" "storePath" "userAccount" "memberOf" "aliasOf" "instance" ]
        then makeMeta "declared" "reasoner/lift-config.nix" fact
        else if elem h [ "portInferred" "listenerInferred" ]
        then makeMeta "inferred" "reasoner/lift-config.nix" fact
        else makeMeta "derived" "reasoner/lift-config.nix" fact;
    in makeEnvelope fact meta;

  # Read a nested attribute, or return the default.
  get = default: path:
    let
      go = v: i:
        if i >= length path then v
        else if isAttrs v && v ? ${elemAt path i} then go v.${elemAt path i} (i + 1)
        else default;
    in go config 0;

  inst = e: c: [ "instance" e c ];
  qInst = s: c: inst (q s) c;

  dedupe = fs:
    attrValues (listToAttrs (map (f: { name = show f; value = f; }) fs));

  trim = s: builtins.replaceStrings [ " " "\t" "\r" ] [ "" "" "" ] s;

  dot = ps: concatStringsSep "." ps;

  # "addr:port" / "[::]:port" -> "addr"; a bare address is itself.
  addressOf = s:
    let v4 = builtins.match "([^:]+):[0-9]+" s;
    in
    if builtins.substring 0 4 s == "[::]" then "::"
    else if v4 != null then elemAt v4 0
    else s;

  normalizeAddress = a:
    if a == "*" || a == "::" || a == "[::]" then "0.0.0.0" else a;

  # A string or a list -> a list of trimmed addresses.
  addressesOf = raw:
    let
      pieces =
        if isList raw then map toString raw
        else filter isString (builtins.split "," (toString raw));
    in map (p: normalizeAddress (addressOf (trim p))) pieces;

  defaultTable = {
    postgresql = {
      unitKey = "postgresql";
      unit = "postgresql.service";
      port = { path = [ "services" "postgresql" "settings" "port" ]; default = 5432; };
      listen = {
        path = [ "services" "postgresql" "settings" "listen_addresses" ];
        default = "localhost";
      };
    };
    openssh = {
      unitKey = "sshd";
      unit = "sshd.service";
      ports = { path = [ "services" "openssh" "ports" ]; default = [ 22 ]; list = true; };
      listen = {
        path = [ "services" "openssh" "listenAddresses" ];
        default = [ ];
        allWhenEmpty = true;
      };
    };
    nginx = {
      unitKey = "nginx";
      unit = "nginx.service";
    };
  };

  table = if serviceTable != null then serviceTable else defaultTable;

  # --- static ontology --------------------------------------------------------
  systemForms = parse (builtins.readFile systemKif);
  isRule = f: isList f && f != [ ] && headOf f == "=>";
  systemRules = filter isRule systemForms;
  systemOntology = filter (f: !(isRule f)) systemForms;
  ontology' =
    if ontology != null then ontology
    else import ../sumo.nix {
      forms = parse (builtins.readFile ../sumo.full/Merge.kif)
        ++ parse (builtins.readFile ../nix-domain.kif)
        ++ systemOntology;
    };

  # --- services ---------------------------------------------------------------
  serviceBlock = name:
    let
      entry = table.${name};
      enabled = (get { } [ "services" name ]).enable or false;
      svc = "services." + name;
      enablePath = svc + ".enable";
      unitAttrs = get null [ "systemd" "services" entry.unitKey ];
      unitNameRaw = get entry.unit [ "systemd" "services" entry.unitKey "name" ];
      templated = isString unitNameRaw && builtins.match ".*@.*" unitNameRaw != null;
      unitName = if isAttrs unitAttrs && isString unitNameRaw && !templated then unitNameRaw else null;
      ambiguity =
        if !enabled then [ ]
        else if unitName == null then
          [ [ "ambiguousJoin" (q svc) (q ("no unambiguous systemd.services." + entry.unitKey)) ] ]
        else [ ];

      common = [
        (qInst svc "NIXService")
        (qInst enablePath "NIXOptionPath")
        [ "declaredService" (q svc) (q enablePath) ]
        [ "declaredRunning" (q svc) (q enablePath) ]
      ];
      join = if unitName == null then [ ] else [
        (qInst unitName "NIXUnit")
        [ "aliasOf" (q svc) (q unitName) ]
      ];

      portSpecs =
        if entry ? ports then
          let v = get entry.ports.default entry.ports.path; in
          (if entry.ports.list or false then v else [ v ])
        else if entry ? port then
          [ (get entry.port.default entry.port.path) ]
        else [ ];
      portPath = if entry ? ports then entry.ports.path else entry.port.path;
      portPathText = dot portPath;
      portDefaults = if entry ? ports then entry.ports.default else [ entry.port.default ];
      portFacts = concatMap (port:
        let
          kind = if elem port portDefaults then "portInferred" else "portDeclared";
        in [
          (qInst (toString port) "NIXPort")
          (qInst portPathText "NIXOptionPath")
          [ kind (q svc) (q (toString port)) (q portPathText) ]
        ]) portSpecs;

      listenRaw = if entry ? listen then get entry.listen.default entry.listen.path else [ ];
      listenFacts =
        if !(entry ? listen) then [ ]
        else
          let
            listenPath = dot entry.listen.path;
            addresses =
              let a = addressesOf listenRaw; in
              if a == [ ] && (entry.listen.allWhenEmpty or false) then [ "0.0.0.0" ]
              else a;
            kind = if listenRaw == entry.listen.default then "listenerInferred" else "listenerDeclared";
          in concatMap (addr: [
            (qInst addr "NIXAddress")
            (qInst listenPath "NIXOptionPath")
            [ kind (q svc) (q addr) (q listenPath) ]
          ]) addresses;
    in
    if !enabled then { facts = [ ]; ambiguous = [ ]; }
    else {
      facts = common ++ join ++ portFacts ++ listenFacts;
      ambiguous = ambiguity;
    };

  serviceBlocks = map serviceBlock (attrNames table);
  serviceFacts = concatMap (b: b.facts) serviceBlocks;
  ambiguous = concatMap (b: b.ambiguous) serviceBlocks;

  # --- firewall ---------------------------------------------------------------
  fwEnabled = get false [ "networking" "firewall" "enable" ];
  fwOptions = [
    (qInst "networking.firewall.enable" "NIXOptionPath")
    (qInst "networking.firewall.allowedTCPPorts" "NIXOptionPath")
    (qInst "networking.firewall.allowedUDPPorts" "NIXOptionPath")
    [ "firewallTcpOption" (q "networking.firewall.allowedTCPPorts") ]
    [ "firewallUdpOption" (q "networking.firewall.allowedUDPPorts") ]
  ] ++ (if fwEnabled then [ [ "firewallEnabled" (q "networking.firewall.enable") ] ] else [ ]);
  portFact = relation: optionPath: port:
    [
      (qInst (toString port) "NIXPort")
      (qInst optionPath "NIXOptionPath")
      [ relation (q (toString port)) (q optionPath) ]
    ];
  firewallFacts = fwOptions
    ++ concatMap (portFact "firewallTcpAllowed" "networking.firewall.allowedTCPPorts")
      (get [ ] [ "networking" "firewall" "allowedTCPPorts" ])
    ++ concatMap (portFact "firewallUdpAllowed" "networking.firewall.allowedUDPPorts")
      (get [ ] [ "networking" "firewall" "allowedUDPPorts" ]);

  # --- packages ---------------------------------------------------------------
  packageFacts = concatMap
    (p:
      let
        rawName = p.pname or null;
        name = if isString rawName then rawName else (builtins.parseDrvName (p.name or "")).name or "";
        version = if isString (p.version or null) then p.version else "unknown";
        path = "environment.systemPackages";
      in
      if !(isAttrs p) || !(isString name) || name == "" || builtins.match "[A-Za-z0-9_.+-]+" name == null then [ ]
      else [
        (qInst name "NIXPackage")
        (qInst path "NIXOptionPath")
        (qInst version "NIXVersion")
        [ "packageVersion" (q name) (q version) (q path) ]
      ])
    (get [ ] [ "environment" "systemPackages" ]);

  # --- users ------------------------------------------------------------------
  users = get { } [ "users" "users" ];
  userFacts = concatMap
    (name:
      let path = "users.users." + name; in [
        (qInst name "NIXUser")
        (qInst path "NIXOptionPath")
        [ "userAccount" (q name) (q path) ]
      ] ++ concatMap (group: [
        (qInst group "NIXGroup")
        [ "memberOf" (q name) (q group) (q path) ]
      ]) (users.${name}.extraGroups or [ ]))
    (attrNames users);

  rawFacts = dedupe (serviceFacts ++ firewallFacts ++ packageFacts ++ userFacts);
  facts = map wrapFact rawFacts;

  # --- well-typedness ---------------------------------------------------------
  # Instance facts establish the types; every other lifted fact must satisfy
  # the domain/range signature in the ontology.
  typed = import ./well-typed.nix { ontology = ontology'; inherit facts; };
  illTyped = typed.illTyped;

  declaredHeads = [
    "declaredService" "declaredRunning" "portDeclared" "listenerDeclared"
    "firewallEnabled" "firewallTcpAllowed" "firewallUdpAllowed"
    "packageVersion" "storePath" "userAccount" "memberOf" "aliasOf" "instance"
  ];
  inferredHeads = [ "portInferred" "listenerInferred" ];
  isDeclared = f: elem (headOf (getFact f)) declaredHeads;
  isInferred = f: elem (headOf (getFact f)) inferredHeads;
  declaredFacts = filter isDeclared facts;
  inferredFacts = filter isInferred facts;
  otherFacts = filter (f: !(isDeclared f) && !(isInferred f)) facts;

  serviceCount = length (filter (f: headOf (getFact f) == "declaredService") facts);
  packageCount = length (filter (f: headOf (getFact f) == "instance" && elemAt (getFact f) 2 == "NIXPackage") facts);
  userCount = length (filter (f: headOf (getFact f) == "instance" && elemAt (getFact f) 2 == "NIXUser") facts);

  showBare = f: showFact (getFact f);
  section = label: fs:
    if fs == [ ] then ""
    else ";; source: " + label + "\n" + concatStringsSep "\n" (map showBare fs) + "\n";
in
{
  inherit facts rawFacts systemRules ontology' illTyped ambiguous;
  rules = systemRules;
  ontology = ontology';
  provenance = filter (f: !(headOf (getFact f) == "instance")) facts;
  typed = illTyped == [ ];
  counts = {
    facts = length facts;
    declared = length declaredFacts;
    inferred = length inferredFacts;
    services = serviceCount;
    packages = packageCount;
    users = userCount;
    ambiguous = length ambiguous;
  };
  factsText = concatStringsSep "\n" (map showBare facts) + "\n";
  labeledText =
    ";; lifted by reasoner/lift-config.nix — TODO5 M1 (do not edit)\n"
    + ";; facts: " + toString (length facts)
    + ", declared: " + toString (length declaredFacts)
    + ", inferred: " + toString (length inferredFacts) + "\n"
    + section "declared" declaredFacts
    + section "inferred" inferredFacts
    + section "ambiguous" ambiguous
    + (if otherFacts == [ ] then "" else section "derived" otherFacts);
}
