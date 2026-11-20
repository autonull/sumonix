# reasoner/policy-pack.nix — Policy Pack Loader
#
#   policy-pack { packFlake, systemKif ? ../system.kif, baseOntology ? ../sumo.full/Merge.kif } ->
#     { rules, schema, ontology, metadata }
#
# Policy pack = flake input with:
#   schema.kif     — JSON/YAML/TOML mappings
#   rules.kif      — KIF rules using mapped predicates
#   ontology.kif   — additional SUMO types
#   metadata.json  — { name, version, description, depends: [] }

{ packFlake, systemKif ? ../system.kif, baseOntology ? ../sumo.full/Merge.kif }:
let
  kif = import ../lib/kif.nix { };
  inherit (kif) headOf;
  inherit (builtins) all concatMap concatStringsSep filter attrNames head tail elem isString isList;

  # Load pack from flake
  pack = import (packFlake + "/default.nix") { };

  # Parse schema
  schema = import ./schema.nix { schemaKif = pack.schema; };

  # Parse rules
  rules = kif.parse (builtins.readFile pack.rules);

  # Parse ontology
  ontologyForms = kif.parse (builtins.readFile pack.ontology);

  # Combine with base ontology
  baseOntologyForms = kif.parse (builtins.readFile baseOntology);
  systemForms = kif.parse (builtins.readFile systemKif);

  # Full ontology: SUMO + Nix domain + system + pack ontology
  allForms = baseOntologyForms ++ systemForms ++ ontologyForms;
  ontology = import ../sumo.nix { forms = allForms; };

  # Validate: pack rules only use predicates from schema + base ontology
  # Extract predicate names from schema
  schemaPredicates = concatMap (name:
    map (p: head p) (schema.toKifPredicates name)
  ) (attrNames schema.compiledSchemas);

  basePredicates = concatMap (f:
    if headOf f == "domain" || headOf f == "instance" || headOf f == "subclass"
    then [ headOf f ] else [ ]
  ) allForms;

  allAllowedPredicates = schemaPredicates ++ basePredicates;

  # Check each rule uses only allowed predicates
  checkPredicates = rule:
    let
      allPreds = extractPredicates rule;
      invalid = filter (p: !(elem p allAllowedPredicates)) allPreds;
    in
    if invalid != [ ] then
      throw "policy-pack: rule uses invalid predicates: " + concatStringsSep ", " invalid
    else true;

  extractPredicates = form:
    if isString form then [ ]
    else if isList form then
      let h = head form; in
      if h == "and" || h == "or" || h == "not" || h == "=>" || h == "exists" || h == "equal"
      then concatMap extractPredicates (tail form)
      else [ h ] ++ concatMap extractPredicates (tail form)
    else [ ];

  # Validate all rules
  validation = all (checkPredicates) rules;

  # Metadata
  metadata = pack.metadata or { name = "unknown"; version = "0.0.0"; description = ""; depends = [ ]; };

in
{
  inherit rules schema ontology metadata validation;
}