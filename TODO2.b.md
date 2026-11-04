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
| **V4** ⏳ | Sub-5 s closures + **any one T-milestone demo** (not just CI) — **T2.4 Congruence Closure rule generation complete** |
| **V5** ⏳ | **Three T-milestones** composing together (e.g., congruence + aggregates + soft rules) |

#### Usable System Checklist (What "Done" Looks Like for a Real User)

- [x] **Equality reasoning** (T2.4) — rule generation complete; engine integration requires iterative fixpoint
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
- [x] T2.4 Congruence Closure demo (reasoner/congruence.nix + tests/unit/congruence.nix; rule generation complete; engine integration blocked by naive fixpoint recursion limit — requires iterative fixpoint or recursion limit increase)
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

## 12. Extension Contract Coverage (Mapping to §5)

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

### V-Milestones

| Milestone | What Ships |
|-----------|------------|
| **V1** ✅ | Core engine (parser, ontology, synthesis, stratifier, ingestion, naive engine, proof, policy gate, relaxation) |
| **V2** | V1 + **1 bootstrap** (e.g., B3 json2kif + B12 env validator) + demo |
| **V3** ✅ | V2 + policy product (build gate + relaxation menu) + **3 bootstraps** composing |
| **V4** ⏳ | V3 + **3 bootstraps** composing + T2.4/T2.6 |
| **V5** ⏳ | V4 + **all 26 bootstraps** + T2.1/T2.6/T3.1 + T2.7 (Soufflé CI) |

---

### Usable System Checklist

- [x] Core reasoning engine (Phases 0–6)
- [x] Policy gate + proof + relaxation menu (V3)
- [x] Equality reasoning (T2.4) — rule generation complete; engine integration requires iterative fixpoint
- [ ] Arithmetic/aggregates (T2.6)
- [ ] Choice/disjunction (T2.1)
- [ ] Optimization (T3.1)
- [ ] Temporal (T3.3)
- [ ] Context-aware secrets
- [ ] Semantic API governance
- [ ] NixOS config logic prover
- [ ] Compliance flakes
- [ ] Native Nix integration
- [ ] Living documentation

---

Also hygiene (P3 commit): delete unused `spike/cve-seed.kif`; rename `spike/vuln-rules.kif` → `spike/capability-rules.kif` **and update the `./vuln-rules.kif` reference in `spike/run-spike.nix`**; keep `default.nix` unchanged.

## 13. Decisions (made; see above)

1. **Slice start**: full 0–5 executed.
2. **Merge.kif**: kept pinned.
3. **Ingestion default**: default-on everywhere (verdict `ingestible`).
4. **CI**: local gates only (no workflow added; P7 CI wiring deferred).
