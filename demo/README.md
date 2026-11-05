# 🎬 The 60-second demo

`./demo/run` plays five standalone scenes, each a real invocation of the engine — no mocks, no setup, ~30 seconds total, fully offline (the nixpkgs facts are committed, `demo/facts/nixpkgs.kif`).

| # | Scene | Shows | Cast |
|---|-------|-------|------|
| 01 | **The 30-second proof** | Derive → export certificate → independent re-check → tamper refused | `demo/casts/01-30-seconds.cast` |
| 02 | **Your package set, reasoned over** | Real nixpkgs facts → capability composition, transitive closure, synergies | `demo/casts/02-capabilities.cast` |
| 03 | **Your organization, reasoned over** | Pick Your AI pages taxonomized under SUMO: 2,109 pages, class reasoning, identical copies, retired names, all with proofs | `demo/casts/03-pages.cast` |
| 04 | **The crosswalk knows what it knows** | Typed questions over PyAI ↔ HF ↔ SUMO; answers are 0/1 plus an explicit null | `demo/casts/04-crosswalk.cast` |
| 05 | **The build fails — and here is why** | Build gate, the proof it emits, the relaxation menu (the single-flip question) | `demo/casts/05-when-the-build-breaks.cast` |

## Run it

```bash
./demo/run                    # everything, ~30s
./demo/run 02-capabilities.sh # one scene
./demo/run scenes/05-*.sh     # glob works too
```

Each scene is a `demo/scenes/<name>.sh` that prints its transcript with `demo/lib.sh` helpers (`say`, `cmd`). Scenes that need Nix evaluation call `./nix-eval.sh` with an absolute path to the repo.

## Screen-record it

```bash
./demo/record                 # re-records every scene into demo/casts/*.cast (needs asciinema ≥ 2.4)
asciinema play demo/casts/02-capabilities.cast
```

asciinema recordings are committed — they are tiny (≈4 KB each, plain text). The README embeds the same transcripts verbatim.

## What each scene proves

- **01** — the certificate is independently re-checkable, and alteration is caught. This is the trust anchor for every other scene.
- **02** — the SUMO layer is not decoration: class/instance subsumption plus Horn rules over *real* nixpkgs meta produce answers a README cannot (which capabilities compose, which your closure unlocks, where they combine).
- **03** — anything that can be factual knowledge can be reasoned over, not just packages: 2,109 documents, their kinds, copies, and retired names, each with a `why` proof.
- **04** — the engine never guesses: gaps are explicit nulls, not silent `no`s; the crosswalk is a rule set, not a model.
- **05** — policy is a build step with a machine-checkable reason, and the relaxation menu answers "what must I change to ship this?" exactly.

## Refresh the facts

```bash
./demo/gen-facts.sh           # re-fetch pinned nixpkgs (default rev 1d060086d60c…) and regenerate demo/facts/nixpkgs.kif
NIXPKGS_REV=<sha> ./demo/gen-facts.sh
```

Scene 02 works offline forever because the facts are committed. The generator only runs when you ask it to.
