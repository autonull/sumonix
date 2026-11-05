# T2.6 Builtins/Aggregates: builtin predicate registry.
#
#   builtins { } -> { greaterThan, lessThan, notEqual, compareVersions, subsetOf, supersetOf, ... }
#
# Each builtin has:
#   arity: int (number of arguments excluding the predicate name)
#   eval: bindings -> args -> bool
#   description: string
#
# Builtins are called during step() when a premise's head matches a builtin name.
# They receive substituted arguments and return true/false.
{ }:
let
  inherit (builtins) all any attrNames concatMap concatStringsSep elem elemAt filter foldl' genList head isList isString length map sort tail substring match replaceStrings;

  # Version comparison: parse "1.2.3" -> [ 1 2 3 ]
  # KIF parser keeps quotes: "1.2.3" -> "\"1.2.3\"", so strip outer quotes first
  stripQuotes = s:
    if isString s && builtins.stringLength s >= 2 && substring 0 1 s == "\"" && substring (builtins.stringLength s - 1) 1 s == "\"" then
      substring 1 (builtins.stringLength s - 2) s
    else s;

  parseVersion = v:
    if isString v then
      let
        unquoted = stripQuotes v;
        spaced = replaceStrings [ "." ] [ " " ] unquoted;
        # Match up to 4 version components - match returns capture groups directly
        m = match "([0-9]+) ?([0-9]+)? ?([0-9]+)? ?([0-9]+)?" spaced;
        # Filter nulls first, then convert to int
        nums = map builtins.fromJSON (builtins.filter (x: x != null) m);
      in
      if m == null then [ ]
      else nums
    else [ ];

  compareVersions = a: b:
    let
      va = parseVersion a;
      vb = parseVersion b;
      maxLen = if length va > length vb then length va else length vb;
      pad = l: l ++ builtins.genList (_: 0) (maxLen - length l);
      vaP = pad va;
      vbP = pad vb;
      cmp = foldl' (acc: i: if acc != 0 then acc else if elemAt vaP i < elemAt vbP i then -1 else if elemAt vaP i > elemAt vbP i then 1 else 0) 0 (genList (i: i) maxLen);
    in cmp;

  # Greater than: (greaterThan ?x ?y) where ?x and ?y are numbers or version strings
  greaterThan = {
    arity = 2;
    eval = b: args:
      let x = head args; y = head (tail args); in
      if isString x && isString y then
        compareVersions x y > 0
      else if builtins.isInt x && builtins.isInt y then
        x > y
      else if builtins.isFloat x && builtins.isFloat y then
        x > y
      else
        false;
    description = "greaterThan(?x, ?y) — true if x > y (numbers or version strings)";
  };

  # Less than: (lessThan ?x ?y)
  lessThan = {
    arity = 2;
    eval = b: args:
      let x = head args; y = head (tail args); in
      if isString x && isString y then
        compareVersions x y < 0
      else if builtins.isInt x && builtins.isInt y then
        x < y
      else if builtins.isFloat x && builtins.isFloat y then
        x < y
      else
        false;
    description = "lessThan(?x, ?y) — true if x < y (numbers or version strings)";
  };

  # Not equal: (notEqual ?x ?y)
  notEqual = {
    arity = 2;
    eval = b: args:
      let x = head args; y = head (tail args); in
      x != y;
    description = "notEqual(?x, ?y) — true if x != y";
  };

  # Compare versions: (compareVersions ?a ?b ?result) where ?result = -1 | 0 | 1
  # This is a ternary relation, not a boolean predicate
  compareVersionsRel = {
    arity = 3;
    eval = b: args:
      let a = head args; b2 = head (tail args); result = head (tail (tail args)); in
      if isString a && isString b2 then
        result == toString (compareVersions a b2)
      else
        false;
    description = "compareVersions(?a, ?b, ?result) — result is -1, 0, or 1";
  };

  # Parse KIF list string like "[ \"a\" \"b\" ]" to Nix list [ "a" "b" ]
  # Manual parsing without builtins.split (which has weird behavior in this Nix version)
  parseKifList = s:
    if isString s then
      let
        stripped = substring 1 (builtins.stringLength s - 2) s;  # Remove [ and ]
        # Parse space-separated quoted strings manually
        parseParts = str: idx:
          if idx >= builtins.stringLength str then [ ]
          else
            let
              # Skip leading spaces
              skipSpaces = i: if i < builtins.stringLength str && substring i 1 str == " " then skipSpaces (i + 1) else i;
              start = skipSpaces idx;
            in
            if start >= builtins.stringLength str then [ ]
            else
              let
                # Find end of token (space or end of string)
                findEnd = i: if i < builtins.stringLength str && substring i 1 str != " " then findEnd (i + 1) else i;
                end = findEnd start;
                token = substring start (end - start) str;
                # Strip quotes if present
                cleaned = if builtins.stringLength token >= 2 && substring 0 1 token == "\"" && substring (builtins.stringLength token - 1) 1 token == "\"" then
                  substring 1 (builtins.stringLength token - 2) token
                else token;
              in
              [ cleaned ] ++ parseParts str (end + 1);
      in
      parseParts stripped 0
    else [ ];

  # Subset of: (subsetOf ?set1 ?set2) where sets are KIF list strings
  subsetOf = {
    arity = 2;
    eval = b: args:
      let s1 = head args; s2 = head (tail args);
          l1 = parseKifList s1; l2 = parseKifList s2;
      in
      all (x: elem x l2) l1;
    description = "subsetOf(?set1, ?set2) — true if every element of set1 is in set2";
  };

  # Superset of: (supersetOf ?set1 ?set2)
  supersetOf = {
    arity = 2;
    eval = b: args:
      let s1 = head args; s2 = head (tail args);
          l1 = parseKifList s1; l2 = parseKifList s2;
      in
      all (x: elem x l1) l2;
    description = "supersetOf(?set1, ?set2) — true if every element of set2 is in set1";
  };

  # Count aggregate: (count ?var ?groupBy ?result)
  # This is more complex - for now we'll implement a simple version
  count = {
    arity = 3;
    eval = b: args: false;  # Placeholder - aggregates need special handling
    description = "count(?var, ?groupBy, ?result) — count of var per groupBy";
  };

in
{
  inherit greaterThan lessThan notEqual compareVersionsRel subsetOf supersetOf count;
}