# M3A — CLI evaluation surface for `sumo lift`, `sumo drift` and `sumo repair`.
#
#   ev = import ./bin/_metavisor.nix {
#     configuration = "/etc/nixos/configuration.nix";  # live system config
#     declaredFile = null;                              # or a pre-lifted KIF file
#     observedFile = "/run/sumo/observed.kif";
#     now = builtins.currentTime;
#   };
#   ev.lift.{text,json}     ev.drift.{text,json,journal,status}     ev.repair.{text,json}
#
# A configuration is loaded through <nixpkgs/nixos> exactly once per operation.
# Repair re-lifts a *real* patched configuration (the M4 contract); facts are
# never edited here.
{ configuration ? null
, declaredFile ? null
, observedFile ? null
, now ? builtins.currentTime
}:
let
  kif = import ../lib/kif.nix { };
  inherit (kif) parse show;

  inherit (builtins)
    concatStringsSep filter isList pathExists readFile;

  pkgs = import <nixpkgs> { };
  inherit (pkgs) lib;

  systemForms = parse (readFile ../system.kif);
  isRule = f: isList f && f != [ ] && builtins.head f == "=>";
  systemRules = filter isRule systemForms;
  systemOntology = filter (f: !(isRule f)) systemForms;

  ontology = import ../sumo.nix {
    forms = parse (readFile ../sumo.full/Merge.kif)
      ++ parse (readFile ../nix-domain.kif)
      ++ systemOntology;
  };

  toPath = p: /. + p;

  loadConfig = extra: (import <nixpkgs/nixos> {
    system = builtins.currentSystem;
    configuration = { imports = extra; };
  }).config;

  liftConfig = config:
    import ../reasoner/lift-config.nix { inherit config ontology; };

  baseLift =
    if configuration == null then null
    else liftConfig (loadConfig [ (toPath configuration) ]);

  # A pre-lifted file is facts only; the rules/ontology stay local so the
  # certificate and the engine match the code that reads it.
  declaredFromFile = {
    facts = parse (readFile declaredFile);
    inherit systemRules ontology;
    rules = systemRules;
  };

  base =
    if declaredFile != null then declaredFromFile
    else baseLift;

  observedText =
    if observedFile != null && pathExists observedFile then readFile observedFile else "";

  observedLabel = if observedFile == null then "observed.kif" else observedFile;
  declaredLabel =
    if declaredFile != null then declaredFile
    else if configuration != null then configuration
    else "declared.kif";

  mv =
    if base == null then null
    else import ../reasoner/metavisor.nix {
      declared = base;
      observed = observedText;
      inherit now;
      declaredSource = declaredLabel;
      observedSource = observedLabel;
    };

  # Repair needs a real configuration to patch: a pre-lifted file cannot be
  # edited honestly.
  patched = edit:
    let
      value = lib.mkOverride 10 edit.value;
      extra = lib.setAttrByPath (lib.splitString "." edit.optionPath) value;
    in liftConfig (loadConfig [ (toPath configuration) extra ]);

  repair =
    if baseLift == null || configuration == null then null
    else import ../reasoner/repair.nix { base = baseLift; inherit patched; };

  summarize = c: {
    inherit (c) name rank verified reason;
    edits = c.edits or [ ];
    diff = c.diff or "";
    proof = c.proof or "";
    factDiff = c.factDiff or { added = [ ]; removed = [ ]; };
  };

  repairText = r:
    if r == null then "repair: no configuration given"
    else
      "base gate: " + (if r.baseGate.pass then "pass" else "violation")
      + "\n"
      + (if r.baseGate.pass then "no violation to repair\n" else r.baseGate.proof + "\n")
      + "candidates: " + toString r.count.candidates
      + ", verified: " + toString r.count.verified
      + ", rejected: " + toString r.count.rejected + "\n\n"
      + (if r.ranked == [ ] then "no verified repair\n" else
        concatStringsSep "\n" (map
          (c:
            "#" + toString c.rank + " " + c.name + "\n"
            + (c.diff or "") + "\n"
            + "re-lifted gate: " + (if c.gate.pass then "pass" else "fail") + "\n"
            + c.proof + "\n")
          r.ranked))
      + (if r.rejected == [ ] then "" else
        "\nrejected:\n" + concatStringsSep "\n"
          (map (c: "  - " + c.name + ": " + c.reason) r.rejected) + "\n");
in
{
  inherit base mv repair;

  lift =
    if baseLift == null then null
    else {
      inherit (baseLift) counts typed ambiguous;
      facts = map show baseLift.facts;
      illTyped = map show baseLift.illTyped;
      text = baseLift.labeledText;
      json = builtins.toJSON {
        inherit (baseLift) counts typed;
        facts = map show baseLift.facts;
        illTyped = map show baseLift.illTyped;
        ambiguous = map show baseLift.ambiguous;
      };
    };

  drift =
    if mv == null then null
    else {
      inherit (mv) status journal;
      text = mv.text;
      json = builtins.toJSON mv.json;
      journalText =
        concatStringsSep "\n" mv.journal
        + (if mv.journal == [ ] then "" else "\n");
    };

  repairResult =
    if repair == null then null
    else {
      inherit (repair) count;
      text = repairText repair;
      json = builtins.toJSON {
        pass = repair.baseGate.pass;
        proof = repair.baseGate.proof;
        inherit (repair) count;
        ranked = map summarize repair.ranked;
        rejected = map summarize repair.rejected;
      };
    };
}
