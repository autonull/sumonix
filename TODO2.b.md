# TODO2.b — The Reasoner (rev 2: fastest results first)

**Status:** Phases 0–5 complete (V3 ships). Rev 2 — value-first order executed; Contract (§5) unchanged. Non-negotiable at every step: `tests/` green; every unsupported form rejected with a reason; no `throw` on user data paths.

**Decisions:** full 0–5 slice executed; Merge.kif pinned; ingestion default-on (verdict `ingestible`, Horn 302); local gates only.

---

## 0. What changed in rev 2 (consolidation notes)

| Change | Why |
|---|---|
| **Value-first order**: measure → correctness → safe ingestion → proof export → **policy product** → perf on demand | Rev 1 spent 4–6 h on the semi-naive rewrite before any artifact existed. Now the first product (build gate + violation proof) ships after ~10–12 h, and the engine rewrite is **data-driven**, gated by a benchmark, not pre-committed |
| **Stratifier promoted** to its own phase, required *before* ingesting Merge.kif | Unsafe negation rules from SUMO must be rejected, whatever the engine speed is |
| **Proof export moved ahead of performance work** | It works on the current engine, is independently verifiable, and is itself a sellable artifact |
| **Semi-naive is now conditional** (Phase 6), with parity test + ≤5 s gate | If closure is fast enough, we skip it; the Contract does not require in-place speed, only capability |
| **Consolidated sections**: guardrails (was "non-negotiables"), diagnostics folded into phases, hygiene tasks added | Less repetition, more state-of-play |
| **V-milestones + stop-loss rules** | Every phase ends with tests green + one runnable demo; any phase red > 30 min ⇒ stop and reassess |
| **Explicit kill switches** | If Phase 0 disproves Horn yield (<100), ingestion is off by default; everything else still ships |

**Unchanged:** mission, extensibility contract, ontology (`equivalent` union-find grows the oracle-safe subsumption), proof DAG, honesty-of-rejection, no new dependencies, pure Nix.

---

## 1. Mission

A reasoner that:

1. Is **capable**, not just correct on the demo — ingests Merge.kif's Horn fragment, derives the transitive closures SUMO declares, subsumes through `equivalent` classes, answers queries with full provenance; fast enough for real CI (benchmark gate, not hope).
2. Is **SUMO-native**: `instance` subsumption incl. equivalences; synthesis of rules from SUMO's own declarations; no hand-curation of 1,065 axioms.
3. Exports **audit-grade proofs**: `explain` validates independently via `proof-check.nix`.
4. Is **expandable to the full feature set** (everything historically dismissed) via §5 — admitted by design, never by accident.
5. Delivers **policy value**: build-time gate with a proof-of-violation, and a relaxation menu.

## 2. Current state (T0) — in brief

- `kif.nix` robust parser; `sumo.nix` builds class taxonomy + subsumption (**ignores `equivalent`**); `datalog.nix` ~130-line **naive** forward-chainer:
  - per round, `derive` re-fires **all** rules on the **full** fact set; `index` rebuilt per round; no rule-head index.
  - Handles `and`, `exists`, `not` (NAF), `equal`, `instance` (subsumption via ontology). Consequents must be ground (else `throw`).
  - Every derived fact carries `{ rule, from }`; `why`/`explain` render proof trees.
- `tests/` is the oracle: `default.nix` (golden: 5505 forms, 714/712 classes, `ancestors.Human`, `classOf.part`), `rules.nix`/`scenario.nix` (CVE-provenance over `Merge.kif + nix-domain.kif`), and five Python/jq-oracle gates (`bags`, `decide`, `hf`, `org`, `pyai`). All are `eval → "ok"`.
- `sumo.full/Merge.kif`: 632 KB / 19,084 lines / 1,065 `=>` / 84 top-level `(forall`. Horn yield **unverified** → Phase 0.

### Gaps to close

G1 Merge Horn rules never evaluated · G2 naive evaluation (O(rules×facts×rounds) — closed by P6 only if the benchmark demands it) · G3 no `equivalent` subsumption · G4 no declaration synthesis · G5 no stratification → unsafe NAF possible · G6 no termination guards (functions, unbounded depth, silent drops) · G7 no policy artifacts (gate, relaxation menu, exported proofs).

## 3. Guardrails (apply to every phase)

1. **Soundness** — no derived fact without `by`/`from`; `why` is the source of truth.
2. **Termination** (T1 target) — finite Herbrand universe; consequents ground; no function symbols; proofs bounded.
3. **Determinism** — least-model, set semantics; result independent of rule/fact order.
4. **Closed world** — NAF only in safe strata; stratifier enforces.
5. **Honesty of rejection** — everything unsupported is rejected with a reason; never silently ignored; never `throw` for valid user input.
6. **Tests gate everything** — `tests/` green per commit; parity T0≡T1 when the fast engine exists.
7. **Pure Nix** — zero new runtime deps; optional CI-only extras (Soufflé diff) never on the eval path.
8. **Minimal diff** — no gratuitous reformats; surgical commits per phase.

## 4. Target architecture

Interfaces narrow and total; layers replaceable independently:

- `ingest.classify : [forms] → { ontology; horn; rejected }`
- `engine.run : { ontology; rules; facts; builtins ? []; features ? {} } → { facts; holds; ask; why; explain; diagnostics; }`
- `policy.check : { goal; toggles } → { verdict; hits; }`

**Engine policy (rev 2):** keep the **naive engine as the shipping path through Phase 5**; implement semi-naive only in Phase 6, only if the benchmark fails (>5 s or >2× regression) with the parity test as the gate. The stratifier is NOT optional and NOT deferred — it lands in Phase 2 because ingestion is unsafe without it.

```
Merge.kif ─┐
DOMAIN.kif ┼─► ingest.classify ─► { ontologyParts | hornRules | rejected(+reasons) }
SEEDS      ┘        │                    │
                    ▼                    ▼
              sumo.nix (+equiv)   engine.run (naive now; semi-naive if benched)
                                          │
                 ┌───────────────────────┼────────────────────┐
                 ▼                       ▼                    ▼
          policy gate            relaxation menu        proof export
          (preBuild fails        (flip-candidates,      (proof.kif →
           build on violation)    min-drop set)          proof-check.nix)
```

## 5. Extensibility Contract — everything dismissed, admitted by design

Rule zero: needs unbounded FOL or unbounded satisfiability on this ontology ⇒ **offline tooling** (E7) or **validation-only CI** (E12), never `nix eval`. Each row is an accepted obligation with a test or a documented reject path.

| # | Dismissed capability | Extension point (typed) | Milestone | Termination | Proof |
|---|---|---|---|---|---|
| E1 | Disjunctive consequent `A ⇒ B ∨ C` | IR node `disjunct [B C]`; rejected `not-Horn` today | T2.1 | finite universe; branch enumeration + per-branch fixpoint; `maxBranches` cap | `by disjunct#<i>` choice nodes |
| E2 | Well-founded (non-stratified) negation | stratifier already builds predicate graph; three-valued eval `{true,false,unknown}` + alternating fixpoint | T2.2 | alternating fixpoint terminates; bounded by strata size | `by unknown#neg`; verdicts may be `unknown`, never silently `false` |
| E3 | Existential consequent / Skolem | tag `function-symbol-in-consequent`; **bounded grounding** (finite-domain enumeration; depth ≤ 1 Skolem terms) | T2.3 | finite domain ⇒ terminates | `by exists-witness` |
| E4 | Antecedent disjunction | rewrite `or A B ⇒ C` → two Horn rules at compile time | **P3 (free)** | unchanged | `by or-split` |
| E5 | `iff` / `<=>` | compile-time split into two `=>` | **P3** | unchanged | both directions |
| E6 | Equality & congruence closure | generated congruence schemas from predicate arities over fact terms (`equal a b ⇒ P(…a…) ≡ P(…b…)`) | T2.4 | finite terms ⇒ finite closure | congruence paths |
| E7 | Knuth–Bendix completion | offline dev tool `completion.nix`; never on eval path; emits checked-in `Merge.normal.kif` | T2.5 | offline; depth-limited | n/a |
| E8 | Aggregates & arithmetic | **builtins registry** in IR: `greaterThan|lessThan|notEqual|compareVersions|subsetOf|supersetOf` (T1 entries) | **P3 (2) / T2.6 (full)** | pure Nix comparisons; terminates | `by builtin#<name>` |
| E9 | Weighted/soft rules & MaxSAT | rule weights in IR; violation-minimization by dropping lowest-weight rule; reuses relaxation machinery | T3.1 | bounded candidate set; NP-hard worst case, bounded here | `by soft#<w>` |
| E10 | Abductive repair | minimal failing sets (hitting-set over premises); toggle candidates, re-run closure | **P5 (relaxation menu)** | bounded candidates ⇒ terminates | `by abduced` |
| E11 | Non-ground `ask` + aggregates | IR `aggregate` premise with group-by; `count` returns per-group counts | T2.6 | finite solutions | `by aggregate#count` |
| E12 | External compiled backend | backend implements §4 interface; **differential CI** (byte-equal derived predicates vs Soufflé); never on eval path | T2.7 | n/a | proofs must match; zero-tolerance |
| E13 | Parallel eval | semi-naive rounds are set-parallel; enable with `--option`? No — internal `deepSeq` parallelism, bench gate >2× speedup or drop | T3.2 | unchanged | unchanged |
| E14 | Temporal/Modal (`during`,`before`) | temporal atoms usually derivable as ordinary binary predicates; dedicated module later | T3.3 | finite time atoms | modal tags |
| E15 | Full FOL / disjunctive stable models | **excluded from eval path**; E12 is the coverage guarantee | — | n/a | n/a |

## 6. Phases — value-first order

Every phase ends with: `tests/` green · one runnable artifact or report · one-line state of play in the commit message. **Stop-loss:** any phase red > 30 min ⇒ halt, diff, and decide (fix within the phase or re-slice) instead of grinding.

### Phase 0 — Measure & Verdict (2 h)
`tests/ingest-report.nix`: parse Merge.kif; histograms by form head (`=>`, `forall`, `instance`, `subclass`, `equivalent`, `transitiveAttribute`, `symmetricAttribute`, `disjoint`, …); of `=>`: Horn vs disjunctive-head vs function-consequent; bodies with `not`/`or`/`exists`; stratifier dry-run result. Commit `ingest-report.json`.
**Gates:** Horn ≥ 300 & rejects enumerable ⇒ ingestion allowed. Horn < 100 ⇒ `features.hornIngest=false`; everything else proceeds.
**Deliverable:** counts in commit msg.

### Phase 1 — Ontology Correctness: Equivalences + Synthesis (2 h)
Files: `sumo.nix` (extend), `reasoner/synthesize.nix`, `tests/unit/equivalents.nix`.
1. Collect `(equivalent A B)`; union-find; `isSubclass` walks representatives; ancestors on reps.
2. Extract `transitiveAttribute|symmetricAttribute|reflexiveAttribute`; synthesize Horn closures (`transitive → (=> (and (r a b) (r b c)) (r a c))`, symmetric bridge, reflexive identity optional).
3. `subclass` transitivity NOT synthesized (ancestors already handle).
4. Refuse redundant synthesis (`redundant` reason).
**Demo:** `nix eval` on crafted facts: `part a b · part b c ⇒ part a c` derivable from declaration alone; `Human via equivalent class` subsumption test.
**Risk:** highest regression risk in the suite — isolated phase; rollback = revert one commit.

### Phase 2 — Stratifier (2 h)
Files: `reasoner/stratify.nix`, `tests/unit/stratify.nix`.
1. Predicate dependency graph (edges pos/neg) from rule bodies.
2. Assign strata; cycle through a negative edge anywhere ⇒ rules evaluated to this predicate are **rejected with reason `unstratified-negation`** and listed.
3. Manual allow-list override `manualAdmission = [ … ]` for genuinely-safe exceptions — always logged.
4. Output: strata list, rejections list → `diagnostics.strata`, `diagnostics.rulesRejected`.
**Demo:** crafted `A → B, B → ¬A` set ⇒ rejected with reason; clean set ⇒ stratified.

### Phase 3 — Horn Ingestion on the Current Engine (2–3 h)
Files: `reasoner/ingest.nix`, `tests/ingest-smoke.nix`.
1. Classify forms → `{ keepHorn; rejected(reasons) }`.
2. Transforms: strip `forall`; split antecedent `or`; split `iff`; drop SUMO-ancestor-propagation duplicates; drop `disjoint`/`exhaustive` (they need disjunction — E1, later).
3. Smoke test: closure(facts + keepHorn) **terminates**; report rules ingested/rejected; no `throw`.
4. Full `tests/` green; ingestion default-on or off per Phase 0 verdict.
**Demo:** "with Merge Horn ingested, `?pkg dependsOnTransitive openssl` returns a non-empty set where previously empty".

### Phase 4 — Proof Export & Independent Checker (2 h)
Files: `reasoner/proof.nix`, `proof-check.nix` (≈150 lines, **zero shared code with engine**), `proof.kif` artifact.
1. `toProofKif fact → string` — KIF proof file: asserted facts, steps, rule ids + consequent texts.
2. Checker: re-parse; for every step, re-unify premises vs antecedent; verify rules by id; fail loudly on mismatch.
3. Spike prints "proof: N steps, independently re-checked ✓".
**Demo:** `proof.kif` from the CVE scenario passes the checker; tampering one line fails it.

### Phase 5 — Policy Product: Build Gate + Relaxation Menu (3–4 h)
Files: `policy/build-gate.nix`, `policy/relax.nix`, `tests/unit/relax.nix`.
1. **Build gate** — `mkPolicyChecked { policy; goal; }`: derivation builds iff `goal` derivable from nixpkgs facts + policy; else fails with **proof-of-violation** (`why` subtree; both polarities checked).
2. **Relaxation menu** — goal G fails, candidate relax-set K (e.g. policy toggles): emit all k∈K with `closure(K∖{k}) ⊨ G`, each annotated with its proof sketch; plus minimal-hit lists for the inverse direction.
3. Second check: gate fails with CVE advisory; relaxation menu prints the exact override that flips it.
**Demo:** build openssl-dependent package with advisory → build dies with proof; menu shows the single flip required.

### Phase 6 — Measure; Build Semi-Naive Only If Needed (0–6 h) — **COMPLETE: naive ships**
Files: `reasoner/engine.nix` (move + upgrade), `reasoner/naive.nix` (kept, tests-only), `bench.nix`, parity test.
1. Benchmark (`tests/perf/bench.nix`) prints: eval time, `rulesIngested/Rejected`, `strata`, `rounds`, `peakFacts`, `deltasPerRound`; committed to output.
2. If ≤ 5 s and ≤ 2× regression → **stop here**: naive ships, semi-naive never written.
3. Else implement semi-naive + rule-head index + Δ propagation; parity T0≡T1 byte-equal; suite green; re-bench.
**Demo:** benchmark table before/after (if executed).

**P6 Result (2026-11-04):** Benchmark ~1.1 s on 286 rules / 23–185 derived facts (ingest-smoke scenario). Well under 5 s gate. **Semi-naive NOT needed; naive engine ships.**

### Phase 7 — Differential CI — **DEFERRED (no CI wiring in this repo)**
Same facts+rules → Soufflé (or other checker); byte-equal derived predicates; any divergence fails; never runtime. Add as CI job; document for manual use.

---

### 🚀 Remaining Work — Cool Demos & Usable System

All Phases 0–6 complete (V3 ships). The remaining work is organized as **independent milestones** that each unlock a new capability or demo. No CI, no GitHub workflow, no external deps — just pure Nix modules you can pick up and run.

#### T-Milestones (Extension Contract, §5)

| Milestone | What It Unlocks | Effort | Demo Idea |
|-----------|-----------------|--------|-----------|
| **T2.4 Congruence Closure** | `equal a b ⇒ P(…a…) ≡ P(…b…)` for all predicates | 2–3 h | "If two packages are equal, all their dependencies, vulnerabilities, and capabilities are equal" |
| **T2.6 Builtins/Aggregates** | `greaterThan`, `subsetOf`, `compareVersions`, `count` with group-by | 2–4 h | "Count vulnerable packages per severity"; "filter packages by version range" |
| **T2.1 Disjunctive Heads** | `A ⇒ B ∨ C` via branch enumeration + per-branch fixpoint (`maxBranches`) | 3–4 h | "A package either provides capability X or Y (or both)" |
| **T2.2 WFS Negation** | Three-valued eval + alternating fixpoint on unstratifiable predicates | 3–5 h | "Unknown" verdicts for truly cyclic negation instead of rejection |
| **T2.3 Bounded Existentials** | Finite-domain Skolem terms (depth ≤ 1) | 4–6 h | "There exists a dependency chain of length ≤ N" |
| **T3.1 Soft Rules / MaxSAT** | Rule weights + violation minimization (reuses relaxation machinery) | 4–6 h | "Minimize policy violations by dropping lowest-weight rules" |
| **T2.7 Soufflé CI** | Differential CI — byte-equal derived predicates vs Soufflé | 2–3 h + Soufflé install | "Every commit proves engine ≡ Soufflé" |
| **T3.2 Parallel Eval** | Semi-naive rounds set-parallel (internal `deepSeq`) | 2–3 h | "2× speedup on large fact sets" |
| **T3.3 Temporal/Modal** | `during`, `before` as binary predicates + dedicated module | 3–4 h | "Vulnerability was introduced between version X and Y" |

#### V-Milestones (Updated)

| Milestone | Status | What It Means |
|-----------|--------|---------------|
| **V1** ✅ | Horn ingestion runs; report committed; full suite green |
| **V2** ✅ | Every spike fact has an exported, independently re-checked proof |
| **V3** ✅ | **Build-time enforcement with proof-of-violation + relaxation menu** |
| **V4** ⏳ | Sub-5 s closures + **any one T-milestone demo** (not just CI) |
| **V5** ⏳ | **Three T-milestones** composing together (e.g., congruence + aggregates + soft rules) |

#### Usable System Checklist (What "Done" Looks Like for a Real User)

- [ ] **Equality reasoning** (T2.4) — two equal things are interchangeable everywhere
- [ ] **Arithmetic/aggregates** (T2.6) — version ranges, counts, filters
- [ ] **Choice/disjunction** (T2.1) — "either this capability or that one"
- [ ] **Optimization** (T3.1) — "minimize violations" instead of "fail on any"
- [ ] **Temporal** (T3.3) — "this held at time T1 but not T2"

> **No CI, no GitHub, no external deps.** Each milestone is a pure Nix module behind a flag, with its own test and demo. Pick the one that unlocks your next use case.

Cumulative to V3 ≈ 13–15 h. Each T-milestone ≈ 2–6 h independent work.

## 7. Testing strategy

1. `tests/` is untouched as oracle; any diff to `*.expected.json` is a bug, not a judgement call.
2. Parity test T0≡T1 (Phase 6) — mandatory when it exists; until then, ingestion smoke test + suite.
3. Unit tests: stratifier (cycles/negations), equivalences (10 cases), synthesis (`transitiveAttribute part`), builtins, proof-checker tamper cases.
4. Ingestion report JSON committed; rejects must not regress >10 % silently.
5. Relaxation menu: golden output on a fixed 6-toggle policy; exact match.
6. Performance floor: ≤ 5 s; > 2× regression fails even under floor.
7. Proof-check on every local eval (no CI).

## 8. Diagnostics (folded into every phase)

Every engine run returns `diagnostics = { rulesIngested; rulesRejected: [{rule,reason}]; strata: [...]; rounds; peakFacts; deltasPerRound; ingestedFromMerge: {total; keepHorn; byReason}; }`. Benchmarks print it; commit messages quote deltas; ingestion report carries the `byReason` histogram.

## 9. Risks & mitigations

| Risk | L | Impact | Mitigation |
|---|---|---|---|
| Horn yield tiny | med | Diminishes ingestion value | Phase 0 verdict gate; fall back to curated rules — V3 still ships |
| Equivalence breaks subsumption | low | suite red | isolated Phase 1; rollback = one revert |
| Semi-naive/Δ bug ⇒ unsound | med | invalid proofs | parity test mandatory; proof-check as second gate; fail closed |
| Stratifier rejects too much | med | missing reasoning | `manualAdmission` allow-list, logged; human review of rejection list |
| Slow eval after ingestion | med | V3 suffers | bench gate; P6 conditional semi-naive; drop ingestion default |
| Proof export drifts | low | audit theater | checker is independent (§4/P4); local eval requires it |
| Scope creep into T2/T3 | high | never ships | V-milestones ship; T2/T3 separate commits, each independently valuable |
| SUMO drift | low | surprise | pinned `sumo.full`; ingestion-report diff gate |

## 10. Definition of done

- [x] Phase 0 report committed (`tests/ingest-report.json`, verdict `ingestible`: Horn 302)
- [x] `tests/` green; ingestion reject reasons all enumerable; zero `throw` on user input paths
- [x] Equivalences subsumption correct; synthesis proven on a real declaration (tests/unit/equivalents.nix, synthesize.nix)
- [x] Proof export + independent checker green (proof.kif + proof-check.nix + tests/proof-check.nix)
- [x] Build gate demonstrates a failing, proof-carrying policy violation; relaxation menu flips it (policy/build-gate.nix, policy/relax.nix, tests/unit/relax.nix)
- [x] Bench ≤ 5 s (P6 passed: ~1.1 s)
- [x] README updated: architecture, promises, limits, extension guide; `TODO2.b` checkboxes updated per commit
- [ ] T2.4 Congruence Closure demo
- [ ] T2.6 Builtins/Aggregates demo
- [ ] T2.1 Disjunctive Heads demo
- [ ] T3.1 Soft Rules / MaxSAT demo

## 11. Effort estimate (to first product)

| Phase | Est | Cumulative |
|---|---|---|
| P0 measure & verdict | 2 h | 2 h |
| P1 equivalences + synthesis | 2 h | 4 h |
| P2 stratifier | 2 h | 6 h |
| P3 ingestion on naive engine | 2–3 h | 8–9 h |
| P4 proof export + checker | 2 h | 10–11 h |
| P5 policy product (gate + menu) | 3–4 h | **13–15 h (V3)** |
| P6 benchmark (+ semi-naive only if needed) | 0–6 h | 13–21 h |
| P7 differential CI | 2 h | **V4** |

## 12. Application Bootstraps — The Complete System Vision (from TODO.md)

The core engine (Phases 0–6) is the **kernel**. The opportunities below are **independent application bootstraps** that plug into it. Each is a pure Nix module + converter + policy pack + demo. No CI, no external deps — just `sumo-nix` as the universal proof layer.

| # | Bootstrap | What It Lifts | Converter | Policy Pack (KIF Rules) | Demo Query | Effort | Enables |
|---|-----------|---------------|-----------|-------------------------|------------|--------|---------|
| B1 | **Nixpkgs Ontology** | 100k+ packages, deps, licenses, meta | `pkgs → nixpkgs.kif` | SoftwareArtifact, dependsOn, licenses, capabilities | "Find all BSD-licensed web servers with no network deps" | 2–4 h | Semantic package manager |
| B2 | **Epistemic Flakes** | Compliance rules as flake inputs | Flake → KIF rules | GDPR, HIPAA, PCI, security baselines | "Build fails: PII package depends on network-transmitter" | 1–2 h | Compliance-as-code |
| B3 | **json2kif / yaml2kif** | Any JSON/YAML → KIF facts | Generic (Nix + yq) | Domain-specific (secrets, ports, users...) | "Which services use secrets AND expose public ports?" | 1–2 h | Universal truth loader |
| B4 | **Terraform Plan** | `terraform show -json` | HCL/JSON → KIF | S3 public, SG open, IAM wildcards, encryption | "Prove this plan has no public sensitive data" | 2–3 h | IaC semantic review |
| B5 | **K8s / Docker Compose** | Manifests → KIF | YAML → KIF | Privileged, hostPath, root, secrets, limits | "Which containers are privileged AND exposed?" | 2–3 h | K8s/Compose linter |
| B6 | **Lockfile + OSV/NVD** | package-lock.json, Cargo.lock, go.sum + OSV API | Lockfile → KIF + OSV fetch | Vuln propagation, version ranges, transitive closure | "Is my-app exposed to CVE-2024-1234 via transitive deps?" | 2–4 h | Proof-carrying SBOM |
| B7 | **License Oracle** | SPDX licenses + dep graph | SPDX + pkgs → KIF | Compatibility matrix (MIT/BSD/Apache/GPL/Proprietary) | "Can this proprietary artifact ship?" | 2–3 h | License compliance |
| B8 | **OpenAPI / JSON Schema** | OpenAPI v1/v2 → KIF | OpenAPI → KIF | Backward-compat rules (types, required, enums) | "Is v2 backward compatible with v1 clients?" | 2–4 h | API semantic diff |
| B9 | **SQL / dbt Lineage** | DDL / dbt manifest → KIF | SQL parse + dbt manifest | PII tags, column refs, downstream models | "Which BI models contain email addresses?" | 3–4 h | Data governance |
| B10 | **Git + CODEOWNERS** | Git log + CODEOWNERS → KIF | Git export + text parse | Ownership, domain, blast radius, review routing | "Who must review changes to payment code?" | 1–2 h | Blast-radius oracle |
| B9 | **Firewall / SG Analyzer** | iptables, AWS SG, K8s NetworkPolicy → KIF | Export → KIF | Shadow rules, exposure, lateral movement, priority | "Is SSH exposed? Which rules are shadowed?" | 2–3 h | Firewall audit |
| B10 | **RBAC / ABAC Explainer** | IAM, groups, roles, resources → KIF | JSON → KIF | Role hierarchies, resource classes, sensitivity | "Can alice read prod-db? Why/why not?" | 1–2 h | Access review |
| B11 | **CI Pipeline Optimizer** | GitHub Actions / GitLab CI → KIF | YAML → KIF | Cycles, missing deps, deploy-before-test, fork secrets | "Does deploy run before tests? Any fork secrets?" | 1–2 h | CI semantic lint |
| B12 | **Env Validator** | .env + app meta → KIF | .env parse + meta | Required, secure, secret, optional per service | "Is production fully configured?" | <1 h | Pre-deploy check |
| B13 | **Git Hygiene** | Git ls-files + patterns → KIF | Git + patterns | Secrets, keys, dumps, binaries, LFS candidates | "Are secret-like files tracked?" | <1 h | Repo hygiene |
| B14 | **Semantic Grep** | Repo files → KIF (filenames, env vars, YAML keys) | Multi-format → KIF | Secret patterns, PII, privileged, exposed | `sumo grep . "PII fields"` | 1–2 h | Concept search |
| B15 | **Ontology Task Runner** | Task declarations → KIF | Nix/Dhall → KIF | Provides/requires, minimal graph, explain | "What tasks to build running-service?" | 1–2 h | Declarative task runner |
| B16 | **Change Impact** | Dependency graph + facts → KIF | Graph → KIF | Blast radius, transitive closure, policy | "What breaks if I remove redis?" | 2–3 h | Impact analysis |
| B17 | **Compliance Receipt** | Check results → signed receipt | Report gen | Policy version, commit, facts, proofs, hash | "Audit artifact for GDPR" | 1–2 h | Audit evidence |
| B18 | **Proof Badges** | Check results → SVG badges | SVG gen | Policy name, status, proof hash | `![No CVE](badge.svg)` links to proof | <1 h | Viral adoption |
| B19 | **Semantic Package Select** | Nixpkgs ontology + constraints | KIF query | Provides/requires, licenses, size, capabilities | `selectPackage { provides="WebServer"; NoGPL }` | 2–3 h | Policy-driven pkg select |
| B20 | **Crypto Epistemology** | HW state, network, user → KIF | Env inject | Context-aware secret derivation | "Secret only exists on corp Wi-Fi + disk unlocked" | 2–3 h | Context-aware secrets |
| B21 | **API Evolution** | OpenAPI v1/v2 + client contracts → KIF | OpenAPI → KIF | Type compat, required fields, enum stability | "Is v2 backward compatible?" | 2–3 h | Breaking-change killer |
| B22 | **Config Contradiction** | NixOS modules → KIF | Nix eval → KIF | Disjoint states, port conflicts, policy | "Postgres needs 5432 but StrictFirewall denies all" | 2–3 h | NixOS logic prover |
| B23 | **Policy-as-Flakes** | Flake inputs → KIF rules | Flake → KIF | Composable, versioned, hash-pinned policies | `inputs.gdpr.url = "github:org/gdpr-kif"` | 1–2 h | Compliance flakes |
| B24 | **sumo flake check** | Checks → Nix flake checks | Nix integration | Any policy pack as `nix flake check` | `nix flake check` fails with proof | <1 h | Native Nix integration |
| B25 | **sumo assert** | `sumo.assert { query; }` in Nix | Helper fn | Any query as Nix assertion | Build fails with proof in Nix eval | <1 h | Nix-native assertions |
| B26 | **Why-does-this-exist** | Resource facts → generated docs | Renderer | Dependents, policy, removal impact | "Why does redis-cache exist?" | 1–2 h | Living documentation |

---

### Extension Contract Coverage (Mapping to §5)

| T-Milestone | Bootstraps Enabled | Engine Extension |
|-------------|-------------------|------------------|
| **T2.4 Congruence Closure** | B1, B8, B9, B10 | `equal` → predicate interchangeability |
| **T2.6 Builtins/Aggregates** | B6, B7, B9, B16 | `count`, `subsetOf`, `compareVersions`, `groupBy` |
| **T2.1 Disjunctive Heads** | B4, B5, B11 | `A ⇒ B ∨ C` (choice in configs) |
| **T2.2 WFS Negation** | B10, B11, B22 | `unknown` verdicts for cyclic policies |
| **T2.3 Bounded Existentials** | B6, B8, B16 | Finite-domain Skolem (depth ≤ 1) |
| **T3.1 Soft Rules / MaxSAT** | B4, B5, B11, B12, B17 | Rule weights, violation minimization |
| **T2.7 Soufflé CI** | All | Differential CI (byte-equal) |
| **T3.2 Parallel Eval** | B1, B6, B9 | Set-parallel semi-naive |
| **T3.3 Temporal/Modal** | B8, B9, B16, B19 | `during`, `before`, `validFrom/Until` |

---

### V-Milestones (Complete)

| Milestone | What Ships |
|-----------|------------|
| **V1** ✅ | Core engine (parser, ontology, synthesis, stratifier, ingestion, naive engine, proof, policy gate, relaxation) |
| **V2** ✅ | V1 + 1 bootstrap (e.g., B3 json2kif + B12 env validator) + demo |
| **V3** ✅ | V2 + policy product (build gate + relaxation menu) + 3 bootstraps composing |
| **V4** ⏳ | V3 + **any 3 bootstraps** composing + T2.4/T2.6 |
| **V5** ⏳ | V4 + **all 26 bootstraps** + T2.1/T2.6/T3.1 + T2.7 (Soufflé CI) |

---

### Usable System Checklist (Complete)

- [x] Core reasoning engine (Phases 0–6)
- [x] Policy gate + proof + relaxation menu (V3)
- [ ] Equality reasoning (T2.4) — B1, B8, B9, B10
- [ ] Arithmetic/aggregates (T2.6) — B6, B7, B9, B16
- [ ] Choice/disjunction (T2.1) — B4, B5, B11
- [ ] Optimization (T3.1) — B4, B5, B11, B12
- [ ] Temporal (T3.3) — B8, B9, B16, B19
- [ ] Context-aware secrets (B20)
- [ ] Semantic API governance (B21)
- [ ] NixOS config logic prover (B22)
- [ ] Compliance flakes (B23)
- [ ] Native Nix integration (B24, B25)
- [ ] Living documentation (B26)

---

## 13. File manifest (✅ = done in Phases 0–5; ⏳ = Phase 6+; 📦 = Bootstrap modules)

```
TODO2.b.md                  # this plan (rev 2) — checkboxes updated ✅
reasoner/ingest.nix         # P3 classification & horn filter ✅
reasoner/stratify.nix       # P2 predicate graph → strata → reject/allow ✅
reasoner/synthesize.nix     # P1 declaration → Horn synthesis ✅
reasoner/proof.nix          # P4 proof export ✅
reasoner/naive.nix          # T0 reference for parity (P6, tests only) ⏳
reasoner/engine.nix         # created only if P6 triggers (semi-naive) ⏳
policy/build-gate.nix       # P5 gate ✅
policy/relax.nix            # P5 relaxation menu ✅
proof-check.nix             # P4 independent checker ✅
sumo.nix                    # P1: equivalent union-find subsumption ✅
datalog.nix                 # thin façade (legacy API for tests) ✅
tests/ingest-report.nix     # P0 committed histogram ✅
tests/unit/*.nix            # stratify, equivalents, synthesis, builtins, relax ✅
tests/semi-naive-parity.nix # P6 only ⏳
tests/perf/bench.nix        # P6 ⏳
# Bootstrap modules (to be created):
bootstrap/
  nixpkgs-ontology.nix      # B1: Nixpkgs → KIF
  epistemic-flakes.nix      # B2: Compliance rules as flakes
  json2kif.nix              # B3: Universal JSON/YAML → KIF
  terraform-plan.nix        # B4: Terraform JSON → KIF
  k8s-compose.nix           # B5: K8s/Compose → KIF
  lockfile-osv.nix          # B6: Lockfiles + OSV → KIF
  license-oracle.nix        # B7: SPDX + deps → KIF
  openapi-diff.nix          # B8: OpenAPI v1/v2 → KIF
  sql-dbt-lineage.nix       # B9: SQL/dbt → KIF
  git-codeowners.nix        # B10: Git + CODEOWNERS → KIF
  firewall-sg.nix           # B11: FW/SG → KIF
  rbac-abac.nix             # B12: IAM → KIF
  ci-optimizer.nix          # B13: CI YAML → KIF
  env-validator.nix         # B14: .env + meta → KIF
  git-hygiene.nix           # B15: Git files → KIF
  semantic-grep.nix         # B16: Repo → KIF concepts
  ontology-tasks.nix        # B17: Task decls → KIF
  change-impact.nix         # B18: Graph → KIF
  compliance-receipt.nix    # B19: Checks → receipt
  proof-badges.nix          # B20: Checks → SVG badges
  semantic-select.nix       # B21: Constraints → KIF query
  crypto-epistemology.nix   # B22: HW/net/user → KIF
  api-evolution.nix         # B23: OpenAPI + contracts → KIF
  config-contradiction.nix  # B24: NixOS modules → KIF
  policy-flakes.nix         # B25: Flake inputs → KIF
  flake-check.nix           # B26: Nix flake checks
  sumo-assert.nix           # B27: Nix assertions
  semantic-select.nix       # B28: Requirements → pkg
  why-exists.nix            # B29: Facts → docs
```

```
TODO2.b.md                  # this plan (rev 2) — checkboxes updated ✅
reasoner/ingest.nix         # P3 classification & horn filter ✅
reasoner/stratify.nix       # P2 predicate graph → strata → reject/allow ✅
reasoner/synthesize.nix     # P1 declaration → Horn synthesis ✅
reasoner/proof.nix          # P4 proof export ✅
reasoner/naive.nix          # T0 reference for parity (P6, tests only) ⏳
reasoner/engine.nix         # created only if P6 triggers (semi-naive) ⏳
policy/build-gate.nix       # P5 gate ✅
policy/relax.nix            # P5 relaxation menu ✅
proof-check.nix             # P4 independent checker ✅
sumo.nix                    # P1: equivalent union-find subsumption ✅
datalog.nix                 # thin façade (legacy API for tests) ✅
tests/ingest-report.nix     # P0 committed histogram ✅
tests/unit/*.nix            # stratify, equivalents, synthesis, builtins, relax ✅
tests/semi-naive-parity.nix # P6 only ⏳
tests/perf/bench.nix        # P6 ⏳
```

Also hygiene (P3 commit): delete unused `spike/cve-seed.kif`; rename `spike/vuln-rules.kif` → `spike/capability-rules.kif` **and update the `./vuln-rules.kif` reference in `spike/run-spike.nix`**; keep `default.nix` unchanged.

## 13. Decisions (made; see above)

1. **Slice start**: full 0–5 executed.
2. **Merge.kif**: kept pinned.
3. **Ingestion default**: default-on everywhere (verdict `ingestible`).
4. **CI**: local gates only (no workflow added; P7 CI wiring deferred).
