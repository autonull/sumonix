## The demo

`./demo/run` plays five scenes. Every scene runs the real engine; the committed
transcripts are normalized for readability. The scenario is a **labelled
fixture**, never a mock service: the facts say `sourceClass: fixture`, and the
demo reports that label. The nixpkgs facts are committed and pinned, so the
answers are reproducible and do not depend on a live registry.

| # | Scene | What it proves |
|---|-------|----------------|
| 01 | **The 30-second proof** | Derive → export a certificate → independently re-check → tamper is refused. |
| 02 | **Your package set, reasoned over** | Real nixpkgs facts: capability composition, transitive closure, synergies. |
| 03 | **Your organization, reasoned over** | 2,109 pages (666 process documents, zero unclassified), taxonomized under SUMO; identical copies and retired names, each with a proof. |
| 04 | **The crosswalk knows what it knows** | Typed questions over PyAI ↔ HF ↔ SUMO; answers are 0/1 plus an explicit null. |
| 05 | **The build fails — and here is why** | The gate, its proof, and the relaxation menu: "what do I actually have to change?" |

```bash
./demo/run                     # all five, in order
./demo/run 02-capabilities.sh  # just one
./demo/record                  # re-record every scene (needs asciinema)
```

Each scene is a standalone recording in `demo/casts/`
(`asciinema play demo/casts/<scene>.cast`); the transcripts are in
`demo/transcripts/`. Full scene notes are in [`demo/README.md`](demo/README.md).

| Scene | Cast | Transcript |
|-------|------|------------|
| 01 | `demo/casts/01-30-seconds.cast` | `demo/transcripts/01-proof.txt` |
| 02 | `demo/casts/02-capabilities.cast` | `demo/transcripts/02-capabilities.txt` |
| 03 | `demo/casts/03-pages.cast` | `demo/transcripts/03-pages.txt` |
| 04 | `demo/casts/04-crosswalk.cast` | `demo/transcripts/04-crosswalk.txt` |
| 05 | `demo/casts/05-when-the-build-breaks.cast` | `demo/transcripts/05-policy.txt` |

---

### Scene 1: The 30-second proof

The build fails; the engine knows why; the why is a file you can re-check, and
the checker shares no code with the engine:

<!-- include:transcript:01-proof.txt -->

The scene derives the CVE policy violation, exports the certificate, re-checks
it with `proof-check.nix`, and then alters the certified goal to prove the
checker refuses tampering. This is the trust anchor for every other scene.

### Scene 2: Your package set, reasoned over

Real nixpkgs facts (60 packages, committed, pinned, offline) answer questions a
README cannot: which capabilities compose, which your transitive closure
unlocks, and where 3+ capabilities combine:

<!-- include:transcript:02-capabilities.txt -->

The ontology is not decoration. It supplies the class hierarchy and the Horn
rules that turn a package's immediate dependencies into the capabilities it
enables, and then into the synergies that no single package declares.

### Scene 3: Your organization, reasoned over

The Pick Your AI repositories, pinned and taxonomized under SUMO: 2,109 pages,
666 of them process documents by *class reasoning*, zero unclassified,
identical copies and retired team names found by hash, every finding carrying
its proof:

<!-- include:transcript:03-pages.txt -->

The point is breadth: anything that can be stated as facts can be reasoned over,
not just packages. Documents, their kinds, their copies, and their stale names
all become facts with provenance.

### Scene 4: The crosswalk knows what it knows

Typed questions over PyAI fields ↔ HF tags ↔ SUMO classes. Answers are 0/1
*plus an explicit null* — when there is no rule, you get "I don't know", never
a silent no:

<!-- include:transcript:04-crosswalk.txt -->

The crosswalk is a rule set, not a model. Gaps are first-class answers, so a
missing mapping is visible instead of being mistaken for a negative conclusion.

### Scene 5: The build fails — and here is why

The gate, the proof it emits, and the relaxation menu answering the question
"what do I actually have to change?":

<!-- include:transcript:05-policy.txt -->

Each checkmark is a true single flip: if that fact or rule could be changed, the
build would pass. The relaxation menu is the honest answer to "what do I have
to change for this to ship?"

---

### The panel (TUI dashboard)

The same digest, rendered as a live TUI (`sumo dashboard`): services, the
capability atlas, the policy verdict with its proof, and a chart:

![sumo dashboard](docs/demo/dashboard.png)

### The movie

`./tools/tour.sh` records the whole walkthrough to `docs/demo/tour.cast`:

```console
$ ./tools/tour.sh
$ asciinema play docs/demo/tour.cast
```

It opens on **this machine**: `demo/host-facts.sh` reads running systemd units,
the kernel release, listening sockets, and the Nix store if the host has one,
and writes facts headed `source: live`. The session then continues with a
labelled fixture — an nginx service and a synthetic critical advisory — so the
policy verdict and its proof are reproducible: `sumo caps`,
`sumo closure nginx`, `sumo query '(vulnerable nginx CVE-2026-9999)'`,
`sumo whatif`, `sumo guard` (exit 1), an independent `proof-check` of the
emitted certificate, and the TUI dump from the same digest.

All artifacts are generated, not pasted: `./tools/tour.sh` (asciinema) and
`./tools/movie.sh` (cast → animated GIF; GitHub renders GIFs but strips player
embeds), plus `./tools/shot.sh` (TUI dump → PNG).

Record your own: `./demo/record` re-records every scene (needs `asciinema`).

### Refresh the facts

```bash
./demo/gen-facts.sh                       # re-fetch pinned nixpkgs and regenerate the facts
NIXPKGS_REV=<sha> ./demo/gen-facts.sh      # pin a different revision
```

Scene 2 works offline forever because the facts are committed. The generator
only runs when you ask it to.

### Live facts vs fixtures

`sumo status` prints where its facts came from:

```text
Facts:  live N (systemd, /proc, ss, nix-store when present)
        fixture M (scenario facts, capability atlas)
```

| Source | Label | What it is |
|--------|-------|------------|
| `demo/host-facts.sh` | `live` | Observed on the host at run time |
| `demo/facts/host.kif` | `fixture` | The deterministic nginx/CVE scenario |
| `demo/facts/nixpkgs.kif` | `fixture` | 60 pinned nixpkgs packages for the capability atlas |

A fixture fact is never printed as an observation. On a host without a Nix
store or without a CVE, the live pass reports zero packages and `PASS` — that
is the truth, not a gap to paper over. `--json` carries the same split as
`"sources":{"live":N,"fixture":M}`.
