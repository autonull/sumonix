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

**7 · The movie** — `./tools/tour.sh` records the whole walkthrough to `docs/demo/tour.cast`:

```console
$ ./tools/tour.sh
$ asciinema play docs/demo/tour.cast
```

It opens on **this machine**, not on a script: `demo/host-facts.sh` reads running
systemd units, the kernel release, listening sockets, and the Nix store if the
host has one, and writes facts headed `source: live`. `sumo status` then shows the
count it actually observed.

The session continues with a **labelled fixture** — an nginx service and a
synthetic critical advisory — so the policy verdict and its proof are
reproducible: `sumo caps`, `sumo closure nginx`, `sumo query '(vulnerable nginx
CVE-2026-9999)'`, `sumo whatif`, `sumo guard` (exit 1: the gate refuses the
build), an independent `proof-check` of the emitted certificate, and finally the
TUI dump from the same digest.

Both artifacts are generated, not pasted: `./tools/tour.sh` (asciinema),
`./tools/movie.sh` (cast → animated GIF, since GitHub renders GIFs but strips
player embeds), and `./tools/shot.sh` (TUI dump → PNG).

### Live facts versus fixtures

`sumo status` prints where its facts came from:

```
Facts:  live 21 (systemd, /proc, ss, nix-store when present)
        fixture 18 (scenario facts, capability atlas)
```

| Source | Label | What it is |
|---|---|---|
| `demo/host-facts.sh` | `live` | observed on the host at run time |
| `demo/facts/host.kif` | `fixture` | the deterministic nginx/CVE scenario |
| `demo/facts/nixpkgs.kif` | `fixture` | 60 pinned nixpkgs packages for the capability atlas |

A fixture fact is never printed as an observation. On a host without a Nix store
or without a CVE, the live pass reports zero packages and `PASS` — that is the
truth, not a gap to paper over. `--json` carries the same split as
`"sources":{"live":N,"fixture":M}`.

### One current limitation

The engine runs under `nix eval`, so every subcommand costs roughly a second of
evaluation. The demo stays inside the two-run budget; `sumo dashboard` refreshes
on a timer rather than on keystroke.

### The live loop, in a container (D1)

`./tools/metavisor-tour.sh` drives the three metavisor scenes against a real
NixOS-in-Podman systemd host — no fixtures, no mocks:

1. **The gate** — a NixOS module with a wildcard postgres listener and a closed
   firewall fails `sumo gate` with a proof naming both option paths.
2. **Live drift** — the declared unit is stopped; one timer tick later
   `sumo status` and the journal carry the drift with its proof. A listener
   nobody declared is a violation, not a guess.
3. **Verified repair** — `sumo repair` ranks single-option patches, each
   re-lifted and re-gated; the top patch is applied and the whole system
   rebuilds through the same gate.

The transcript is normalized (timestamps, snapshot ids, hashes) and
byte-compared in CI, so a changed claim fails the build:

<!-- include:transcript:06-metavisor-live.txt -->

Record the cast with `./tools/metavisor-tour.sh --record` →
`docs/demo/metavisor-tour.cast`. The container harness is
`./container/run.sh build|run`, and its NixOS configuration is
`container/container.nix`.
