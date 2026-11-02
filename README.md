# sumo-nix

The SUMO upper ontology as Nix lambdas, read from its KIF text. It needs [mlnix](https://github.com/jnorthrup/mlir-nix) (or any Nix) to run, and nothing else.

TrikeShed keeps a 13-term hand-written spine (`SumoOntology.kt`) and a frozen binary of SUMO. This repository
uses neither. The source is the KIF file at the commit pinned in `pins.nix`, the same commit and hashes as
TrikeShed's `utils/sumo/sumo-corpus.pins`. `builtins.fetchurl` downloads it once and refuses a file whose SHA-256 differs.

| file | what |
| --- | --- |
| `kif.nix` | `parse`: KIF text to S-expressions (an atom is a string, a list is a list) |
| `sumo.nix` | `parents`, `ancestors`, `classOf`, `domains`, `isSubclass`, `isInstance`, `wellTyped`, and `classes`: each SUMO class as a predicate lambda |
| `pins.nix` | the pinned corpus |
| `tests/default.nix` | `mlnix eval tests/default.nix` prints `"ok"` |

```
$ mlnix eval -E 'let k = import ./kif.nix; p = import ./pins.nix;
                     o = import ./sumo.nix { forms = k.parse (builtins.readFile p.merge); };
                 in o.ancestors.Human'
```

## What is covered

Top-level `subclass`, `instance` and `domain` forms of `Merge.kif`: 5,505 forms, 712 classes with a parent, 714 classes.
Not yet: `Mid-level-ontology.kif`, rules (`=>`), `range`, `subrelation`, `documentation`, and the implicit
`(instance C Class)` that every `subclass` form implies, so `wellTyped "subclass" [...]` is false for a class name.

## Checked

The expected numbers in the tests come from a separate Python reader of the same file. The tests give `"ok"` on mlnix and on Nix 2.35.4.
Breaking the ancestor fold makes them fail.

## Known gap in mlnix

The first `mlnix eval` that fetches a file fails with `path ... is not valid` when it reads it in the same run. A second run works.
