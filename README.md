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

## Bags and help screens

`bags.nix` groups the pinned SUMO files into canned bags. Ten macro sets (core, life, things, transport, hospitality,
military, society, geography, english, other) partition the 78 files of `sumo.full`. Four test bags (`tests-general`,
`tests-spatial`, `tests-modal`, `tests-all`) group the 84 `.kif.tq` files of `sumo.tests`, the `tests/` directory of
ontologyportal/sumo, by the category each file declares. A bag lists the bags it needs. `compose` puts bags in order and
reports what it added. `match` lists the bags that join a plan with nothing new.

    bin/sumo-nix help            # front screen; also: help bag NAME, help compose, help tq
    bin/sumo-nix bags
    bin/sumo-nix compose military tests-spatial
    bin/sumo-nix match core
    bin/sumo-nix tq tests-general

`tq.nix` runs a test file on the Horn solver with Merge.kif's structural axioms. Of the 84 files: 10 pass, 31 are open (the
answer is yes, and the file needs a non-Horn axiom of Merge.kif that is not loaded), 0 fail, 43 are unsupported (`<=>`,
`forall`, `or`, row variables, compound consequents, typed languages). An unsupported file is not run and gets no verdict.
`tests/bags.nix` checks the bags against `tests/bags-oracle.py`, a separate reader.

## Hugging Face tags anchored in SUMO

`hf/tags.json` is a snapshot (2026-11-02) of the small facets of Hugging Face's public tag lists: 9 modalities, 56 tasks, 82 licenses, 11 domains, 1 origin, plus size, format and library. `hf/anchors.kif` anchors each tag in SUMO:
`exact` (same meaning), `broader` (a SUMO class the tag falls under) or `new` (SUMO has no class: 14 are declared, each under a class SUMO has). Two tags are left out on purpose (`any-to-any`, `simready`), and size, format and library are not SUMO's subject.
A group rule keeps each facet on its branch: modalities under ContentBearingObject, tasks under Process, domains under FieldOfStudy. Two traps are avoided: SUMO's `Table` is furniture and its `Medicine` is a drug.
`hf/check.nix` checks the file; `hf/oracle.py` checks it again with its own reader; `tests/hf.nix` compares them and shows five bad edits being refused. `hf/fetch.py` refreshes the snapshot.
Hugging Face lists domain, origin and modality together under `other`; its own tag lists keep axes apart better than most outlines.
