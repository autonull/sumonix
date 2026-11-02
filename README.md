# sumo-nix

The SUMO upper ontology as Nix lambdas, read from its KIF text. It needs [mlnix](https://github.com/jnorthrup/mlir-nix) (or any Nix) to run, and nothing else.

TrikeShed keeps a 13-term hand-written spine (`SumoOntology.kt`) and a frozen binary of SUMO. This repository
uses neither. The source is the KIF file at the commit pinned in `pins.nix`, the same commit and hashes as
TrikeShed's `utils/sumo/sumo-corpus.pins`. `builtins.fetchurl` downloads it once and refuses a file whose SHA-256 differs.

| file | what |
| --- | --- |
| `kif.nix` | `parse`: KIF text to S-expressions (an atom is a string, a list is a list) |
| `sumo.nix` | `parents`, `ancestors`, `classOf`, `domains`, `isSubclass`, `isInstance`, `wellTyped`, and `classes`: each SUMO class as a predicate lambda |
| `datalog.nix` | forward chaining over `(=> ..)` rules: `facts`, `holds`, `ask`, `why`, `explain`; every derived fact keeps its rule and the facts it rests on |
| `nix-domain.kif`, `rules.kif` | the NIX classes and relations under SUMO, and the rules, from [nix_sumo.md](https://gist.github.com/autonull/2d60c4001c8f92f25945ed6decee39f1) sections 6, 11 and 18 |
| `pins.nix` | the pinned corpus |
| `tests/default.nix`, `tests/rules.nix` | `mlnix eval tests/default.nix` prints `"ok"`; so does `tests/rules.nix` |

```
$ mlnix eval -E 'let k = import ./kif.nix; p = import ./pins.nix;
                     o = import ./sumo.nix { forms = k.parse (builtins.readFile p.merge); };
                 in o.ancestors.Human'
```

## Through the dialects

mlnix has the layers above the nix dialect: `sumo` (relations as ops) lowers to `kif` (terms, facts, rules) lowers to `nix`
(`include/NixDialect/Kif.td`, `Sumo.td` in mlir-nix). The scenario as dialect ops is `test/mlir/inputs/kif-openssl.mlir` there.

```
mlnix-opt kif-openssl.mlir --sumo-to-kif --kif-to-nix > theory.mlir
mlnix run-mlir theory.mlir --json > theory.json
mlnix eval -E 'import ./tests/scenario.nix (builtins.fromJSON (builtins.readFile ./theory.json))'     # "ok"
```

`tests/scenario.nix` is the same check that `tests/rules.nix` runs on KIF text, so the two paths must agree.
The solver itself is still the Nix in `datalog.nix`, not IR.

## What is covered

Top-level `subclass`, `instance` and `domain` forms of `Merge.kif`: 5,505 forms, 712 classes with a parent, 714 classes.
The engine covers `and`, `exists`, `not`, `equal` and `(instance X Class)` (subclasses by the ontology). A proof lists asserted facts and rules, not the `subclass` steps the ontology supplied.
Not yet: `Mid-level-ontology.kif`, `or`, `forall`, `range`, `subrelation`, `documentation`, and the implicit
`(instance C Class)` that every `subclass` form implies, so `wellTyped "subclass" [...]` is false for a class name.

## Checked

The expected numbers in the tests come from a separate Python reader of the same file. The tests give `"ok"` on mlnix and on Nix 2.35.4.
Breaking the ancestor fold, the transitive rule or the severity test makes them fail. `tests/rules.nix` runs the scenario of section 18 of the gist.

## Known gap in mlnix

The first `mlnix eval` that fetches a file fails with `path ... is not valid` when it reads it in the same run. A second run works.
