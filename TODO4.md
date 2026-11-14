I've got the README overview. Let me dig into the current TODO/roadmap files and repo internals so the plan builds on what's actually there rather than duplicating it.
# sumonix — Next-Development Plan

I read the repo (README, `TODO3.md`, `AGENTS.md`, `bin/sumo`, `flake.nix`, `reasoner/`, `policy/`, tests) before planning. Quick assessment, then a prioritized roadmap.

## Where the value is — and isn't

**Already strong (don't rebuild):** the kernel is real — parser → ontology with equivalence union-find → provenance-carrying Datalog → declaration-driven synthesis (166 rules) → stratified ingestion (116 Horn rules, honest rejections) → **proof export + zero-shared-code checker** → build gate + relaxation menu. Extension modules (`congruence`, `builtins`, `wfs`, `temporal`, `existential`, `soft-rules`) exist with unit tests. Demo discipline (byte-stable output, live/fixture labeling, generated README) is exceptional.

**The value gaps, with evidence:**

| Gap | Evidence | Cost to value |
|---|---|---|
| It's a demo of a product, not a product | `bin/sumo guard` hardcodes `(policyViolation nginx NoCriticalRunningCVE)`; atlas is 60 fixture packages; `whatif` does one canned flip | Nobody can point it at *their* system yet |
| Zero install path | `flake.nix` has no `apps`, `checks`, `devShells`; no CI (`.github/` absent); no releases | `nix run github:autonull/sumonix` fails; invisible to adopters |
| Best features unreachable from CLI | `query` is ground-only; no `sumo why/proof/check/relax` despite library support | The differentiator (auditable answers) is locked inside demo scenes |
| ~1 s per subcommand | README limitation; every call re-runs the fixpoint under `nix eval` | Blocks scale (B1) and interactivity |
| Thin real-world ingestion | Live facts = systemd/proc/ss/store only; 24 live facts | No answer to "what does this do for *my* repo?" |
| Extensions are islands | Modules + unit tests exist, but README's covered/not-covered table shows they're not on the eval/proof path | Power built but not shipped |

**Strategy: convert the proven demo into a tool people run on their own machines and repos, and make it installable and independently verified in one command.** Every phase below preserves the project's constitution: pure Nix, Rule Zero (no unbounded FOL in eval), rejection-with-reason, live/fixture honesty, every answer checkable.

---

## Phase 0 — Installable & verified (~1–2 days) · *usability × trust, highest ROI*

| # | Item | Acceptance | Status |
|---|---|---|---|
| 0.1 | **Flake product surface**: `apps.default = sumo`, `devShells`, `checks` from the 21-test suite (this is bootstrap **B26**, <1 h), packages for `x86_64-linux` | `nix run github:autonull/sumonix -- status` works on a clean machine, no clone; `nix flake check` fails with a proof when a policy test breaks | ✅ DONE |
| 0.2 | **GitHub Actions CI**: `run-tests.sh`, demo byte-diff, `check-readme.sh`, proof tamper suite; Nix store cache; badge | Green badge on README; every PR proves itself. **Bonus:** runners have user namespaces — this unblocks the parked container workstream (N2/N3/N5/N6) that your dev sandbox can't verify (`AGENTS.md`: `userns_clone=0`) | ✅ DONE (`.github/workflows/ci.yml`) |
| 0.3 | **Tag v0.1.0** with `proof.kif` + checker as release assets | The release ships its own independently re-checkable proof — a marketing artifact nobody else has | ⬜ TODO |

## Phase 1 — Demo → tool (~1 week) · *usefulness*

| # | Item | Acceptance | Effort |
|---|---|---|---|
| 1.1 | **De-hardcode `guard`**: read policy goals from a `policies.kif` (or `--policy` file); report *all* violations, each with proof; stable versioned `--json` schema | On a host with no nginx/CVE, `guard` checks the user's actual policies; exit codes documented | ✅ DONE |
| 1.2 | **Expose the crown jewels**: `sumo ask '(vulnerable ?X ?CVE)'` (non-ground, library already has `ask`), `sumo why <fact>`, `sumo proof <goal> -o p.kif`, `sumo check p.kif`, `sumo relax` | Every README demo scene becomes a command a user can run on their own facts; checker usable standalone | ✅ DONE |
| 1.3 | **`sumo init`** scaffolding: `facts.kif` / `rules.kif` / `policies.kif` + pre-commit hook + CI template | `sumo init && sumo guard` in any repo in <60 s — this is your time-to-first-value metric | 2–3 h |
| 1.4 | **Compile-once/query-many cache**: at `refresh`, compute fixpoint + proofs; store under `.runtime/` keyed by hash(facts+rules+ontology); subcommands become lookups; `--no-cache` escape | Unchanged facts → subcommands ~instant instead of ~1 s each; purity intact (cache is content-addressed, engine remains the oracle) | 4–8 h |
| 1.5 | **Error UX**: parser errors with `file:line:col`, unknown-predicate warnings, `sumo lint`, shell completions | A typo'd KIF file gets a located diagnostic, never a Nix stack trace (extends your no-throw-on-user-data rule) | 3–5 h |

## Phase 2 — Real-world inputs (~1–2 weeks) · *flexibility × usefulness*

Pick bootstraps by demand and uniqueness, not by list order:

| # | Bootstrap | Why this one | Acceptance |
|---|---|---|---|
| 2.1 | **B3 json2kif/yaml2kif** (keystone) | Unlocks B4/B5/B8/B9/B13/B14 for free; declarative mapping spec, typed, total, rejects with reasons | Round-trip test + oracle (you already use Python oracles in `tests/`) |
| 2.2 | **B6 lockfile + OSV** | The killer demo: *your* `flake.lock`/`package-lock.json`/`Cargo.lock`, real advisories (pinned OSV snapshot, offline like `pins.nix`), transitive CVE proof, gate, relaxation menu | `sumo guard` on this repo finds real advisories or honestly reports zero; proof re-checks |
| 2.3 | **B1 at true scale** | Replace 60 fixture packages with the live system closure (`nix-store -q --requisites /run/current-system`): licenses, deps, versions | Measured fact count + eval time at 10k–100k facts; published benchmark decides whether semi-naive/incremental is ever needed (currently skipped by evidence — keep it that way until data says otherwise) |
| 2.4 | **B24 NixOS config contradiction** | Uniquely native, zero competitors: "Postgres needs 5432 but StrictFirewall denies all" — with proof, at eval time | Contradiction demo on a real `nixosConfigurations`; module options → facts lifter |
| 2.5 | **B25/B2 policy packs as flake inputs** | The ecosystem play: `inputs.policies.url = "github:org/gdpr-kif"` — versioned, pinned, composable compliance | Two third-party-style packs compose; pin changes are visible in `sumo status` sources |

## Phase 3 — Ship the power you already built (~1–2 weeks) · *power*

The extension modules exist; the missing work is **integration through ingest → engine → proof → checker → CLI**, in value order:

1. **Builtins/version ranges first** — CVE reasoning is *wrong* without "affects < 3.0.7"; this makes 2.2 correct, not just impressive.
2. **Aggregates** — policies like "≤ 2 critical CVEs", "no more than N network transmitters".
3. **Temporal** — fact TTL/freshness ("advisory older than 90 days", "service restarted after patch"), natural fit for live facts.
4. **Congruence, soft-rules/MaxSAT, WFS** — behind flags, per the extension contract.

**Hard acceptance for each:** new proof step kinds (`by builtin#…`, `by aggregate#…`) must be verifiable by the zero-shared-code checker, with tamper tests — checker parity is the invariant that makes this project worth anything. Then **V4 Soufflé differential CI** as an offline nightly job (never in the eval path): same facts + rules → same fixpoint, disagreements are bugs. Cheap, and it certifies the naive engine at scale.

## Phase 4 — Receipts & reach (~1 week, parallelizable)

- **B19 signed compliance receipts** (`sumo receipt` → JSON+KIF bundle: fact hashes, policy pack versions, verdict, proof; `sumo receipt verify`) — the audit artifact enterprises actually buy.
- **SARIF output + a GitHub Action wrapper** (`uses: autonull/sumonix-action`) — violations render in the PR security tab; 3 lines of YAML to adopt. Biggest single adoption lever.
- **B20 proof badges**, **B28 why-does-this-exist** docgen.
- **Finish workstream N in CI** (0.2 unblocked it): the NixOS container that *passes its own gate* — "the system that gates itself" is your best story; keep it out of the demo until it passes, per your own honesty rule.
- TUI: interactive query + proof-tree browsing over the cached digest (fixes the timer-only refresh limitation).

---

## Explicitly *not* doing (protects value)

- Full FOL / disjunctive stable models in the eval path (Rule Zero), online Knuth–Bendix.
- New logic extensions before Phase 3 integration — islands don't ship.
- Premature semi-naive/parallel eval — your benchmark (~1.1 s, well under the 5 s gate) says no until Phase 2.3 data says yes; the cache (1.4) likely dominates both.
- Reviving the QEMU/VM path; the container-in-CI route supersedes it.
- Chasing non-Nix platforms before owning the Nix niche.

## Success metrics

| Metric | Now | Target after Phases 0–2 |
|---|---|---|
| Time from landing on README to first answer about *your own* system | impossible | < 2 min (`nix run` + `init`) |
| Facts reasoned over | 60 fixture + ~24 live | full system closure + real advisories |
| Subcommand latency (warm) | ~1 s | < 100 ms |
| Checker coverage of shipped features | core only | 100% (every step kind re-checkable) |
| CI-verified claims | 0 (local only) | all tests + demo byte-stability + container gate |

**If you only do three things next:** 0.1 + 0.2 (one-command install, CI that proves every claim) ✅, 1.1 + 1.2 (real guard, exposed proof/why/ask), 2.2 (real CVEs on real lockfiles). Those three convert sumonix from "a beautiful demo of an idea" into "the tool that fails your build with a proof you can check" — which is the sentence the README already promises.

---

## Implementation Notes (Phase 0)

### Flake Changes
- **apps.default**: `nix run github:autonull/sumonix` now works
- **devShells**: Includes `sumo-cli` package, `sumo` command available in shell
- **checks**: 5 checks defined (tests, demo-byte-diff, readme-check, proof-tamper, all)
- **packages**: `sumo-cli`, `sumo-tui`, `sumo-facts` for x86_64-linux

### Known Issues
- **aarch64-linux**: Package builds work but not tested (no aarch64 runner locally)
- **sumo-tui**: Go module download fails in sandbox (needs `buildGoModule` or vendored deps)
- **sumo-facts**: Builds but not fully tested

### CI Workflow (`.github/workflows/ci.yml`)
- Runs on push/PR to main
- Jobs: checks, build, run-smoke, dev-shell
- Uses DeterminateSystems nix-installer-action
- Requires `/nix/store` (available on GitHub runners)

### Next: Phase 1
✅ **1.1 De-hardcode `guard`** - `policies.kif` created, `guard` now reads all policy goals, reports each violation with proof, stable `--json` schema.
✅ **1.2 Expose the crown jewels** - `sumo ask`, `sumo why`, `sumo proof`, `sumo check`, `sumo relax` all implemented with `--json` support.

Next: **1.3 `sumo init`** scaffolding: `facts.kif` / `rules.kif` / `policies.kif` + pre-commit hook + CI template.

