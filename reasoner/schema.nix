# reasoner/schema.nix — Universal JSON/YAML/TOML ⇄ KIF Schema Mapper
#
#   schema { schemaKif ? ./schemas/default.kif } -> { parseJson, emitJson, validate, toKifPredicates }
#
# Parses schema.kif DSL and generates:
#   parseJson:   string -> KIF facts + meta
#   emitJson:    KIF facts -> string
#   validate:    KIF facts -> { valid: bool, errors: list }
#   toKifPredicates: schema -> list of KIF predicate signatures
#
# Schema DSL (schema.kif):
#   (jsonSchema "name" (object (property "field" (string)) (required "field")))
#   (yamlSchema "name" ...)
#   (tomlSchema "name" ...)
#
# Types: string, int, float, bool, array, object, any
#   (array (string)) — array of strings
#   (object (property "x" (int)) (property "y" (string)) (required "x"))

{ schemaKif ? ./schemas/default.kif }:
let
  kif = import ../lib/kif.nix { };
  forms = kif.parse (builtins.readFile schemaKif);

  inherit (kif) headOf;
  inherit (builtins) all any attrNames attrValues concatMap concatStringsSep elem elemAt filter foldl' genList head isList isString length listToAttrs map sort tail substring match replaceStrings fromJSON toJSON mapAttrs;

  # --- Schema AST parsing -------------------------------------------------------
  # Schema forms: (jsonSchema "name" typeDef) | (yamlSchema "name" typeDef) | (tomlSchema "name" typeDef)
  schemaForms = filter (f: headOf f == "jsonSchema" || headOf f == "yamlSchema" || headOf f == "tomlSchema") forms;

  # Extract schema definitions
  schemaDefs = listToAttrs (map (f:
    { name = elemAt f 1; value = { format = headOf f; typeDef = elemAt f 2; }; }
  ) schemaForms);

  # Type definitions: string, int, float, bool, array, object, any
  # (array (string)) -> { type = "array"; items = { type = "string" } }
  # (object (property "x" (int)) (required "x")) -> { type = "object"; properties = { x = { type = "integer" } }; required = [ "x" ] }

  parseTypeDef = t:
    if isString t then
      if t == "string" then { type = "string"; }
      else if t == "int" then { type = "integer"; }
      else if t == "float" then { type = "number"; }
      else if t == "bool" then { type = "boolean"; }
      else if t == "any" then { }
      else { type = "string"; }  # default
    else if isList t then
      let h = headOf t; in
      if h == "array" then
        { type = "array"; items = parseTypeDef (elemAt t 1); }
      else if h == "object" then
        let
          props = filter (p: headOf p == "property") (tail t);
          required = filter (p: headOf p == "required") (tail t);
          properties = listToAttrs (map (p:
            { name = elemAt p 1; value = parseTypeDef (elemAt p 2); }
          ) props);
          requiredList = concatMap (r: tail r) required;
        in
        { type = "object"; properties = properties; required = requiredList; }
      else { type = "string"; }
    else { type = "string"; };

  # Compile all schemas
  compiledSchemas = mapAttrs (name: def:
    { format = def.format; typeDef = parseTypeDef def.typeDef; }
  ) schemaDefs;

  # --- JSON parsing -------------------------------------------------------------
  # parseJson: name -> jsonStr -> { facts, meta }
  parseJson = name: jsonStr:
    let
      schema = compiledSchemas.${name} or null;
      data = fromJSON jsonStr;
      # Validate against schema (simplified)
      validated = if schema == null then data else data;  # TODO: full validation
      # Convert to KIF facts
      facts = jsonToKif name validated;
      meta = { sourceClass = "fixture"; sourceId = "schema.nix:parseJson:${name}"; observedAt = 0; expiresAt = 0; snapshotId = ""; contentHash = ""; confidence = 0.9; provenance = [ ]; };
      factsWithMeta = map (f: f // { meta = meta; }) facts;
    in
    { inherit factsWithMeta; };

  # --- JSON emission ------------------------------------------------------------
  # emitJson: name -> facts -> string
  emitJson = name: facts:
    let
      schema = compiledSchemas.${name} or null;
      json = kifToJson name facts;
    in
    toJSON json;

  # --- Validation ---------------------------------------------------------------
  # validate: name -> facts -> { valid, errors }
  validate = name: facts:
    let
      schema = compiledSchemas.${name} or null;
      errors = if schema == null then [ ] else [ ];  # TODO: full validation
    in
    { valid = errors == [ ]; inherit errors; };

  # --- KIF predicate signatures -------------------------------------------------
  # toKifPredicates: name -> list of predicate signatures
  toKifPredicates = name:
    let
      schema = compiledSchemas.${name} or null;
      typeDef = schema.typeDef or { };
      predicates = typeDefToPredicates name typeDef;
    in
    predicates;

  # --- Helper: JSON to KIF facts ------------------------------------------------
  jsonToKif = prefix: data:
    if isList data then
      concatMap (jsonToKif prefix) data
    else if isString data || builtins.isInt data || builtins.isFloat data || data == true || data == false || data == null then
      [ [ "jsonValue" prefix (toString data) ] ]
    else if isList (attrNames data) then  # object
      concatMap (k:
        jsonToKif "${prefix}.${k}" (data.${k})
      ) (attrNames data)
    else
      [ ];

  # --- Helper: KIF to JSON ------------------------------------------------------
  kifToJson = prefix: facts:
    let
      relevant = filter (f: headOf f == "jsonValue" && elemAt f 1 == prefix) facts;
      build = fs:
        if fs == [ ] then { }
        else
          let f = head fs; key = elemAt f 2; value = elemAt f 3; in
          { ${key} = value; } // build (tail fs);
    in
    build relevant;

  # --- Helper: TypeDef to KIF predicates ----------------------------------------
  typeDefToPredicates = prefix: typeDef:
    if typeDef.type == "object" then
      concatMap (k:
        let prop = typeDef.properties.${k} or { }; in
        [ [ "domain" "jsonValue" 1 prefix ] [ "domain" "jsonValue" 2 "string" ] ]  # simplified
      ) (attrNames (typeDef.properties or { }))
    else if typeDef.type == "array" then
      typeDefToPredicates prefix typeDef.items
    else
      [ ];

in
{
  inherit parseJson emitJson validate toKifPredicates compiledSchemas;
}