## 🎬 The 60-second demo

`./demo/run` plays the same five scenes every time — no setup, no network, ~30 seconds. Each is a standalone recording in `demo/casts/` (`asciinema play demo/casts/<scene>.cast`). Nothing here is a mock: every line is the real engine answering a real question, and the output below is pasted verbatim from `./demo/run`.

```bash
./demo/run    # all five, in order
./demo/run 02-capabilities.sh   # just one
```

**1 · The 30-second proof** — the build fails; the engine knows why; the why is a file you can re-check, and the checker shares no code with the engine:

<!-- include:transcript:01-proof.txt -->

**2 · Your package set, reasoned over** — real nixpkgs facts (60 packages, committed, pinned, offline) answer questions a README cannot: which capabilities compose, which your transitive closure unlocks, and where 3+ capabilities combine:

<!-- include:transcript:02-capabilities.txt -->

**3 · Your organization, reasoned over** — the Pick Your AI repositories, pinned and taxonomized under SUMO: 2,109 pages, 666 of them process documents by *class reasoning*, zero unclassified, identical copies and retired team names found by hash, every finding carrying its proof:

<!-- include:transcript:03-pages.txt -->

**4 · The crosswalk knows what it knows** — typed questions over PyAI fields ↔ HF tags ↔ SUMO classes. Answers are 0/1 *plus an explicit null* — when there is no rule, you get "I don't know", never a silent no:

<!-- include:transcript:04-crosswalk.txt -->

**5 · The build fails — and here is why** — the gate, the proof it emits, and the relaxation menu answering the question "what do I actually have to change?":

<!-- include:transcript:05-policy.txt -->

Record your own: `./demo/record` re-records every scene (needs `asciinema`). Full script and cast index: `demo/README.md`.

**6 · The panel** — the same digest, rendered as a live TUI (`sumo dashboard`): services, capability atlas, the policy verdict with its proof, and a chart:

![sumo dashboard](docs/demo/dashboard.png)

**7 · The session, recorded** — `sumo status`, `sumo caps`, `sumo closure nginx`, `sumo query`, `sumo whatif`, captured as an asciicast:

```console
$ asciinema play docs/demo/tour.cast
```

Both artifacts are generated, not pasted: `./tools/shot.sh` (TUI dump → PNG) and `./tools/tour.sh` (asciinema).
