# The SUMO ontology as lambdas, read from its KIF text.
#
#   ontology = import ./sumo.nix { forms = kif.parse (builtins.readFile Merge.kif); };
#
# `frozen` is { parents, classOf, domains } as sumo-nix-os keeps them in ontology.json: the same tables without reading a KIF file.
#
# Nothing is copied by hand: every class, every instance and every relation signature comes from a top-level
# (subclass ..), (instance ..) or (domain ..) form of the file. All fields are lazy.
{ forms ? [ ], frozen ? null }:
let
  inherit (builtins) all any attrNames concatMap elem elemAt filter foldl' head isList isString length listToAttrs map mapAttrs zipAttrsWith;

  top = name: filter (f: isList f && f != [ ] && head f == name) forms;

  group = zipAttrsWith (_: vs: vs);
  unique = xs: attrNames (listToAttrs (map (name: { inherit name; value = null; }) xs));

  # (subclass Child Parent): a class can have several parents.
  parents = if frozen != null then frozen.parents else group (map (f: { ${elemAt f 1} = elemAt f 2; }) (filter (f: length f == 3 && isString (elemAt f 1) && isString (elemAt f 2)) (top "subclass")));

  # Every class above a class, itself not included. The knot is lazy: a class reads its parents' entries on demand.
  ancestors = mapAttrs (_: ps: unique (ps ++ concatMap (p: ancestors.${p} or [ ]) ps)) parents;

  # (instance Thing Class): a thing can be an instance of several classes.
  classOf = if frozen != null then frozen.classOf else group (map (f: { ${elemAt f 1} = elemAt f 2; }) (filter (f: length f == 3 && isString (elemAt f 1) && isString (elemAt f 2)) (top "instance")));

  isSubclass = c: a: c == a || elem a (ancestors.${c} or [ ]);
  isInstance = x: c: any (k: isSubclass k c) (classOf.${x} or [ ]);

  # (domain Relation Position Class): the class the argument at Position must belong to.
  domains = if frozen != null then frozen.domains else zipAttrsWith (_: foldl' (a: b: a // b) { })
    (map (f: { ${elemAt f 1} = { ${elemAt f 2} = elemAt f 3; }; }) (filter (f: length f == 4 && isString (elemAt f 1) && isString (elemAt f 2) && isString (elemAt f 3)) (top "domain")));

  # A relation applied to things is well typed when each thing belongs to the class its position asks for.
  wellTyped = rel: args:
    let sig = domains.${rel} or { }; in
    all (i: !(sig ? ${toString (i + 1)}) || isInstance (elemAt args i) sig.${toString (i + 1)}) (builtins.genList (i: i) (length args));
in
{
  inherit parents ancestors classOf domains isSubclass isInstance wellTyped;

  # Every class is a predicate on things.
  classes = listToAttrs (map (c: { name = c; value = x: isInstance x c; })
    (unique (attrNames parents ++ concatMap (ps: ps) (builtins.attrValues parents))));
}
