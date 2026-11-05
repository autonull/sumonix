# TODO.3 — The Real 60-Second Demo: login on a NixOS VM, README from parts, and the big refactor

**Status:** planned, not started. **Predecessors:** TODO2.b (V3 + 7 T-milestones), `demo/` package, `run-tests.sh`. **Non-negotiables:** `./run-tests.sh` green at every step; the VM demo must boot unattended and exit non-zero on failure; nothing on the login path that can hang a real session; README regeneration must be byte-identical to what we ship.

---

## 0. Why this milestone exists

The current demo (`./demo/run`) is a good *proof* the engine works; it is not what a user experiences. The missing piece is the moment a person **logs into a real NixOS machine and sumonix is what let them in** — the policy verdict, its proof, and the machine explaining itself as they arrive. That is the 60-second story. Two things block it today:

1. **No live entry point on a real system** — no `sumo` command, no admission decision, no VM image that runs the story end-to-end.
2. **Human-curated README** — the transcripts in `README.md` are hand-pasted and drift from reality on every edit; they must be generated, or editing them rots the doc.

A side effect of building this honestly is forced refactoring: the engine's shared helpers are copy-pasted across ~12 files; extracting them is the cheapest large code-quality win available, and it must happen on the way, not after.

---

## 1. Non-goals (explicitly deferred)

- No new reasoning capability (no T-milestones, no Soufflé, no parallel eval). The login demo must be built with what the engine already does.
- No public network service, no hosted dashboard. VM-only and local.
- No PAM rewrite for the demo. Custom `pam_exec` rules in NixOS are marked `[experimental]` and a misconfiguration locks the machine out — see §8 risk table. The admit decision is made by **SSH `ForceCommand`** (supported, config-level, no lockout beyond the demo account) with a getty/console path as fallback.
- No real-user secrets handling. The demo VM is disposable, unprivileged UT `demo` with a dummy password, no network route to anything real.
- No Windows/macOS. Serial console Linux VM only.

---

## 2. Current state (what we have, verified 2026-11-05)

| Thing | Where | State |
|---|---|---|
| 5-scene offline demo (proof, packages, pages, crosswalk, gate) | `demo/`, `./demo/run` | ships; casts committed; transcripts in README hand-pasted |
| Pinned nixpkgs snapshot (rev `1d060086d60c`, fetched, cached, committed to `demo/facts/nixpkgs.kif`) | `demo/facts/` | offline, deterministic |
| NixOS VM spike (boots headless, runs sumo inside, serial console) | `spike/vm.nix`, `spike/demo.sh` | works; not a user-facing demo; autologin not used |
| nixpkgs in this environment | `/home/me/sumonix/.nix-store/a3q0rqv034l7g9d30hzhv9kzakak14jq-source` (rev `1d060086…`) | `git ls-remote` works; `builtins.getFlake "github:…"` works |
| Test runner | `./run-tests.sh` | 21 tests, all green, one command |
| Duplicated engine helpers (`show`, `headOf`, `flatten`, `isVar`, `ground`, `subst`, `varsOf`, `ruleVars`, `unique`, `index`) | `datalog.nix`, `stratify.nix`, `ingest.nix`, `wfs.nix`, `existential.nix`, `temporal.nix`, `congruence.nix`, `policy/*.nix` | ~8–10 sites each; `sumo.nix` partial; proof-check.nix deliberately standalone |
| README gate | none (manual edit) | transcripts drift |

---

## 3. Workstream A — The login VM demo (the centerpiece)

### 3.1 The user journey the recording shows

```
$ just boot the VM           # ./demo/vm.sh   (or: nix run)
... kernel boots, sshd starts ...
$ ssh demo@localhost -p 2222          # password: demo
╔════════════════════════════════════════════════════════════╗
║  sumonix evaluates this login…                             ║
║  host facts: 61 packages · 2 services · 1 profile (web)    ║
║  policy: login-admit                                     ║
║  verdict: ADMITTED (proof: 23 steps, re-checked in 0.4s)  ║
╚════════════════════════════════════════════════════════════╝
demo@sumo-nix-demo:~$ sumo caps           # what can this machine do?
demo@sumo-nix-demo:~$ sumo closure openssl  # what does openssl pull in?
demo@sumo-nix-demo:~$ sumo gate           # why am I in — show the proof
demo@sumo-nix-demo:~$ exit
$ ./demo/vm.sh --record                  # asciinema cast
```

A second recording flashes the *deny* path (`./demo/vm.sh --deny` → synthesized advisory hits the running web service → login refused, proof printed, no shell).

### 3.2 The mechanism (decision + rationale)

**Chosen: sshd + `ForceCommand`.** In `vm.nix`:

```nix
services.openssh.enable = true;
services.openssh.extraConfig = ''
  Match User demo
    ForceCommand /run/wrappers/bin/sumo-login-gate
    PasswordAuthentication yes
'';
environment.systemPackages = [ sumo-cmd ];   # the `sumo` CLI
```

`sumo-login-gate` is a small bash launcher that runs the gate decision (`nix eval`, cached) and either execs the user's shell (admit) or prints the refusal proof and `exit 1` (deny). The decision is **never** an exception you can't see: it prints the verdict and where the proof lives. Console fallback for humans without ssh: `services.getty.autologinUser = "demo"` + `demo`'s shell profile runs the same gate banner before the prompt (does not block, non-secret).

**Rejected:** custom PAM `pam_exec` / `rules.*` — experimental upstream, misconfig = locked out, zero diagnostic value for a screen recording. **Rejected for now:** replacing `getty`'s `login` binary — invasive for marginal gain.

### 3.3 Missing functionality to implement (the actual work)

**A1. `sumo` user command** — `bin/sumo` (pure bash + `nix`), installed via `environment.systemPackages` in the VM. Subcommands (all deterministic, all cached after first call):
- `sumo caps` — capability summary of the *running* machine's package set (reuses `spike/nixpkgs-snapshot.nix` capability map, but facts generated from the VM's own `profile.toplevel` or a pinned list — see A4 decision).
- `sumo closure <pkg>` — transitive `dependsOn` closure, rendered as a tree (`libq` style indent), with `--json` for scripting.
- `sumo query <goal …>` — pass a ground goal (e.g. `vulnerable nginx CVE-2026-9999`), print the engine's verdict + `why` subtree.
- `sumo gate` — re-run the login-admission policy; print verdict + proof path (`/run/sumo/login-proof.txt`).
- `sumo version` / `sumo help` — self-explanatory.

**A2. Login-admission policy** — `policy/login-gate.nix`. Input: machine facts (A4). Goal predicate: `policyViolation <any running service> <any unresolved critical advisory>` must be **underivable**. Output: `{ pass; verdict; proof; tree; }` (shape of `policy/build-gate.nix` `check`). When it passes, proof says "admitted because …"; when it fails, includes the `why` subtree. This is the only new policy; reuses existing machinery verbatim.

**A3. Machine-facts generator** — `demo/vm/host-facts.nix`. Two modes: `--baked` (default, deterministic): a pinned synthetic host — 61 packages, `nginx` running as `NIXService`, one open advisory against `openssl` → the deny path exists and is recordable; or the same facts minus the advisory → admit path. `--live` (optional, not in the recording): evaluates facts from the VM's actual system closure (slower, varies). Baked facts are committed as `demo/vm/facts.kif`.

**A4. The VM** — `demo/vm/vm.nix` (+ `demo/vm/build.sh`). Extends the `spike/vm.nix` pattern, not a new architecture:
- NixOS, `boot.loader.grub.enable = false`, tmpfs root, direct kernel boot, `console=ttyS0`, 2 cores / 2048 MB, `virtualisation.memorySize`.
- `users.users.demo = { isNormalUser = true; password = "demo"; }` (documented throwaway credential).
- `services.openssh.enable = true` with the `ForceCommand` block above; serial getty for console fallback.
- `sumo` package on PATH; `/etc/bashrc.d` or user profile export `SUMO_FACTS=/run/sumo/facts.kif`, `SUMO_PROOF_DIR=/run/sumo`.
- Oneshot `sumo-facts.service` runs before sshd: writes `/run/sumo/facts.kif` from `demo/vm/host-facts.nix`.
- `sumo-login-gate` (from A1) on PATH; `systemd` journal is the log (`console` gets it).
- No network: `networking.useDHCP = false` for the login demo; ssh works over `user-mode` forwarding to host port 2222.
- `./demo/vm.sh` — build, boot, wait for `sshd`, run the scripted transcript via `ssh -o … demo@127.0.0.1 -p 2222`, capture, exit; `--record` wraps it in `asciinema rec`; `--deny` toggles the baked advisory fact on/off; `--live` selects live mode; hard `timeout 180`.

**A5. Deterministic session transcript** — scripted stdin (fixed commands, fixed order) → byte-stable output for README. Interactive logins keep working for humans; the *recording* is scripted.

**A6. CI-less smoke gate** — `./demo/vm.sh --check`: boot, ssh in, run `sumo version`, expect exit 0 inside 60 s, hard kill. Added to `run-tests.sh` behind a flag (off by default — requires KVM; opt-in on machines that can).

**A7. Recordings** — two casts committed: `docs/demo/login-admit.cast`, `docs/demo/login-deny.cast`. README embeds the transcripts (see Workstream B).

### 3.4 Tasks

| # | Task | Files | Acceptance |
|---|---|---|---|
| A1a | `bin/sumo` with `caps`/`closure`/`query`/`gate`/`version`/`help` | `bin/sumo`, `demo/vm/sumo-pkg.nix` | each subcommand runs against baked facts; `sumo query '(vulnerable openssl CVE-2026-9999)'` prints the gate subtree |
| A1b | `sumo-login-gate` launcher | `bin/sumo-login-gate` | exit 0 + `exec /bin/bash -l` on pass; exit 1 + proof to stderr on fail; never swallows the gate's exit code |
| A2 | login-admission policy | `policy/login-gate.nix`, `tests/unit/login-gate.nix` | admit case passes; deny case fails with proof containing `policyViolation` |
| A3 | baked host facts + generator | `demo/vm/host-facts.nix`, `demo/vm/facts.kif` | deterministic across runs; `--live` works when network available |
| A4 | VM definition + `demo/vm.sh` | `demo/vm/vm.nix`, `demo/vm.sh` | boots headless; ssh works with `demo/demo`; forced command in effect; `--deny` shows refusal; timeout enforced |
| A5 | scripted session | `demo/vm/session.sh` | output byte-identical across two runs (modulo timestamps, which are stripped or fixed) |
| A6 | check mode | `demo/vm.sh`, `run-tests.sh --vm` | passes on KVM hosts; clean skip otherwise with a clear message |
| A7 | record both casts | `docs/demo/*.cast` | committed; playable |

### 3.5 Verification of the whole workstream

```bash
./demo/vm.sh                # boots, ssh session runs, transcript printed
./demo/vm.sh --deny         # shows refused login with proof
./demo/vm.sh --check        # exits 0 (KVM) or prints "SKIP: no KVM" and exits 0
run-tests.sh                # all 21 (+ login-gate unit) green
```

---

## 4. Workstream B — README from parts (no hand-pasted transcripts)

### 4.1 Layout

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
  05-login-admit.md     # from ./demo/vm.sh
  05-login-deny.md
tools/gen-demo.sh       # runs each scene, writes docs/demo/*.md (txt), writes .cast files
tools/build-readme.sh   # concatenates docs/readme/*.md; expands <!-- include:demo/05-login-admit.md --> markers
tools/check-readme.sh   # re-renders to a temp file, diffs against README.md, exits non-zero on drift
README.md               # generated; header says "DO NOT EDIT — run ./tools/build-readme.sh"
```

### 4.2 Marker rules (kept minimal)

- `<!-- include:demo/05-login-admit.md -->` → replaced by the file contents.
- `<!-- run: ./demo/run 02-capabilities.sh -->` → replaced by the **captured output** of the command (used when regeneration is desired without pre-committed transcripts).
- Everything else is literal prose.
- The generator is a ~60-line bash script using `awk`; no external deps.

### 4.3 Migration checklist

| # | Task | Acceptance |
|---|---|---|
| B1 | Split current README into `docs/readme/*.md` | byte-identical output after one `./tools/build-readme.sh` run |
| B2 | Extract the five existing demo transcripts into `docs/demo/*.md`; rewrite `10-demo.md` to `<!-- include: -->` them | `./demo/run` output unchanged; README section renders identically |
| B3 | Add `login-*` transcripts once A7 lands | they are generated, not pasted |
| B4 | Header comment in generated README: `<!-- generated by tools/build-readme.sh; do not edit -->` | present |
| B5 | `./tools/check-readme.sh` exits 0 | added to `run-tests.sh` |
| B6 | `tools/gen-demo.sh` re-records everything (`asciinema` required; degrades to txt-only if absent, with a warning) | committed casts change only when output changes |
| B7 | Delete `docs/demo/*.txt` after migration (keep `.md`) | no stale duplicates |

### 4.4 Why this matters

Every future edit to a demo transcript becomes a `git diff` of a generated file, not a hand-edited block; README can never silently disagree with the code; `./tools/check-readme.sh` in the test runner makes drift a failing test.

---

## 5. Workstream C — Low-hanging refactor (do this *before* A if the diff gets big)

**Order rule:** extract in order of risk, verify `./run-tests.sh` after each extraction, and require a byte-identical `./demo/run` transcript (modulo nothing — it should not change at all).

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

**Sites:** `datalog.nix`, `stratify.nix`, `ingest.nix`, `wfs.nix`, `existential.nix`, `temporal.nix`, `congruence.nix`, `synthesize.nix`, `policy/relax.nix`, `policy/soft-rules.nix` (and any others found by grep). Expected deletion: ~300 lines of duplication.

`proof-check.nix` is intentionally **zero-shared-code with the engine** — it keeps its own copies, with a comment saying so. Do not wire it to `lib/kif.nix`.

### C2. Test boilerplate — `tests/lib.nix`

Every `tests/unit/*.nix` repeats `check = what: ok: …`. Extract `tests/lib.nix` exporting `check` (and if it stays tiny, nothing else). Unit tests shrink by ~4 lines each; more importantly they stop diverging.

### C3. Shell environment — `tools/env.sh`

`nix-eval.sh`, `run-tests.sh`, `demo/lib.sh`, `spike/demo.sh` each export `NIX_STORE_DIR`/`NIX_STATE_DIR` differently (absolute vs relative, duplicated). One `tools/env.sh` sourced everywhere; `nix-eval.sh` becomes a 6-line wrapper. No behavior change; one place to change if the store layout ever moves.

### C4. `show` as the single pretty-printer

Once `lib/kif.nix` exists, give it `show` and delete the ~6 local copies. This is the one that unblocks consistent proof formatting everywhere.

### C5. Verification of C

```bash
./run-tests.sh                 # 21+ tests green
./demo/run > /tmp/after.txt
diff <(cat /tmp/before.txt) /tmp/after.txt   # MUST be empty
git diff --stat                # expect ~-300 lines
```

If any `diff` is non-empty, stop and revert the extraction — do not patch forward.

---

## 6. Workstream D — Tools directory coherence (small, do last)

- `tools/` holds `env.sh`, `gen-demo.sh`, `build-readme.sh`, `check-readme.sh`.
- Root keeps only user-facing entry points: `nix-eval.sh`, `run-tests.sh`, `demo/run`, `demo/vm.sh`, `bin/sumo`.
- `spike/` stays as the *exploration* area; anything reused by the VM moves to `demo/vm/` or `lib/`, spike imports it (do not fork it).

---

## 7. Milestones, order, and effort

| Order | Milestone | Effort | Gate |
|---|---|---|---|
| 1 | C3 (`tools/env.sh`) + C1 extraction, one module at a time | 1–2 h | suite green after each |
| 2 | C4 (`show`) + C2 (`tests/lib.nix`) | 30–45 min | suite green |
| 3 | A2 (policy) + A3 (facts) + A1 (`sumo` CLI) | 1.5–2 h | unit test green |
| 4 | A4 (VM + `demo/vm.sh`) + A5 (scripted session) | 2–3 h | `--check` passes on KVM |
| 5 | A7 (record both casts) | 30 min | casts committed |
| 6 | B1–B7 (README from parts) | 1.5–2 h | `check-readme.sh` green; README diff ~0 lines of substance |
| 7 | D (tools coherence) | 20 min | links updated, nothing else changes |

Total ≈ **7–10 h**, independent of the deferred Soufflé/parallel work.

---

## 8. Risks and mitigations

| Risk | L | Impact | Mitigation |
|---|---|---|---|
| sshd `ForceCommand` breaks normal interactive login expectations | med | annoyance | demo account only; console fallback (getty autologin + profile banner, no blocking) |
| VM too heavy for laptop/CI | med | demo unusable | 2 vCPU / 2048 MB; `--check` skippable; offline baked facts; `timeout 180` |
| PAM temptation / scope creep | high | lockout, schedule | §1 non-goal; §3.2 decision table; no PAM in this milestone |
| README drift returns | high | doc rots | generated files + header + `check-readme.sh` in the suite |
| Refactor breaks subtle semantics (`show`, `subst`) | med | silent wrong proofs | extract one helper at a time; byte-identical demo diff required; suite after each commit |
| Login gate becomes a real auth path someone copies | low | misuse | `demo/vm/` README warning; demo creds never leave the VM; no secrets anywhere in facts |
| nixpkgs pin drifts | med | demo rots with time | pin in `demo/vm/vm.nix` (`1d060086…`), `gen-facts.sh` refreshes explicitly |

---

## 9. Definition of done

- [ ] `./demo/vm.sh` boots a real NixOS VM, sshd login succeeds with `demo`/`demo`, transcript shows `ADMITTED` + proof; `--deny` shows refusal + proof; both casts committed and playable.
- [ ] `sumo` command exists in the VM: `caps`, `closure`, `query`, `gate`, `version` all work.
- [ ] `README.md` is generated (`./tools/build-readme.sh`); header says do-not-edit; `./tools/check-readme.sh` passes and is wired into `./run-tests.sh`.
- [ ] `lib/kif.nix` exists; engine/policy modules import from it; `proof-check.nix` untouched; suite green; `./demo/run` output byte-identical to before.
- [ ] `./run-tests.sh` passes including the new `tests/unit/login-gate.nix`.
- [ ] `TODO.3.md` updated to track completion (checkboxes ticked, as-built notes).

## 10. Open questions (with recommendations)

1. **Baked vs live facts for the admit decision** — recommend baked (deterministic, offline, recordable) with `--live` as an option; live makes the recording flaky.
2. **Where should `sumo` live?** — recommend top-level `bin/sumo`, consistent with `bin/sumo-nix`; not `tools/` (user-facing, not dev tooling).
3. **Should the login gate sign the verdict?** — no for this milestone; proof file + re-check is the trust anchor; signing is a separate, later decision.
4. **One VM or two recordings?** — recommend two committed casts (admit, deny) from one VM definition; the README shows both.

---

## 11. Effort and sequencing summary

Refactor first (C) — it makes A and B smaller. Then A (the demo). Then B (README from parts) using A's transcripts. Then D (coherence). Each step is independently revertable; every step ends with the suite green and the demo transcript byte-identical, except A5 and A7 which intentionally add output.
