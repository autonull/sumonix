# reasoner/audit.nix — Audit Ingestion Pipeline (simplified for Phase 3)
#
# Stages (composable, each returns KIF facts + meta):
#   stage1_runtimeClosure   — nix store query --requisites /run/current-system
#   stage2_configClosure    — schema mapper: flake.lock -> packageVersion, dependsOn, storePath
#   stage3_vulnerabilities  — schema mapper: OSV JSON -> vulnerable, severity, fixedIn
#   stage4_licenses         — schema mapper: SPDX -> license, licenseExpr
#   stage5_policyCheck      — Run datalog.nix with vuln/license rules
#
# Main entry:
#   audit { flakeLock, osvCache, spdxCache, rules, ontology } ->
#     { facts, violations, engine }

{ flakeLock ? ../flake.lock, osvCache ? ../.osv-cache.json, spdxCache ? ../.spdx-cache.json, rules, ontology }:
let
  kif = import ../lib/kif.nix { };
  schema = import ./schema.nix { };

  inherit (builtins) all any attrNames attrValues concatMap concatStringsSep elem elemAt filter foldl' genList head isList isString length listToAttrs map sort tail substring match replaceStrings fromJSON toJSON readFile;

  # --- Stage 1: Runtime closure (live system) -----------------------------------
  stage1_runtimeClosure = { }:
    let
      meta = { sourceClass = "observed"; sourceId = "audit.nix:stage1_runtimeClosure"; observedAt = 0; expiresAt = 0; snapshotId = ""; contentHash = ""; confidence = 1.0; provenance = [ ]; };
    in
    [ ];

  # --- Stage 2: Config closure (from flake.lock) --------------------------------
  stage2_configClosure = { }:
    let
      lockData = fromJSON (readFile flakeLock);
      meta = { sourceClass = "fixture"; sourceId = "audit.nix:stage2_configClosure"; observedAt = 0; expiresAt = 0; snapshotId = ""; contentHash = ""; confidence = 0.9; provenance = [ ]; };
      packages = lockData.nodes or { };
      pkgNames = attrNames packages;
      facts = builtins.concatMap (name: attrs:
        let
          locked = attrs.locked or { };
          version = locked.version or locked.rev or "";
          storePath = locked.narHash or "";
        in
        if version != "" then
          [ (["packageVersion" name version "flake.lock"] // { meta = meta; })
            (["storePath" name storePath "flake.lock"] // { meta = meta; }) ]
        else [ ]
      ) pkgNames;
    in
    facts;

  # --- Stage 3: Vulnerabilities (from OSV) --------------------------------------
  stage3_vulnerabilities = { }:
    let
      osvData = fromJSON (readFile osvCache);
      meta = { sourceClass = "fixture"; sourceId = "audit.nix:stage3_vulnerabilities"; observedAt = 0; expiresAt = 0; snapshotId = ""; contentHash = ""; confidence = 0.95; provenance = [ ]; };
      vulns = osvData.vulns or [ ];
      facts = builtins.concatMap (v:
        let
          cve = v.id or "";
          affected = v.affected or [ ];
          pkgFacts = builtins.concatMap (a:
            let
              pkg = a.package.name or "";
              ranges = a.ranges or [ ];
              versions = a.versions or [ ];
              rangeFacts = builtins.concatMap (r:
                let
                  events = r.events or [ ];
                  introduced = (head (filter (e: e.introduced != null) events)).introduced or "";
                  fixed = (head (filter (e: e.fixed != null) events)).fixed or "";
                in
                if fixed != "" then
                  [ (["vulnerable" pkg cve] // { meta = meta; })
                    (["fixedIn" pkg fixed] // { meta = meta; }) ]
                else if introduced != "" then
                  [ (["vulnerable" pkg cve] // { meta = meta; }) ]
                else [ ]
              ) ranges;
              versionFacts = builtins.concatMap (ver:
                [ (["vulnerable" pkg cve] // { meta = meta; }) ]
              ) versions;
            in
            rangeFacts ++ versionFacts
          ) affected;
        in
        pkgFacts
      ) vulns;
    in
    facts;

  # --- Stage 4: Licenses (from SPDX) --------------------------------------------
  stage4_licenses = { }:
    let
      spdxData = fromJSON (readFile spdxCache);
      meta = { sourceClass = "fixture"; sourceId = "audit.nix:stage4_licenses"; observedAt = 0; expiresAt = 0; snapshotId = ""; contentHash = ""; confidence = 0.9; provenance = [ ]; };
      packages = spdxData.packages or [ ];
      facts = builtins.concatMap (p:
        let
          name = p.name or "";
          license = p.licenseConcluded or p.licenseDeclared or "NOASSERTION";
        in
        if name != "" && license != "NOASSERTION" then
          [ (["packageLicense" name license] // { meta = meta; }) ]
        else [ ]
      ) packages;
    in
    facts;

  # --- Stage 5: Policy check ----------------------------------------------------
  stage5_policyCheck = { facts }:
    let
      engine = import ../datalog.nix { ontology = ontology; rules = rules; facts = facts; builtinRegistry = import ../reasoner/builtins.nix { }; };
      violations = engine.ask [ "policyViolation" "?pkg" "?reason" ];
    in
    { inherit violations engine; };

  # --- Main entry ---------------------------------------------------------------
  audit = { }:
    let
      facts1 = stage1_runtimeClosure { };
      facts2 = stage2_configClosure { };
      facts3 = stage3_vulnerabilities { };
      facts4 = stage4_licenses { };
      allFacts = facts1 ++ facts2 ++ facts3 ++ facts4;
      result = stage5_policyCheck { facts = allFacts; };
    in
    { facts = allFacts; violations = result.violations; engine = result.engine; };

in
{
  inherit stage1_runtimeClosure stage2_configClosure stage3_vulnerabilities stage4_licenses stage5_policyCheck audit;
}