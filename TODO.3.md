# TODO.3 — The Real 60-Second Demo: a logged-in NixOS session and a sumonix dashboard

**Status:** planned, not started. **Predecessors:** TODO2.b (V3 + 7 T-milestones), `demo/` package, `run-tests.sh`. **Non-negotiables:** `./run-tests.sh` green at every step; the VM must boot unattended and exit non-zero on failure; the demo must be explorable *interactively*, not only as a scripted transcript; never anything that can hang a real login; README regeneration must be byte-identical to what we ship.

---

## 0. Why this milestone exists

The current demo (`./demo/run`) proves the engine works, but it is a *slideshow*, not a *product*. What is missing is the moment a **logged-in user, sitting at a real machine that sumonix reasons about, reaches for sumonix to answer questions about that machine** — installed packages, running services, what capabilities are present, why the policy verdict came out the way it did, what changes if one fact is different — and the payoff: **a dashboard UI, running inside the VM, showing the machine's live knowledge graph** instead of terminal scrollback. That is the 60-second story that makes people want this on their real hardware.

Two things block it today:

1. **No live, interactive entry point on a real system** — no `sumo` command, no machine that boots into a sumonix session, no way to *poke at the machine* and see the engine answer.
2. **No face** — the engine speaks terminal; a real deployment wants a panel. The dashboard inside the VM is what turns "cool reasoner" into "I want this on my server."

A side effect of building this honestly is forced refactoring: the engine's shared helpers are copy-pasted across ~12 files; extracting them is the cheapest large code-quality win available, and it should happen on the way, not after.

---

## 1. The demo, as a user experiences it

A NixOS VM boots (2 vCPU / 2 GB, serial console). The `demo` account autologs in. The user is given a working machine with real software — `nginx`, `openssl`, `python3`, `redis`, `postgresql` and their closures — all as facts in a knowledge base. A MOTD shows:

```
╔════════════════════════════════════════════════════════════╗
║  sumonix reasons about this machine.                       ║
║  Try:  sumo status   sumo caps   sumo closure openssl      ║
║        sumo query '(vulnerable nginx CVE-2026-9999)'       ║
║        sumo whatif    sumo dashboard                       ║
╚════════════════════════════════════════════════════════════╝
```

The recording then wanders, non-linearly like a real demo:

1. `sumo status` — machine overview: services, packages, capabilities, policy verdict + proof path.
2. `sumo caps` — the capability atlas of the installed set ("what can this box do?").
3. `sumo closure openssl` — dependency tree; then `--json`; then a piped query.
4. `sumo query '(vulnerable nginx CVE-2026-9999)'` — the why subtree, printed.
5. `sumo whatif` — drop one fact (the advisory), re-run the gate, watch the verdict flip; the interactive version of the relaxation menu.
6. `sumo dashboard` — opens the UI in a browser via port-forwarded 8080 (or prints the URL); the panel shows services, capability atlas, counts of facts/rules/derived knowledge, the policy verdict with a link to the proof, and refreshes itself. **This is the scene the recording lands on.**

The session is also fully explorable interactively — any command, any order, `--help` everywhere — because that is the point: it is not a tape, it is a world.

## 2. Non-goals (explicitly deferred)

- No new reasoning capability (no T-milestones, no Soufflé, no parallel eval). The whole session is built with what the engine already does.
- No production hardening of the dashboard: no auth, no TLS, no persistence beyond `/run/sumo`, no multi-tenant anything. It is a demo surface, honestly labeled as such.
- No real network dependency at runtime beyond local loopback inside the VM; the recording must be offline.
- No Windows/macOS. Serial console Linux VM only. SSH access is provided for convenience, never required.
- No PAM work. The login path is a plain NixOS account; nothing about authentication is being changed.
- No live mutation of the host outside the VM. Nothing escapes `/run/sumo`.

---

## 3. Current state (verified 2026-11-05)

| Thing | Where | State |
|---|---|---|
| 5-scene offline demo (proof, packages, pages, crosswalk, gate) | `demo/`, `./demo/run` | ships; casts committed; transcripts in README are hand-pasted |
| Pinned nixpkgs snapshot (rev `1d060086d60c`; facts committed) | `demo/facts/nixpkgs.kif` | offline, deterministic |
| NixOS VM spike (boots headless, runs sumonix at boot, serial console) | `spike/vm.nix`, `spike/demo.sh` | works; but a *service*, not a *session*; no interactivity |
| nixpkgs in this environment | `/nix-store/a3q0…-source` | `getFlake` works; `git ls-remote` works |
| Test runner | `./run-tests.sh` | 21 tests, all green |
| Duplicated engine helpers (`show`, `headOf`, `flatten`, `isVar`, `ground`, `subst`, `varsOf`, `ruleVars`, `unique`, `index`) | `datalog.nix`, `stratify.nix`, `ingest.nix`, `wfs.nix`, `existential.nix`, `temporal.nix`, `congruence.nix`, `policy/*.nix` | ~8–10 sites each; `proof-check.nix` deliberately standalone |
| README gate | none (manual edit) | transcripts drift |

---

## 4. Workstream A — The logged-in VM + sumonix dashboard (the centerpiece)

### 4.1 What ships, in order of visible payoff

```
A1  bin/sumo — the command the user reaches for           (foundation)
A2  machine facts — the VM's own world, as facts          (foundation)
A3  the VM — boots, autologin, MOTD, sshd for humans      (foundation)
A4  scripted tour — deterministic, recordable walkthrough (visible demo)
A5  sumo dashboard v1 — static UI, generated from eval    (the scene)
A6  sumo dashboard v2 — live/auto-refresh + activity log  (the product taste)
A7  recordings — cast(s) + browser screenshot(s)           (the artifact)
A8  sumo dashboard --serve flag; systemd timer; cleanup   (polish)
```

### 4.2 Components and the missing functionality to build

**A1. `sumo` command** — `bin/sumo`, pure bash + `nix`, on PATH in the VM. Subcommands (deterministic, cached after first run via `/run/sumo/cache/`):

| Subcommand | What it does | Uses |
|---|---|---|
| `sumo status` | Machine overview: services, package count, capability count, policy verdict + proof path | `status.nix` digest (new) |
| `sumo caps` | What this machine can do — the capability atlas of the installed closure | `spike/nixpkgs-snapshot.nix` capability map, baked facts |
| `sumo closure <pkg>` | Dependency tree (indented); `--json` for scripts | `closure.nix` (new digest) |
| `sumo query <goal …>` | Ground goal → engine verdict + `why` subtree | `datalog.nix` |
| `sumo why <finding…>` | Explain an org/policy finding with its proof (reuses `org/check.nix`-style `why`) | existing `why` machinery |
| `sumo whatif` | Interactive: drop one fact, re-run gate, show verdict flip + proof | `policy/relax.nix` patterns |
| `sumo dashboard` | Build (or rebuild) and serve the dashboard | A5–A8 |
| `sumo version`, `sumo help` | self-explanatory | — |

**A2. Machine facts** — `demo/vm/host-facts.nix` + committed `demo/vm/facts.kif`:
- 61 packages with `dependsOn` / `providesCapability` / `hasLicense` (reuse `spike/nixpkgs-snapshot.nix`);
- `nginx` as `NIXService`, `serviceState nginx running`;
- one critical advisory against `openssl` (`CVE-2026-9999`) so the policy verdict in the demo is non-trivial;
- `/run/sumo/facts.kif` written by a oneshot unit before any login.

**A3. The VM** — `demo/vm/vm.nix` (+ `demo/vm/build.sh`), extending the `spike/` pattern, not a new architecture:
- NixOS, `boot.loader.grub.enable = false`, tmpfs root, direct kernel boot, `console=ttyS0`, 2 cores / 2048 MB, `virtualisation.memorySize`.
- `users.users.demo = { isNormalUser = true; password = "demo"; extraGroups = [ "wheel" ]; }` (documented throwaway).
- `services.getty.autologinUser = "demo"` for the console experience; `services.openssh.enable = true` for humans who prefer ssh; no forced command — login behaves like any NixOS box.
- MOTD (`/etc/profile.d/sumo-motd.sh` or `environment.etc."bashrc.d/sumo.sh"`): the ASCII panel above, plus `export SUMO_FACTS=/run/sumo/facts.kif`.
- `systemd` unit `sumo-facts.service` (before `getty`): writes facts + seeds `/run/sumo/cache/`.
- `systemd` unit `sumo-dashboard.service` (A8): serves the dashboard on `127.0.0.1:8080`.
- `./demo/vm.sh` — build / boot / wait-for-ssh-or-console / `--record` / `--check` / `--teardown`. Hard `timeout 300`.

**A4. Scripted tour** — `demo/vm/session.sh`: deterministic command sequence, stdin-driven, byte-stable output (timestamps stripped). Interactive mode unaffected.

**A5. `sumo dashboard` v1 — static, honest, small**
- `demo/vm/dashboard.nix` — evaluates the gate, the capability atlas, the counts (facts/rules/rounds/derived), embeds the proof *verbatim*.
- Emits `/run/sumo/www/index.html` (self-contained: no external CSS/JS; inline a small `<style>`; ~120 lines).
- Served by `services.nginx` (127.0.0.1:8080, `root /run/sumo/www`).
- `sumo dashboard` command = regenerate + report the URL + exit.

**A6. `sumo dashboard` v2 — feels alive**
- systemd timer every 5 s re-runs the digest (derivations are cached; ~0.5 s warm).
- `<meta http-equiv="refresh" content="5">` on the page; no JS framework.
- An "activity" strip: last few derivations with round numbers (from `trace`), scrolling.
- A "policy" card verdict with a `<details>` block containing the raw proof.
- Optional, if time: `sumo dashboard --watch` in the terminal prints the same data as an updating TUI (ncurses-ish; or just `watch -n1 cat`).

**A7. Recordings**
- `docs/demo/tour.cast` — asciinema of the scripted session (autologin console, not ssh, for the "just works" feel).
- `docs/demo/dashboard.png` — one screenshot of the dashboard page from the host browser (or `import` from a headless Xvfb inside the VM).
- README embeds both (after Workstream B lands).

**A8. Polish** — `sumo dashboard` prints URL; nginx logs suppressed in demo; teardown clean; `--check` mode for KVM; docs updated.

### 4.3 Tasks

| # | Task | Files | Acceptance |
|---|---|---|---|
| A1 | `sumo` CLI (all subcommands) | `bin/sumo`, `demo/vm/sumo-pkg.nix` | each subcommand runs against baked facts; `sumo query '(vulnerable nginx CVE-2026-9999)'` prints the proof subtree; `--help` complete |
| A2 | machine facts (baked) | `demo/vm/host-facts.nix`, `demo/vm/facts.kif` | regenerate deterministically; includes nginx service + running state + one advisory |
| A3 | VM + `demo/vm.sh` | `demo/vm/vm.nix`, `demo/vm.sh` | boots headless; `demo` autologs in; MOTD shows; ssh works too; `sumo` on PATH; timeout enforced |
| A4 | scripted tour | `demo/vm/session.sh` | byte-identical output across two runs (timestamps stripped) |
| A5 | dashboard v1 | `demo/vm/dashboard.nix`, `demo/vm/dashboard.service`, nginx config | `sumo dashboard` builds and serves; page renders services/caps/proof; port 8080 |
| A6 | dashboard v2 | same + timer unit | refreshes ≤5 s; activity strip visible; proof `<details>` works |
| A7 | recordings | `docs/demo/tour.cast`, `docs/demo/dashboard.png` | committed; playable/viewable |
| A8 | `--check` mode + docs | `demo/vm.sh`, `run-tests.sh` | exits 0 on KVM; clear SKIP otherwise |

### 4.4 Why this is the demo

- **Interactive**, not a tape: the user can wander off-script and the machine answers.
- **Honest**: every number on the dashboard traces to an eval of the real engine; nothing is mocked.
- **Compelling**: the terminal builds appetite; the dashboard delivers it; the proof keeps it.
- **Extensible**: the same page structure scales to real deployments (multi-host, persistence, auth) — each next step is obvious.

## 5. Workstream B — README from parts (no hand-pasted transcripts)

### 5.1 Layout

```
docs/readme/            # prose, one file per section, emitted in lexicographic order
  00-head.md            # title + tagline + vision quote
  10-demo.md            # links to docs/demo/*.md (does NOT embed content)
  20-what-this-is.md
  ...                   # every current hand-written section, one file each
docs/demo/              # generated transcripts + casts (from ./demo/run, ./demo/vm.sh)
  00-proof.md
  01-capabilities.md
  02-pages.md
  03-crosswalk.md
  04-policy.md
  05-tour.md            # the VM session transcript
  05-dashboard.md       # dashboard transcript + screenshot link
tools/gen-demo.sh       # runs each scene, writes docs/demo/*.md (txt), writes .cast files
tools/build-readme.sh   # concatenates docs/readme/*.md; expands <!-- include:demo/05-tour.md --> markers
tools/check-readme.sh   # re-renders to a temp file, diffs against README.md, exits non-zero on drift
README.md               # generated; header says "DO NOT EDIT — run ./tools/build-readme.sh"
```

### 5.2 Marker rules (kept minimal)

- `<!-- include:demo/05-tour.md -->` → replaced by the file contents.
- `<!-- run: ./demo/run 02-capabilities.sh -->` → replaced by the **captured output** of the command.
- Everything else is literal prose.
- The generator is a ~60-line bash script using `awk`; no external deps.

### 5.3 Migration checklist

| # | Task | Acceptance |
|---|---|---|
| B1 | Split current README into `docs/readme/*.md` | byte-identical output after one `./tools/build-readme.sh` run |
| B2 | Extract the five existing demo transcripts into `docs/demo/*.md`; rewrite `10-demo.md` to `<!-- include: -->` them | `./demo/run` output unchanged; README section renders identically |
| B3 | Add `tour` and `dashboard` transcripts once A7 lands | generated, not pasted |
| B4 | Header comment in generated README: `<!-- generated by tools/build-readme.sh; do not edit -->` | present |
| B5 | `./tools/check-readme.sh` exits 0 | added to `run-tests.sh` |
| B6 | `tools/gen-demo.sh` re-records everything (`asciinema` required; degrades to txt-only if absent, with a warning) | committed casts change only when output changes |
| B7 | Delete `docs/demo/*.txt` after migration (keep `.md`) | no stale duplicates |

### 5.4 Why this matters

Every future edit to a demo transcript becomes a `git diff` of a generated file, not a hand-edited block; README can never silently disagree with the code; `./tools/check-readme.sh` in the test runner makes drift a failing test.

## 6. Workstream C — Low-hanging refactor (do this first)

**Order rule:** extract in order of risk, verify `./run-tests.sh` after each extraction, require a byte-identical `./demo/run` transcript.

### C1. Shared Nix helper library — `lib/kif.nix`

Extract, do not change semantics:

```nix
{
  inherit (builtins) concatStringsSep; …
  headOf, show, flatten, isVar, ground, subst, varsOf, ruleVars,
  unique, index,         # engine-local helpers
  isKifOp,               # headOf ∈ { "and" "or" "not" "exists" "forall" }
}
```

**Sites:** `datalog.nix`, `stratify.nix`, `ingest.nix`, `wfs.nix`, `existential.nix`, `temporal.nix`, `congruence.nix`, `synthesize.nix`, `policy/relax.nix`, `policy/soft-rules.nix`. Expected deletion: ~300 lines.

`proof-check.nix` keeps its own copies — zero-shared-code checker is the trust anchor.

### C2. Test boilerplate — `tests/lib.nix`

Every `tests/unit/*.nix` repeats `check = what: ok: …`. Extract `tests/lib.nix` exporting `check`. Unit tests shrink; they stop diverging.

### C3. Shell environment — `tools/env.sh`

`nix-eval.sh`, `run-tests.sh`, `demo/lib.sh`, `spike/demo.sh` each export `NIX_STORE_DIR`/`NIX_STATE_DIR` differently. One `tools/env.sh` sourced everywhere; `nix-eval.sh` becomes a 6-line wrapper.

### C4. `show` as the single pretty-printer

Once `lib/kif.nix` exists, give it `show` and delete the ~6 local copies.

### C5. Verification of C

```bash
./run-tests.sh                 # 21+ tests green
./demo/run > /tmp/after.txt
diff /tmp/before.txt /tmp/after.txt   # MUST be empty
git diff --stat                # expect ~-300 lines
```

If the diff is non-empty, stop and revert the extraction — do not patch forward.

## 7. Workstream D — Tools directory coherence (small, do last)

- `tools/` holds `env.sh`, `gen-demo.sh`, `build-readme.sh`, `check-readme.sh`.
- Root keeps only user-facing entry points: `nix-eval.sh`, `run-tests.sh`, `demo/run`, `bin/sumo`.
- `spike/` stays as exploration; anything reused by the VM moves to `demo/vm/` or `lib/`, spike imports it.

## 8. Milestones, order, and effort

| Order | Milestone | Effort | Gate |
|---|---|---|---|
| 1 | C3 + C1, one module at a time | 1–2 h | suite green after each |
| 2 | C4 + C2 | 30–45 min | suite green |
| 3 | A1 (`sumo` CLI) + A2 (facts) | 1–1.5 h | sumo runs in-repo |
| 4 | A3 (VM + `demo/vm.sh`) + A4 (tour) | 2–3 h | boots; autologin; MOTD; sumo on PATH |
| 5 | A5 (dashboard v1) | 1–2 h | page renders in a browser on 8080 |
| 6 | A6 (dashboard v2) | 45–60 min | auto-refresh + proof panel visible |
| 7 | A7 (record) | 30 min | casts committed |
| 8 | B1–B7 (README from parts) | 1.5–2 h | `check-readme.sh` green |
| 9 | D | 20 min | links updated |

Total ≈ **8–11 h**.

## 9. Risks and mitigations

| Risk | L | Impact | Mitigation |
|---|---|---|---|
| Dashboard is scope creep (turns into a product) | high | schedule | §2 non-goal; v1 is static HTML, v2 adds refresh *only*; no auth, no JS framework |
| VM build too heavy | med | demo unusable | 2 vCPU / 2048 MB; offline facts; `--check` skippable; `timeout 300` |
| Refactor breaks subtle semantics (`show`, `subst`) | med | silent wrong proofs | extract one helper at a time; byte-identical demo diff required; suite after every commit |
| README drift returns | high | doc rots | generated files + header + `check-readme.sh` in the suite |
| Demo session not byte-stable | med | README re-diff churn | scripted stdin, stripped timestamps, fixed locale |
| "login" misunderstood again | — | wasted hour | §1 and §4 are explicit: it is a *session*, a *world*, a *panel* — not an auth handshake |

## 10. Definition of done

- [ ] `./demo/vm.sh` boots; `demo` autologs into a working machine; MOTD shows; `sumo` works for every subcommand.
- [ ] `sumo dashboard` serves a rendered page on 127.0.0.1:8080 showing services, capabilities, policy verdict + proof, and auto-refreshes.
- [ ] `docs/demo/tour.cast` and `docs/demo/dashboard.png` committed.
- [ ] `README.md` is generated; `./tools/check-readme.sh` passes and is in `./run-tests.sh`.
- [ ] `lib/kif.nix` exists; `proof-check.nix` untouched; suite green; `./demo/run` output byte-identical.
- [ ] `./run-tests.sh` passes (including new VM smoke gate when `--vm`).
- [ ] `TODO.3.md` updated to track completion.

## 11. Open questions (with recommendations)

1. **Dashboard implementation** — recommend v1 static HTML (no framework, nginx) + v2 meta-refresh; no React, no build step. A TUI variant is a stretch goal, not a blocker.
2. **Baked vs live facts** — recommend baked for the recording (deterministic), `--live` as an option.
3. **Where does `sumo` live?** — `bin/sumo`, consistent with `bin/sumo-nix`.
4. **One VM or two recordings?** — one VM; `tour.cast` (terminal) and `dashboard.png` (browser) from it; README shows both.
5. **Should the dashboard be a real product later?** — out of scope; the §4 structure keeps the door open (auth, multi-host, persistence) without committing to it.

## 12. Sequencing summary

Refactor first (C) → VM + `sumo` CLI (A1–A4) → dashboard (A5–A6) → record (A7) → README from parts (B) → tools coherence (D). Each step ends with the suite green and the demo transcript byte-identical, except A5–A8 which intentionally add surface.
