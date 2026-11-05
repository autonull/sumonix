# TODO.3 — The Real 60-Second Demo: a logged-in NixOS session and a real sumonix TUI dashboard

**Status:** in progress. **Predecessors:** TODO2.b (V3 + 7 T-milestones), `demo/` package, `run-tests.sh`. **Non-negotiables:** `./run-tests.sh` green at every step; the VM boots unattended and exits non-zero on failure; the demo is explorable *interactively*, not only a scripted tape; never anything that can hang a real login; README regeneration is byte-identical to what we ship.

**Rev 2 — what changed and why** (each line saves time or buys surface):

| Change | Why |
|---|---|
| **Dashboard is a real TUI** (tcell + tui-go), not HTML+nginx+meta-refresh | A browser panel inside the VM needs port-forwarding, a headless-browser capture, and nginx; for the same effort a TUI gives mouse, layouts, charts, and a *capturable* screenshot via `vt10x` — one artifact, byte-stable, no runtime deps |
| **The dashboard is the same digest renderer as the CLI** | `sumo status` and `sumo dashboard` read one eval; nothing can disagree. Saves a whole `dashboard.nix` |
| **The VM builds the repo, the host builds the packages** | The repo tree is copied into the guest **with the host's `.nix-store`**, so the warm closures resolve and evals cost ~1 s (measured), not a 2× 286-rule recompute with no binary cache |
| **VM by default is a plain NixOS VM** (one repack) | No cache services, no extra nixpkgs instantiation. The image is an `ext4` store export, built once; `make-disk-image.nix` only if `--fast` is dropped |
| **What-if stops enumerating the space** | It answers *one* counterfactual from the goal's own proof: *"which leaf flips the verdict?"* — two engine runs, always well under a second. The relaxation *menu* stays what it is (five candidate facts, run only for the policy scene) |
| **`--help` and topology are layout nodes, not a `help` command** | The dashboard still shows every skeleton screen; the CLI's top bar lists subcommands, no separate tree to drift |
| **B reads the curated transcripts** (`demo/transcripts/*.txt`), not scene output | The five README scenes *curate* (the first line is a `│ Step` the scene does not print). Capturing raw scene output would make B1 fail byte-identity. This is the one decision that de-risks Workstream B |
| **Refactor list is exact (see §6)** | `isVar` is *not* uniform: engine `?` only; reasoner `?` or `@`; stratify also skips `@`. Copying one into the other would silently change behaviour |
| **TTY path is closed; no shell wrapper** | A `sumo` shell script that closed the terminal, rand the `go` binary, and got the TTY back is unnecessary once facts and rules are in `cwd`. The TUI is ~40 lines of Go; the `go` binary is build-time only |
| **The `--vm` test lives in `tests/vm/`** | Keeps `run-tests.sh` a list of `nix eval` tests with one gate, and needs no KVM unless asked |

---

## 0. Why this milestone exists

`./demo/run` proves the engine works, but it is a **slideshow**, not a **world**. What is missing is a **logged-in user, at a real machine that sumonix reasons about, reaching for sumonix to answer questions about that machine** — installed packages, running services, what capabilities are present, why the policy verdict came out the way it did, what changes if one fact is different — and the payoff: **a real terminal dashboard, for the same session, showing the machine's live knowledge graph** instead of scrollback. That is the 60-second story that makes someone want this on their real hardware.

Two things block it today:

1. **No live, interactive entry point** — no `sumo` command, no machine that boots into a sumonix session, no way to *poke at the machine* and watch the engine answer.
2. **No face** — the engine speaks scrollback; a real deployment wants a panel. The dashboard is what turns "cool reasoner" into "I want this on my server."

Building it honestly forces a small, safe refactor: the engine's shared helpers are copy-pasted across ~10 files; extracting them is the cheapest code-quality win available, and it should happen on the way, not after.

---

## 1. The demo, as a user experiences it

A NixOS VM boots (2 vCPU / 2 GB, serial console). The `demo` account autologs in. The machine has real software — `nginx`, `openssl`, `python3`, `redis`, `postgresql` and their closures — as facts in a knowledge base. A MOTD shows:

```
╔════════════════════════════════════════════════════════════╗
║  sumonix reasons about this machine.                       ║
║  Try:  sumo status   sumo caps   sumo closure openssl      ║
║        sumo query '(vulnerable nginx CVE-2026-9999)'       ║
║        sumo whatif   sumo dashboard                        ║
╚════════════════════════════════════════════════════════════╝
```

The session then wanders, non-linearly, like a real demo:

1. `sumo status` — services, packages, capabilities, rounds, derived facts; the policy verdict and where its proof lives.
2. `sumo caps` — the capability atlas of the installed set ("what can this box do?").
3. `sumo closure openssl` — dependency tree; then `--json`; then a query piped through it.
4. `sumo query '(vulnerable nginx CVE-2026-9999)'` — the why subtree, printed.
5. `sumo whatif` — take one leaf of the goal's own proof, drop it, re-run the gate, watch the verdict flip; then offer the full relaxation menu on request.
6. `sumo dashboard` — the TUI, in the same terminal: panes of services, capability atlas, counts, the policy proof, and a chart; mouse works; panes resize. **This is the scene the recording lands on** — and the scene the screenshot freezes.

The session is fully explorable: any command, any order, `--help` on the bare invocation and in the dashboard's header. It is a world, not a tape.

## 2. Non-goals (explicitly deferred)

- No new reasoning capability: no T-milestones, no Soufflé, no parallel eval. Everything is built from what the engine already does.
- No browser dashboard, no HTTP server, no JS, no port forwarding. The dashboard is TUI only; its screenshot is produced by replaying the TUI's own output stream, not by a browser. `demo/vm` needs `python3 + websocket-client` and Go on the **host** for the replay and the build (both present; nothing new at runtime).
- No auth, no TLS, no persistence beyond `/run/sumo`; no multi-tenant anything.
- No network at runtime; the recording is offline.
- No Windows/macOS host. Serial-console Linux VM only; SSH is convenience, never required (and is not in the recording).
- No PAM work; the login path is a plain NixOS account.
- Nothing escapes `/run/sumo` (facts, cache, derived goal rules, digest) inside the VM.

---

## 3. Current state (verified 2026-11-05)

| Thing | Where | State |
|---|---|---|
| 5-scene offline demo (proof, packages, pages, crosswalk, gate) | `demo/`, `./demo/run` | ships; casts committed; the README's five `console` fences are hand-pasted and curate more than the scenes print — B1 moves them byte-for-byte to `demo/transcripts/*.txt` (new files) |
| Pinned nixpkgs facts (60 packages, committed) | `demo/facts/nixpkgs.kif` | offline, deterministic |
| Capability atlas / spike | `spike/nixpkgs-snapshot.nix`, `spike/run-spike.nix`, `spike/demo.sh` | works; snapshot needs `<nixpkgs>` (VMs only) |
| NixOS VM spike | `spike/vm.nix` | boots headless, `nix eval` at boot, serial console; a *service*, no session, no interactivity |
| Host layout | this machine | no `/nix/store`; local store is `.nix-store/`; the policy digest is **warm ~1.4 s / ~1 s** (measured twice); a 989-rule eval is 0.33 s; `chromium --headless --screenshot` works |
| Engine blank-run guard | `datalog.nix:123-125` | `fix` stops when a round derives nothing (already a de-facto strata cut); **no-op facts are still appended** |
| Duplicated helpers | `datalog.nix`, `reasoner/{stratify,ingest,wfs,existential,temporal,congruence,synthesize}.nix`, `policy/{relax,soft-rules}.nix` | copy-pasted with **divergences**: engine `isVar` is `?` only; the reasoner's is `?` or `@`; `stratify.nix`'s also skips `@` members; `unique` has four bodies (two keep non-strings). `proof-check.nix` is deliberately standalone |
| Tests | `./run-tests.sh` | 21 tests; `nix-eval.sh` + `demo/lib.sh` + `spike/demo.sh` each export the store vars; `./demo/run` is 6–8 s warm |

---

## 4. Workstream A — The logged-in VM + the sumonix TUI dashboard (the centerpiece)

### 4.1 What ships, in order of visible payoff

```
A1  bin/sumo — the command the user reaches for            (foundation)
A2  machine facts — the VM's own world, as facts           (foundation)
A3  the VM — boots, autologin, MOTD, sshd for humans        (foundation)
A4  scripted tour — deterministic, recordable walkthrough  (visible demo)
A5  sumo dashboard v1 — real TUI: layout, mouse, pane help  (the scene)
A6  sumo dashboard v2 — charts, live activity, what-if card (the product taste)
A7  recordings — tour.cast + dashboard.png (from vt10x)     (the artifact)
A8  polish — `--check`, `--json` everywhere, docs            (finish)
```

### 4.2 Components and the missing functionality to build

**A1. `sumo` command** — `bin/sumo`, pure bash + `nix eval` (the two stores from `tools/env.sh`), on PATH in the VM. All evaluation flows through `bin/_sumo.nix`, a read-only dispatcher that returns the digest as an attrset (local API sketch: `s cmd [status]`, `s topology`, `s proof [goal]`). The only module that is evaluation-rich is the policy digest; `vim` exists in the guest, so the CLI has **no edit**.

| Subcommand | What it does | Reads |
|---|---|---|
| `sumo status [--json]` | Machine overview: services, package/derived counts, rounds; verdict + proof file; `--json` for scripts | digest (`_sumo.nix status`), memoized |
| `sumo caps` | Capability atlas of the installed closure (via `spike/run-spike.nix` with the snapshot as data) | `demo/facts/nixpkgs.kif` |
| `sumo closure <pkg>` [`--json`] | Dependency tree (indented); `--json` for scripts | vault facts |
| `sumo query <goal>` | Ground goal → verdict + why subtree | vault rules |
| `sumo whatif` | **One** counterfactual from the proof: two warm runs, exit 1 when a flip | proof leaves, policy digest |
| `sumo dashboard` | Builds and runs the Go TUI over the digest (no TTY needed for `--dump`) | digest (`--json`) |
| `sumo version`; `sumo` / `sumo --help` | Self-explanatory; the subcommand list comes from `_sumo.nix` | — |

Facts: `SUMO_FACTS` or `/run/sumo/facts.kif` (or `demo/vm/facts.kif` in-repo). Rules: `SUMO_RULES` then `<worktree>/rules.kif`, or the generated `demo/vm/rules.kif` in the VM. Every sub-command after the first evals in ~0.3–1.4 s warm; **each sub-command has a 15 s guard** (no hang).

**A2. Machine facts** — the machine's own world, as facts.
- **Curated mode (default, committed `demo/vm/host-facts.kif`):** kernel `runningKernel 6.6`, `hasLoaded nginx`, `listensOn nginx 80`, `runningAs nginx nginx`, the five "installed" packages plus their closure mirrors of the demo facts; nginx is a `NIXService` with `serviceState running`; one advisory (`vulnerable openssl CVE-2026-9999` + `severity critical`) so the policy verdict is non-trivial. 30 lines; regenerated deterministically.
- **Live mode (`--live`):** an exporter writes what the kernel and systemd say at boot: `readsFile /etc/nginx/nginx.conf`, modprobe depends, `ExecStart` deps. It **adds** facts; the graph argument (and so the proof) is unchanged.
- `/run/sumo/{facts,universe,rules}.kif` are written by `sumo-facts.service` (oneshot, before `getty`).
- **The universe is asserted by the facts, not quoted from SUMO:** `(instance nginx NIXService)` expands through the ontology to `instance nginx Process`; the *proof file* contains only asserted + derived NIX facts, so it stays small enough to read. (Matching the existing `proof.kif` culture.)

**A3. The VM** — `demo/vm/vm.nix` (+ `demo/vm/build.sh`), extending the spike, not a new architecture:
- NixOS, `boot.loader.grub.enable = false`, tmpfs root, direct kernel boot, `console=ttyS0`, 2 cores / 2048 MB; build with `system.build.vm` (one repack).
- **Repo in guest:** `builtins.path` of the worktree (VCS, `.nix-store`, `result` dropped), **copied with the host's `.nix-store`** (the 6–8 s demo's closures). On boot, `nix-store --export` of the store directory, one file.
- `users.users.demo = { isNormalUser = true; password = "demo"; extraGroups = [ "wheel" ]; }` (documented throwaway); `services.getty.autologinUser = "demo"`.
- `services.openssh.enable = true`; no forced command — login behaves like any NixOS box.
- MOTD in `/etc/profile.d/sumo-motd.sh`: the panel, plus `export SUMO_FACTS=/run/sumo/facts.kif`.
- Guests get `nix`, `bash`, `coreutils`, `asciinema` (for A7); **`nerdctl`/Docker is deliberately out** (a container runtime would add evaluation cost for no story).
- `./demo/vm.sh` — `build` / `boot` / `--record` / `--check` / `--teardown`; an exit trap kills the `qemu`; hard `timeout 300`. `make-disk-image.nix` only if `--fast` (persistent `/nix/store`) is dropped.

**A4. Scripted tour** — `demo/vm/session.sh`: a deterministic command sequence on the autologin console, byte-stable (`TZ=UTC LANG=C`, timestamps stripped, the MOTD and the prompt normalized). Broadcast as an *input* (keystrokes) to the console; interactive use is unaffected.

**A5. `sumo dashboard` v1 — a real TUI.**
- **Renderer:** `demo/vm/tui/` (Go): `tcell` (terminfo/mouse) + `tui-go` (layout, borders, widgets). Build-time only; the binary lives in the guest at `/run/sumo/bin/sumo-tui`. No runtime deps.
- **Layout:** a header (host `nginx`, package/capability/rule counts, verdict badge), a left "services / installed" pane, a right "policy" pane (the verdict and a scrollable proof with per-node collapse — `Tab`/arrows, mouse), a bottom "activity" line (last rounds, from `trace`). No new data: **every widget renders the digest the CLI prints**. Counts come from the digest, never hardcoded (`286 rules` is the demo's number, not the VM's).
- **Inputs:** `h`/`?` shows `_sumo.nix topology` (a layout tree of every screen — the help screen is a node, so it cannot drift); `q` quits.
- **`--dump`:** render the same TUI to stdout with no TTY (the digest test and the screenshot share this path).
- `sumo dashboard` regen (if any) and runs the binary; `sumo` (or `sumo dashboard`) exits cleanly with `q`.

**A6. v2 — feels alive.**
- **Charts:** a capability bar chart (a 12-row sparkline over the atlas), a round-count sparkline from `trace`. Same `tui-go` widgets; no chart library.
- **Live activity:** refresh each 5 s by re-running the memoized digest (warm ~1 s — measured); **rounds recounted only when the fact file's hash changes**; the "activity" strip scrolls the last derivations.
- **What-if card:** the two warm runs from A1, run once on a key, never on a timer.
- **No second watch mode** (`watch -n1 cat` would lie about the engine); the dashboard *is* the watch.

**A7. Recordings**
- `docs/demo/tour.cast` — `asciinema` inside the guest, autologin console (byte-stable).
- `docs/demo/dashboard.png` — replay the TUI's real output stream (`--dump` once per key, captured) through `vt10x` on the host: a PNG of what the guest actually rendered, no Xvfb, no browser. One artifact, generated by a committed script (`tools/shot.sh`).
- README embeds both (after B).

**A8. Polish** — `sumo dashboard` prints nothing but the UI; `--json` on `status`, `closure`, `query`; teardown clean; `--check` runs the eval gate and prints KVM availability; docs updated.

### 4.3 Tasks

| # | Task | Files | Acceptance |
|---|---|---|---|
| A1 | `sumo` CLI (all subcommands) | `bin/sumo`, `bin/_sumo.nix` | each runs in-repo; `sumo query '(vulnerable nginx CVE-2026-9999)'` prints the proof subtree; `sumo` lists the subcommands; `--json` valid on `status`/`closure` |
| A2 | machine facts | `demo/vm/host-facts.kif`, `--live` exporter | regenerate deterministically; nginx service + running state + one advisory; `--live` only adds |
| A3 | VM + `demo/vm.sh` | `demo/vm/vm.nix`, `demo/vm/build.sh`, `demo/vm.sh` | boots headless; `demo` autologs; MOTD; ssh alternatives; `sumo` on PATH; exit trap + `timeout 300`; cold build once (`system.build.vm`), no `make-disk-image` |
| A4 | scripted tour | `demo/vm/session.sh` | identical output across two runs (normalized) |
| A5 | TUI v1 | `demo/vm/tui/`, `demo/vm/sumo-tui.nix` | `go test` pins one digest → one rendered (snapshotted) header/panes; renders in a real terminal; `q` quits |
| A6 | TUI v2 | same | charts drawn from the same data; refresh ≤5 s; what-if card flips; digest test green |
| A7 | recordings | `docs/demo/tour.cast`, `docs/demo/dashboard.png`, `tools/shot.sh` | committed; screenshot is the real TUI stream (no browser) |
| A8 | `--check` + docs | `demo/vm.sh`, `run-tests.sh` | KVM gate exits 0 with KVM, prints a clear SKIP otherwise, in `tests/vm/` (outside `run-tests.sh` unless `--vm`) |

### 4.4 Why this is the demo

- **Interactive**, not a tape: the user wanders off-script and the machine answers.
- **Honest**: every number on the TUI traces to an eval of the real engine; the same digest feeds the CLI and the panes; nothing is mocked.
- **Compelling**: the terminal builds appetite; the TUI delivers it; the proof keeps it.
- **Extensible**: the feature set is the data model; layout, colors, and charts change, the lines do not.

---

## 5. Workstream B — README from parts (from the curated transcripts)

### 5.1 Layout

```
docs/readme/           # prose, one file per section, emitted in lexicographic order
  00-head.md 10-demo.md 20-what-this-is.md ...   # every current hand-written section
demo/transcripts/      # the *curated* README scenes (existing content, moved verbatim)
  01-proof.txt 02-capabilities.txt ... 05-policy.txt
docs/demo/             # generated casts + screenshots (from ./demo/run, ./demo/vm.sh)
tools/gen-demo.sh      # records each scene with asciinema (txt-only + warning without it)
tools/build-readme.sh  # concatenates docs/readme/*.md; expands <!-- include:transcript:... -->
tools/check-readme.sh  # re-renders to a temp file, diffs README.md, non-zero on drift
README.md              # generated; header says "DO NOT EDIT — run ./tools/build-readme.sh"
```

### 5.2 Marker rules (kept minimal)

- `<!-- include:transcript:02-capabilities.txt -->` → the contents of `demo/transcripts/02-capabilities.txt` in a `console` fence.
- Everything else is literal prose. The generator is ~30 lines of shell + `awk`; no external deps.

**Why the curated transcripts, not `./demo/run` output:** the README's first scene opens with `│ Step 2 …` — a *narration* line the scene does not print. Raw capture would make B1's "byte-identical after one run" fail. B1 then means: the current README, with its five fences replaced by the transcript files, is byte-identical. The drift risk stays covered: the `include` is generated, the file changes only when the *scene* changes.

### 5.3 Migration checklist

| # | Task | Acceptance |
|---|---|---|
| B1 | Split current README into `docs/readme/*.md`; move the five `console` fences byte-for-byte to the new `demo/transcripts/*.txt` | byte-identical output after one `./tools/build-readme.sh` run |
| B2 | `10-demo.md` uses `include:transcript:` for the five demos | README section renders identically; the transcripts are the only source |
| B3 | Add `tour` and `dashboard` transcripts once A7 lands (the later ones can be raw: they add, not edit) | generated, not pasted |
| B4 | Header comment in generated README: `<!-- generated by tools/build-readme.sh; do not edit -->` | present |
| B5 | `./tools/check-readme.sh` exits 0 | added to `run-tests.sh` |
| B6 | `tools/gen-demo.sh` re-records everything (`asciinema` required; degrades to txt-only with a warning) | casts change only when output changes |
| B7 | Delete `docs/demo/*.txt` after migration (keep `.md`) | no stale duplicates |

### 5.4 Why this matters

Every future transcript edit becomes a `git diff` of a generated file, not a hand-edited block; README can never silently disagree with the code; `check-readme.sh` in the test runner makes drift a failing test.

---

## 6. Workstream C — Low-hanging refactor (do this first)

**Order rule:** extract in order of risk, verify `./run-tests.sh` after each extraction, require a byte-identical `./demo/run` transcript. **Do not touch `proof-check.nix`.**

### C1. Shared Nix helper library — `lib/kif.nix`

Extract, do not change semantics. Exported: `show`, `headOf`, `flatten`, `subforms`, `isVar` (the reasoner's: `?` or `@`), `isEngineVar` (`?` only), `ground`, `subst`, `varsOf`, `unique` (hash-name dedupe), `isKifOp`. **Type-aware `show`** (`isString → s`, `isInt → toString s`, else the list) so one `show` serves `relax.nix` / `soft-rules.nix` and future predicates (`gzip-1.13` would have rendered as `gzip` with the string-only body: that is allowed only as an unused variant).

Sites and expected deletion (~150 lines net; ~60 lines added in `lib/kif.nix`, ~210 deleted):

| Site | Now | After |
|---|---|---|
| `datalog.nix:14-33, 87-92` | own `isVar` (`?`), `show`, `headOf`, `ground`, `subst`, local `flatten`, `unique` | `isEngineVar`, `show`, `headOf`, `ground`, `subst`, `unique` |
| `reasoner/stratify.nix:24-27` | `?`/`@`, plus members starting `@` are *not* vars | **keep both** local (its `isVar` is this, its membership skip is not extractable) |
| `reasoner/ingest.nix:38-44` | `?`/`@` | `headOf`, `show`, `flatten`, `isVar`, `unique` |
| `reasoner/{wfs,existential,temporal}.nix` | `?`/`@`, four-body `unique` | `show`, `headOf`, `unique`, `flatten`, `isVar` |
| `reasoner/congruence.nix` | the type-aware `unique` (`attrValues`) | `show`, `headOf`, `flatten`, `isVar`; **its `unique` stays** (documented divergence) |
| `reasoner/synthesize.nix` | `?`/`@`, `unique` via `count` | `headOf`, `show`, `unique` |
| `policy/relax.nix:16`, `policy/soft-rules.nix:8` | the same `show` | `show` |

`datalog.nix` returns one small new field: `ask` dedupes the bindings it prints (`{ ?pkg }` twice if a package has two capability reasons) — no derived set changes.

### C2. Test boilerplate — `tests/lib.nix`

`check = what: ok: …`. One unit test (say `relax`) converted; the rest move only if it is a strict shrink, one per commit.

### C3. Shell environment — `tools/env.sh`

`nix-eval.sh`, `run-tests.sh`, `demo/lib.sh`, `spike/demo.sh` source one file; `nix-eval.sh` becomes a 6-line wrapper.

### C4. `bin/sumo` uses `tools/env.sh`

Once C3 exists, `bin/sumo` is the fourth consumer.

### C5. Verification of C

```bash
./run-tests.sh                 # 21+ tests green
./demo/run > /tmp/after.txt
diff /tmp/before.txt /tmp/after.txt   # MUST be empty
git diff --stat                # expect ~−150 lines in the extraction commit
```

If the diff is non-empty, stop and revert the extraction — do not patch forward.

---

## 7. Workstream D — Tools directory coherence (small, do last)

- `tools/` holds `env.sh`, `gen-demo.sh`, `build-readme.sh`, `check-readme.sh`, `shot.sh`.
- Root keeps only user-facing entry points: `nix-eval.sh`, `run-tests.sh`, `demo/run`, `bin/sumo`.
- `spike/` stays as exploration; anything reused by the VM moves to `demo/vm/` or `lib/`, spike imports it.

---

## 8. Milestones, order, and effort

| Order | Milestone | Effort | Gate | Status |
|---|---|---|---|---|
| 1 | C1 (one module at a time) + C3 | 1–2 h | suite green after each; demo diff empty | ✅ |
| 2 | C2, C4 | 30 min | suite green | ✅ (C2 done, C4 deferred to A1) |
| 3 | A1 (`sumo` CLI) + A2 (facts, curated mode) | 1–1.5 h | every subcommand runs in-repo | ✅ |
| 4 | A3 (VM + `demo/vm.sh`) + A4 (tour) | 2–3 h | boots; autologin; MOTD; `sumo` on PATH | 🟡 **Config complete; build blocked by env (no writable /nix/store + no binary substitutes in local store)** |
| 5 | A5 (TUI v1) | 1–1.5 h | real terminal; mouse; `q`; digest test | ✅ dump mode works |
| 6 | A6 (TUI v2) | 45–60 min | charts; 5 s refresh; what-if card | ✅ implemented (sparkline, auto-refresh, what-if card) |
| 7 | A7 (record + screenshot) | 30 min | casts + png committed | ⏳ needs VM (blocked by env) |
| 8 | B1–B7 (README from parts) | 1.5–2 h | `check-readme.sh` green | ✅ |
| 9 | D | 20 min | links updated | ✅ |

Total ≈ **7.5–10 h**. (Rev 1 was 8–11 h: the TUI replaces the browser panel, the transcript source makes B1 risk-free, the VM does not spend its boot building two policy closures, and what-if is two runs, not a menu of one.)

## 9. Risks and mitigations

| Risk | L | Impact | Mitigation |
|---|---|---|---|
| TUI scope creep (turns into a product) | med | schedule | §2; v1 = layout + panes + help; v2 = charts + activity; **no** HTTP, browser, auth, JS |
| `noop` facts grow forever | med | wrong verdicts | **optional** accumulator cut in `datalog.nix`: a new fact that touches no rule head is not appended (a semantics change → only with a green suite and a demo diff; not a silent extra) |
| Refactor breaks subtle semantics (`isVar`/`unique`/`show`) | med | silent wrong proofs | §6 divergence table; extract one helper at a time; byte-identical demo diff required; suite after every commit |
| VM build too heavy | med | demo unusable | one repack; host store exported into the guest; `--check` skippable; exit trap; `timeout 300` |
| Warm policy eval slower than expected | med | paced demo | measured ~1–1.4 s; memoize the digest; `whatif` = two runs, exit 1 on a flip; **two-run budget as a test** (`time` a cold `status` < 3 s) |
| README drift returns | high | doc rots | generated files + header + `check-readme.sh` in the suite |
| Demo session not byte-stable | med | README churn | scripted stdin, stripped timestamps, fixed locale, normalized MOTD/prompt |
| "login" misunderstood again | — | wasted hour | §1 and §4 are explicit: it is a *session*, a *world*, a *panel* — not an auth handshake |
| **Writing to /nix/store** | **high** | **breaks in CI/no-KVM env** | **ALL work stays in repo (./bin, ./demo, ./lib, ./tools). VM build is the ONLY thing that touches /nix/store — gate it behind --check that SKIPs when KVM/store unavailable. Never run nix build in main flow.** |
| **VM build needs bootstrap binaries / binary cache** | **high** | **build fails in clean env** | **VM config is complete and correct. Building requires: (1) writable /nix/store OR local store populated with substitutes from cache.nixos.org, (2) stage0-posix bootstrap binaries. Document as env requirement; `--check` validates KVM + store + cache access.** |

## 10. Definition of done

- [ ] `./demo/vm.sh` boots; `demo` autologs into a working machine; MOTD shows; `sumo` works for every subcommand.
- [ ] `sumo dashboard` renders the TUI in the terminal: services, capabilities, policy verdict + proof, a chart; `q` quits; `h` shows the topology.
- [ ] `docs/demo/tour.cast` and `docs/demo/dashboard.png` committed; the png is the TUI's own rendering.
- [x] `README.md` is generated; `./tools/check-readme.sh` passes and is in `./run-tests.sh`.
- [x] `lib/kif.nix` exists; `proof-check.nix` untouched; suite green; `./demo/run` output byte-identical.
- [x] `./run-tests.sh` passes; the two-run `status` budget holds; `./demo/vm.sh --check` passes on KVM, SKIPs elsewhere.
- [x] `TODO.3.md` updated to track completion.
- [x] `bin/sumo` CLI with all subcommands (status, caps, closure, query, whatif, dashboard, version, --help)
- [x] `bin/_sumo.nix` dispatcher with JSON output for all subcommands
- [x] `demo/vm/host-facts.kif` curated machine facts
- [x] `demo/vm/tui/` Go TUI with `--dump` mode for screenshot capture, sparkline charts, 5s auto-refresh, what-if card (press 'w')
- [x] `demo/vm/vm.nix` NixOS VM configuration
- [x] `demo/vm.sh` VM management script
- [x] `demo/vm/session.sh` scripted tour
- [x] `tools/` coherence: `env.sh`, `gen-demo.sh`, `build-readme.sh`, `check-readme.sh`, `shot.sh`; root entry points source `tools/env.sh`

## 11. Open questions (with recommendations)

1. **TUI stack** — recommend `tcell` (terminfo, mouse) + `tui-go` (layout, borders, widgets, one dep). Not `tview` (no layout) and not `bubbletea/lipgloss` (grid is DIY). Go is build-time only; the `go` binary lives in the guest.
2. **Dashboard vs CLI** — the same digest: `sumo --json` is the TUI's input. Recommend holding to that; adding TUI-only data is the creep.
3. **Baked vs live facts** — baked for the recording (deterministic); `--live` **adds** facts, never contradicts them, so the proof stays the same.
4. **Where does `sumo` live?** — `bin/sumo`, consistent with `bin/sumo-nix`.
5. **One VM or two recordings?** — one; `tour.cast` (terminal) and `dashboard.png` (TUI replay) from it.
6. **`noop` cut** — recommend: only if the suite still goes green and the demo diff is empty; else not at all, and say so in the docs.

## 12. Sequencing summary

Refactor first (C) → VM + `sumo` CLI (A1–A4) → TUI (A5–A6) → record (A7) → README from parts (B) → tools (D). Each step ends with the suite green and the demo transcript byte-identical, except A5–A8 which intentionally add surface.
