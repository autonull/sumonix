# The well-typedness gate for lifted/observed facts.
#
# The ontology's own instance facts type the static world (classes, kinds,
# commands). Facts lifted from a config add instance facts too; they must be
# part of the lookup, or every lifted fact looks ill typed. `wellTyped` checks
# every non-instance fact against the domain/range signatures.
{ ontology, facts }:
let
  kif = import ../lib/kif.nix { };
  inherit (kif) headOf;

  inherit (builtins) all any elemAt filter genList groupBy length tail;

  instanceFacts = filter (f: headOf f == "instance" && length f == 3) facts;
  classOfLifted = groupBy (f: elemAt f 1) instanceFacts;
  classesOf = x:
    map (f: elemAt f 2) (classOfLifted.${x} or [ ])
    ++ (ontology.classOf.${x} or [ ]);

  isInstance = x: c: any (k: ontology.isSubclass k c) (classesOf x);

  wellTyped = f:
    let
      sig = ontology.domains.${headOf f} or { };
      args = tail f;
    in
    all
      (i:
        let wanted = sig.${toString (i + 1)} or null; in
        wanted == null || isInstance (elemAt args i) wanted)
      (genList (i: i) (length args));

  typedFacts = filter (f: headOf f != "instance") facts;
  illTyped = filter (f: !(wellTyped f)) typedFacts;
in
{
  inherit isInstance wellTyped illTyped;
  pass = illTyped == [ ];
}
