# Pick Your AI OS

Pick Your AI OS is a working name for one idea: keep a project's knowledge and organization the way NixOS keeps a computer. The state is declared in files. Every input is pinned by hash. A change is built and checked before it takes effect. Anyone can rebuild the same result and see why it is what it is.

It is not a model, and it does not judge prose, sources or licenses. It is lookup and checking over pinned data, with typed answers that say "unknown" when they do not know (the way Jev frames answers for JSON, but with no model behind them). The parts are [mlnix](https://github.com/jnorthrup/mlir-nix) (a Nix evaluator on MLIR), this repository (the SUMO ontology and Horn rules in plain Nix), and `org/` (the pages of an organization's repositories, pinned and taxonomized).

## What NixOS gives a computer, and what the same property gives a project

| NixOS | In the knowledge and organization space | Here today |
| --- | --- | --- |
| `configuration.nix`: the machine is a declared value | The taxonomy, the roles and the process rules are files that anyone can read, diff and review. | Built: `org/taxonomy.kif`, `org/rules.kif`, `org/rules-closed.kif`, `org/classify.nix` |
| `flake.lock`: inputs pinned by hash | Every claim names the exact bytes it came from: a commit, a git blob SHA or a SHA-256. | Built: `org/PINS`, `org/pages.json`, `sumo.full/PINS` |
| Reproducible builds | The same pages give the same answers on any machine and on two Nix evaluators. A second reading in jq agrees. | Built: `tests/org.nix` on mlnix and on Nix 2.35.4 |
| Pure evaluation | A check reads pinned data and nothing else. Fetching is a separate, visible step. | Built: `org/check.nix` only reads; the `gh api` fetch is described in `org/extract.nix` |
| A content-addressed store | The same bytes have the same name. Identical copies of a page are found by hash, and so is a page that changed after it was cited. | Built for copies (`identicalCopy`). Changed-since-cited was done by hand so far |
| Generations and rollback | Each pin set is a generation. An earlier `PINS` with its `pages.json` rebuilds an earlier view. | Partly: git keeps the generations. A diff of two generations is not built |
| An atomic switch after the build passes | A new pin set takes effect when its tests pass, not before. | Partly: the tests exist. The switch is a commit |
| `nixos-rebuild test` and VM tests | The rules have tests, and the tests are tested by breaking the rules on purpose: 13 mutations, each caught by a named assertion. | Built |
| Assertions and option types | A missing fact is `unclassified` or `unknown`, never a guess. A broken rule stops the build loudly. | Built |
| `nix why-depends` | Every conclusion has a proof tree, for example `why [ "staleName" page name ]`. | Built: `why` in `org/check.nix` |
| The module system | Teams add page kinds and rules as files, merged without editing each other's. | Not built: there is one rule table |
| Overlays | A team's local exception overrides a default for one repository, in plain view. | Not built |
| Closures (`nix-store -qR`) | "What does this decision depend on?": the pages it links to, and the pages they link to. | Not built: links are not extracted yet |
| Garbage collection | Pages that nothing refers to are listed as candidates to retire. | Not built |
| A multi-user store: trust the hash, not the user | A contributor does not need an administrator's word. Anyone can recompute the hash and run the check. This suits a project with one owner account and many contributors. | Built for the data above |

The last column describes this repository only. It says nothing about what any project has adopted.

## What it does not do

- It does not say who wrote a page. "Says it was generated" means the page carries its own marker.
- It does not read meaning. A rule table puts a page in a kind by its path and name; a person or a model still reads the pages in the "general" kind and the pages marked unknown.
- It does not replace review. It removes the mechanical part of review (is this the file that was cited, is this copy the same copy, does this page still use a retired name) so that reviewers keep their time for the judgment calls.

## Try it

```
mlnix eval --raw tests/org.nix                       # ok
nix-instantiate --eval --strict tests/org.nix        # "ok" on Nix 2.35.4
jq -S -L org -f org/expected.jq org/pages.json       # the second reading, no Nix
```
