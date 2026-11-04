# TODO2.b — The Reasoner: Build a Capable Heavy-Duty SUMO Reasoner

**Status:** New plan (supersedes the "trim Phase 3 / reasoner = plumbing" framing in TODO2.a's §12).
**Owner decision needed:** approve Phases 0–2 as one slice, or Phase 0 alone (measurement first). See §13.
**Non-negotiable:** existing tests (`nix eval -f tests/` or `tests/default.nix`) stay green at every step; every unsupported input is **rejected with an explicit reason**, never silently dropped.

---

## 1. Mission

Build, inside `sumo-nix`, a reasoner that:

1. Is **capable**, not just correct on the demo: semi-naive Datalog with rule-head indexing, stratified negation-as-failure, temporally safe defaults — fast enough for the real universe (all of `sumo.full/Merge.kif`, with Horn ingestion).
2. Is **SUMO-native**: `instance` subsumption through the ontology (incl. `equivalent` classes), automatic synthesis of rules from SUMO's own `transitiveAttribute` / `symmetricAttribute` / `reflexiveAttribute` declarations, and ingestion of the Horn fragment of Merge.kif as rules — no hand-curation of hundreds of axioms.
3. Exports **audit-grade proofs**: every derived fact carries provenance; `explain` emits SUO-KIF-valid proof trees that an external checker can validate; the engine can be differentially tested against an external backend (Soufflé).
4. Is **expandable to the full feature set** — including everything this project historically dismissed — via an explicit **Extensibility Contract** (§5): disjunctive consequents, well-founded (non-stratified) negation, existential/Skolem handling, congruence closure and Knuth–Bendix completion, aggregates and comparisons, weighted/soft rules (MaxSAT), external compiled backends. Nothing is admitted by accident; everything is either (a) implemented with tests, or (b) a typed, documented extension point with a milestone and a termination guarantee.
5. Delivers **policy value**: a build-time gate (FAIL the build on policy violation) and a relaxation menu (minimum facts to assert to flip the verdict) — features only possible with a proof-tracking reasoner.

## 2. Where We Stand (T0)

Baseline (committed `a310e08`):

- `kif.nix` — KIF tokenizer/parser; handles comments, strings, nested lists; produces s-expression lists. Solid; will be extended, not replaced.
- `sumo.nix` — builds `{ ontology, isSubclass, ancestors, classOf }` from parsed forms; `ancestors` memoizes subclass chains; `isSubclass` does strict-ancestor walk. **No `equivalent` handling.**
- `datalog.nix` — forward-chaining Horn engine (~130 lines).
  - Supported premise forms: `and`, `exists` (body-only), `not` (negation-as-failure), `equal`, `instance` (subsumption via ontology), ordinary ground-fact unification.
  - Consequent: single atom, must be ground under bindings (else `throw`).
  - Evaluation: **naive** — `derive` (datalog.nix:81-94) re-fires ALL rules against the FULL fact set every round; `index` is rebuilt per round; rules are not indexed by head.
  - Provenance: every derived fact records `{ rule = "<head>#<n>"; from = [<keys>] }` — a complete proof DAG; `why`/`explain` render trees.
  - `instance` special-case prefilters via `isSubclass` — correct, but the biggest Merge.kif lever (Horn ingestion) is unused: the ontology's 1,065 Horn rules (`(=> …)`) are **not** evaluated, only class metadata is used.
- `tests/` — the golden reference semantics:
  - `tests/default.nix` — corpus checksums consulted as gates: `kif.parse` 5505 top-level forms, 714 classes / 712 with parents, `ancestors.Human` golden list, `classOf.part` golden, `instance`-subsumption checks.
  - `tests/rules.nix`, `tests/scenario.nix` — the CVE-provenance scenario over `Merge.kif + nix-domain.kif` (shared module, exercised on KIF-text facts and via `rules.nix`); checks advisory on openssl reaching curl/nginx/app, `NoCriticalRunningCVE` for the running service, untouched hello.
  - `tests/bags.nix`, `tests/decide.nix`, `tests/hf.nix`, `tests/org.nix`, `tests/pyai.nix` — independent Python/jq oracles (`tests/*-oracle.py`, `org/oracle.jq`, committed `*.expected.json`) cross-checke against our checkers; these pin taxonomy decisions over external corpora.
  - All are “eval → `\"ok\"`” gates. **This suite is the oracle for every engine change.**
- `sumo.full/Merge.kif` — ~632 KB, ~19,084 lines, **1,065 `=>` forms**, **84 top-level `forall` forms** (plus nested). Whether ≥1/3 is admissible Horn is **unverified** — hence Phase 0.
- `spike/` — capability-discovery demo works (6/10/2 results; `e.explain` proof trees). It is the CLI prototype, not the product.

### 2.1 Measured gaps blocking "fully leverage SUMO"

| # | Gap | Evidence |
|---|---|---|
| G1 | Engine never applies Merge.kif's Horn axioms | `ontology` object consumed only via `isSubclass`; `rules` param unused by Merge |
| G2 | Naive evaluation → O(rules × facts × rounds) | `derive` iterates `named` rules unfiltered; `index` rebuilt per round |
| G3 | Subsumption ignores `equivalent` classes | `isSubclass` walks `ancestors` only; SUMO equivalences are invisible |
| G4 | No declaration synthesis | `transitiveAttribute` et al. are not parsed into rules |
| G5 | No stratification analysis | `not` is ad hoc; non-Horn Merge forms would loop or be dropped silently |
| G6 | No termination safeguards | No function-symbol check; no rule-size/atom cap; no reject report |
| G7 | No operational artifacts for policy | No build gate; no relaxation menu; proofs not exportable as standalone KIF |

## 3. Non-Negotiable Design Goals

1. **Soundness (audit):** every derived fact is checkable — replayable against `kif.nix` + the source forms. No fact exists without `by`/`from` (asserted facts: `asserted = true`).
2. **Termination (guaranteed for T1):** finite Herbrand universe; consequent atoms ground; no function symbols admitted; proof depth bounded by rule count × fact count.
3. **Determinism:** least-model semantics, set semantics per round; result independent of rule order and fact order.
4. **Closed world:** absence of derivation ⇒ false, with negation-as-failure evaluated only in strata where the predicate is fully derived (stratification enforced).
5. **Honesty of rejection:** anything the engine cannot settle is **rejected with a reason** (`not-Horn`, `unstratified-negation`, `function-symbol-in-consequent`, …). Never silently ignored.
6. **Test-gated evolution:** `tests/` green on every commit; every new capability ships with tests; both-engine parity check (T0 vs T1).
7. **Minimal dependencies:** pure Nix; zero new runtime deps; optional CI extras (dif. testing vs Soufflé) never on the eval path.

## 4. Target Architecture

```
        KIF source files
   (Merge.kif, nix-domain.kif, policy.kif, seeds)
                  │
                  ▼
   ┌───────────────────────────┐
   │ 0. ingest.nix (NEW)        │  parse → classify → validate
   │   → ontology candidates     │  (subclass / equivalent /
   │   → horn rules              │   instance / relation decls)
   │   → rejected (with reasons) │
   └───────────────────────────┘
                  │
        ┌─────────┴─────────┐
        ▼                   ▼
  ontology.nix          rules compiler (synthesize.nix)
  (equivalents          (declarations → Horn rules;
   union-find,          (=>) ingestion w/ stratum filter)
   subsumption)                │
        ▼                   ▼
   ┌──────────────────────────────┐
   │ engine.nix (T1 core)          │  semi-naive Δ propagation;
   │  • rule-head index            │  stratified NAF; builtins registry;
   │  • strata analyzer            │  provenance (by/from + rule source)
   └──────────────────────────────┘
                  │
        ┌─────────┼───────────┐
        ▼         ▼           ▼
  policy gate   relaxation   proof export
  (preBuild)    menu         (proof.kif +
                              external checker)
```

Interfaces are **narrow and total** — every layer can be replaced without touching callers:

- `ingest.classify : [forms] → { ontologyCandidates; horn; disjunctive; rejected; }`
- `engine.run : { ontology; rules; facts; builtins ? []; features ? {} } → { facts; holds; ask; why; explain; diagnostics; }`
- `policy.check : { goal; candidates } → { verdict; hits; }` (candidates = togglable facts; used by relaxation menu)

`datalog.nix` remains the **façade** re-exporting `engine.run` under the legacy attribute names (`closure`, `holds`, `ask`, `why`, `explain`) — existing tests and callers are untouched.

### 4.1 Engine internals (T1)

1. **IR** — each rule compiles to `{ id, stratum, headSym, binds, body: [premise], source }`.
   `premise ::= and [t] | exists t | not t | equal a b | instance v C | atom t | builtin(name, args)`.
2. **Index** — per round: `byHead`/`byFirst` for facts (as today) **plus `byConsequentHead`** for rules; delta (Δ) sets per predicate; a round fires only rules whose premise heads intersect Δ (semi-naive).
3. **Stratifier** — dependency graph over predicates with a boolean per edge: `pos` or `neg`. Classes: `stratum(pred) = 1 + max(stratum(dep))` over pos edges; any negative edge crossing strata → **reject rule with reason `unstratified-negation`** (T1) — logged, excluded, *never* silently included. In T3 the same analyzer outputs **stratification strata** consumed by the WFS solver (§8.4).
4. **Groundness/function-symbol guard** — consequent must be ground under bindings (today's `throw` becomes a **reject with reason** recorded in diagnostics; tests cover it). Any atom containing a function symbol (`(f …)` in an argument position where SUMO uses a non-relation constant) that would grow the Herbrand universe is rejected (`function-symbol-in-consequent`). NOTE: SUMO predicate constants like `(instance …)` are *relations*, never functions — only atoms with arity > 0 appearing in argument position are flagged; this is verified against Merge.kif in Phase 0 measurement.
5. **Builtins registry** — `equal` (exists), `greaterThan|lessThan|greaterOrEqual|lessOrEqual`, `notEqual`, `subsetOf|supersetOf` (set predicates via `listToSet`), `stringConcat`, `spdxCompare` (shells to `nix eval` of planned derivations? NO — pure Nix `builtins.compareVersions` only, no exec). Each builtin emits provenance tag `by builtin#<name>`; registry is extensible; every builtin ships unit tests + determinism notes.
6. **Diagnostics** — engine returns `diagnostics = { rulesIngested; rulesRejected; strata; rounds; peakFacts; deltasPerRound; }`; printed by benchmarks; machine-readable (`--json`) for CI.

### 4.2 Ontology layer (T1)

1. **`isSubclass` via equivalence-aware union-find** — collect `(equivalent A B)` pairs from parsed forms; coalesce or bridge; subsumption walks the union-find, not a plain tree. Union-find cost ~O(α(n)); tests MUST remain green (this is the highest regression risk — see Phase 2 rollback).
2. **Declaration extraction** — `transitiveAttribute rel`, `symmetricAttribute rel`, `reflexiveAttribute rel` → record relation specs; synthesize Horn closures per spec (below).
3. **Synthesized rules** —
   - `transitiveAttribute r` ⇒ `(=> (and (r ?a ?b) (r ?b ?c)) (r ?a ?c))`
   - `symmetricAttribute r` ⇒ `(=> (r ?a ?b) (r ?b ?a))`
   - `reflexiveAttribute r` ⇒ `(=> (r ?a ?a) (r ?a ?a))` (identity — present for completeness; usually absorbed by seeds)
   - `equivalentPredicate r s` (if present in Merge) ⇒ bridge rules both ways.
   - NO synthesis for `antiTransitive` / `asymmetric` (contravariant; require pairwise checks — deferred to T3).
   - Synthesized rules carry provenance `by synthesized#transitive#part`.
4. **`subclass` transitivity** — already handled by the ontology's `ancestors`; do NOT synthesize `subclass` Horn (would double-derive).

## 5. The Extensibility Contract — everything I dismissed, admitted by design

This section is the answer to "ensure the reasoner can be expanded to include all features". Each entry states: **limit today**, **extension point**, **milestone**, **termination posture**, **proof handling**. Nothing below is "we could maybe one day". Each row is an accepted obligation with a test or a documented reject path.

| # | Dismissed capability | Extension point (typed) | Milestone | Termination | Proof |
|---|---|---|---|---|---|
| E1 | **Disjunctive consequents** `A ⇒ B ∨ C` | IR node `disjunct [B C]` — rejected `not-Horn` today | T2.1 | finite Herbrand universe; enumeration splits into branches; branch-local fixpoints; optional cap `maxBranches` | `by disjunct#<i>` choice nodes; answer set enum |
| E2 | **Well-founded (non-stratified) negation** | stratifier already computes the dependency graph; three-valued evaluation `{true,false,unknown}` + alternating fixpoint | T2.2 | alternating fixpoint terminates (polynomial per iteration, ≤ 2 iterations for local strata; bounded by strata size) | `by unknown#neg` markers; verdicts may be `unknown`, never silently `false` |
| E3 | **Existential consequents / Skolem funcs** | compile-time tag `function-symbol-in-consequent`; **bounded grounding** mode (enumerate finite domain constants; refuse nested Skolem terms beyond depth 1) | T2.3 | finite domain grounding ⇒ terminates; infinite terms rejected with reason | `by exists-witness` nodes |
| E4 | **Antecedent disjunction** | rewrite `(or A B) ⇒ C` ⇒ two Horn rules; provenance `by or-split` | **T1** (free) | unchanged | shared |
| E5 | **`iff` / `<=>`** | split into two `=>` at compile time | **T1** | unchanged | both ways |
| E6 | **Equality & congruence closure** (i.e. reasoning *through* `equal` atoms inside derived facts) | premise `equal` exists; add **congruence rule schema** generated per predicate arity: `equal a b ⇒ P(…a…) ≡ P(…b…)` — generator over Merge's predicate arities | T2.4 | congruence closure is finite (terms from facts) | congruence paths |
| E7 | **Knuth–Bendix completion** (disequalities, rewrite ordering) | offline dev tool `completion.nix` — never on eval path; rewrites Merge axioms into canonical form; output is checked-in `Merge.normal.kif` | T2.5 | offline; bounded by completion depth limit | n/a (preprocessing) |
| E8 | **Aggregates & arithmetic** (`greaterThan`, `compareVersions`, counts) | **builtins registry** (already in IR) — new entries only, no engine change | **T1** (2 builtins) / T2.6 (full set) | sound & terminating: pure Nix comparisons over finite values | `by builtin#<name>` |
| E9 | **Weighted/soft rules & MaxSAT** `A ⇒ᴡ B` (weight w) | rule weights in IR; violation-minimization loop (drop/relax lowest-weight rule flip); reuses relaxation menu machinery | T3.1 | NP-hard worst case; bounded candidate set ⇒ finite; cache `regret` per rule | `by soft#<w>`; costs exported |
| E10 | **Abductive repair** (directly buildable on proofs) | assertion order irrelevant; enumerate minimal failing sets (hitting-set over failing premises); flip candidate facts one at a time (k × closure cost) | **T1.5** (relaxation menu) | bounded candidates ⇒ terminates | `by abduced` nodes |
| E11 | **Non-ground `ask` with aggregates** | registry entry `count ?x (pred…)…` — needs multi-solution aggregation; IR gains `aggregate` premise with group-by | T2.6 | finite solutions ⇒ terminates | `by aggregate#count` |
| E12 | **External compiled backend** (Soufflé IFD) | backend implements interface §4 (`run`); **differential CI** checks T1 vs Soufflé outputs byte-equal on Merge closure; never on eval path | T2.7 / CI | n/a (validation only) | proofs **must** match or zero-tolerance failure |
| E13 | **Concurrency / parallel eval** | semi-naive rounds are already set-parallel; map per-branch with `builtins.deepSeq`; benchmark gate fires only if >2× speedup retained | T3.2 | unchanged | unchanged |
| E14 | **Temporal/Modal extensions** (SUMO `during`, `before`) | IR tag `temporal`; derived from `timeInterval` classes; engine treats temporal atoms as ordinary predicates first, then dedicated module T3.3 | T3.3 | unchanged (finite time atoms) | modal provenance tags |
| E15 | **Full FOL / disjunctive stable models** | **Deliberately excluded** from eval path; E12 differential CI is the coverage guarantee; any need escalates to the completion tooling (E7) or external prover artifacts | — | n/a | n/a |

**Rule zero:** if a requested feature needs a logic with unbounded terms or non-decidable satisfiability on this ontology, it lives in **offline tooling** (E7) or **validation-only CI** (E12), never in `nix eval`.

## 6. Phased Execution Plan

### Phase 0 — Measure & Decide (2 h)

**Goal:** know exactly what Merge.kif contains before committing to ingestion.

- `tests/ingest-report.nix` (new): parses `sumo.full/Merge.kif`; outputs JSON histogram:
  - count of forms by head symbol: `=>`, `forall`, `instance`, `subclass`, `equivalent`, `transitiveAttribute`, `symmetricAttribute`, `reflexiveAttribute`, `disjoint`, `exhaustive`, `part`, …
  - of `=>` forms: Horn vs disjunctive-head vs function-symbol consequents; bodies containing `not`, `or`, `exists`; stratification candidates (negated predicates also derived elsewhere);
  - `(forall (?X …)` wrappers peel-able (yes/no cases).
- Verdict gates:
  - Horn ≥ 300 rules AND rejects enumerable → proceed to Phase 1 with ingestion **enabled by default** (but always logged).
  - Horn < 100 → ingestion OPTIONAL (`features.hornIngest = false`); still ship Phases 1–4 (they pay off regardless).
- Deliverable: `tests/ingest-report.json` committed; numbers quoted in commit message.

### Phase 1 — Engine Core T1 (4–6 h)

**Files:** `reasoner/engine.nix` (moved from `datalog.nix`, same API via façade), `reasoner/stratify.nix`, `tests/semi-naive-parity.nix`, `tests/unit/stratify.nix`.

1. Semi-naive evaluation:
   - per-predicate Δ; round fires rules whose premise-head symbols intersect Δ ∪ previous Δ;
   - stop when Δ empty; track `rounds`.
2. Rule-head index: `rulesByHead` attrset; lookup per head, not linear scan.
3. Stratifier module with unit tests: chains (`A→B, B→¬A` ⇒ reject), independent strata, self-negated (`A, A ∧ ¬A ⇒ A` ⇒ reject — unground negation).
4. Groundness failures become **rejection entries** in `diagnostics.rulesRejected` instead of `throw`.
5. Builtins registry v1: `equal` (kept), `greaterThan`, `lessThan`, `notEqual`, `compareVersions` (wraps `builtins.compareVersions`; non-numeric inputs rejected), `subsetOf`, `supersetOf`.
6. Parity test: T0 (naive reference, kept as `reasoner/naive.nix` used ONLY by tests) vs T1 on identical inputs → identical closure byte-for-byte, identical proof DAG shape.
7. Benchmark (`tests/perf/bench.nix`): closure of full universe + Merge horn subset; print eval time & counters; fail CI if > 5 s on reference hardware.

**Rollback:** if any gate fails, revert `datalog.nix` façade to previous tag; Merge ingestion code is a separate file — delete or gate behind `features.hornIngest=false`.

### Phase 2 — Ontology upgrade: equivalences + synthesis (2 h)

**Files:** `sumo.nix` (extend), `reasoner/synthesize.nix`, `tests/unit/equivalents.nix`.

1. Collect `(equivalent A B)`; build union-find; `isSubclass X C` ⇒ component(C); ancestors walk on representatives.
2. Extract relation declarations; synthesize transitive/symmetric Horn (§4.2).
3. Refuse reflexive identity duplication if already implied (redundant rules rejected with reason `redundant`).
4. Tests: `tests/` green; new unit tests for equivalence subsumption (10 hand cases); `transitiveAttribute part` derivation test.

### Phase 3 — Horn ingestion pipeline (2–3 h)

**Files:** `reasoner/ingest.nix`, `tests/ingest-report.json`, `tests/ingest-smoke.nix`.

1. Classify all parsed forms → `{ keepHorn; rejected; }`.
2. `keepHorn` transforms: strip `forall` wrapper; split antecedent `or`; drop redundant SUMO `subclass`-propagation rules; STYLES: keep SUMO's `isa`/`instance` as-is (engine handles).
3. `rejected` — reasons enumerated (`unstratified-negation`, `disjunctive-consequent`, `function-symbol-in-consequent`, `ungrounded-consequent`, `parse-failed`); count & dump sample to report; **never** throw — log, continue.
4. Smoke test: closure(facts + keepHorn) terminates; print counters; optional timing.
5. Full-suite run; if green, ingestion default **on** (still overridable: `feature.hornIngest=false`).

### Phase 4 — Proof artifacts & external checkability (2 h)

**Files:** `reasoner/proof.nix`, `proof-check.nix`, `proof.kif` (example output).

1. `toProofKif fact → string` — emit KIF file: asserted facts, rules used (by id + consequent text), steps.
2. `proof-check.nix` — **independent re-checker** (not the engine): re-parse exported proof; for each step, re-unify premises vs antecedent; fail on mismatch. Small (~150 lines), zero shared code with engine — the point is independent verification.
3. Wire into spike output: prints "proof: N steps, all premises re-checked ✓".

### Phase 5 — Policy product: gate & relaxation menu (3–4 h)

**Files:** `policy/build-gate.nix`, `policy/relax.nix`, CI wiring.

1. **Build gate** — nix derivation helper `mkPolicyChecked { pkgs; policy; goal; }`: builds the derivation only if the goal fact is derivable from (nixpkgs facts ∧ policy); else fails with the proof-of-violation (`explain` subtree of the negated-goal proof… i.e. proof of `¬policyCompliant` if stated as a Horn query — via `holds` on the complement; always check both polarities and report whichever is derivable).
2. **Relaxation menu** — given failing goal G and candidate fact set K (e.g. all `disjoint/implies` relaxations in the policy): find all k ∈ K with closure(K \ {k}) ⊨ G; emit minimal-hit list with cardinality; or find all minimal H ⊆ K such that closure ⊭ G under H (for "what to drop to forbid"). Output: `./relax.txt` with per-candidate scope & proof sketch.
3. Docs + `nix build` example wired into `nix-checks`; CI job optional.

### Phase 6 — Differential testing & CI (2 h)

**Files:** `tests/diff/souffle/`, CI workflow snippet.

1. Same facts+rules dumped to Soufflé syntax; run; compare derived predicates byte-wise (modulo ordering — sort first).
2. Any mismatch ⇒ failing job; logs the minimal rule set that diverges.
3. **Never** required for runtime; **required** when T1 logic changes (gate).

### Post-T1 milestones (planned, separate commits)

| Milestone | Content | Est. |
|---|---|---|
| T2.1 | Disjunctive consequents (E1) — branch-enumerate fixpoints with `disjunct` IR | 1–2 d |
| T2.2 | Well-founded negation (E2) — three-valued + alternating fixpoint | 1–2 d |
| T2.3 | Bounded existential grounding (E3) | 1 d |
| T2.4 | Congruence closure synthesis (E6) | 1 d |
| T2.5 | Knuth–Bendix offline tool + checked-in Merge.normal.kif (E7) | 2–3 d |
| T2.6 | Builtins full set + aggregate premises (E8/E11) | 1 d |
| T2.7 | Soufflé differential CI (E12) | 0.5 d |
| T3.1 | Weighted/soft rules + MaxSAT relaxation (E9) | 2–3 d |
| T3.2 | Parallel branches (E13) | 1 d |
| T3.3 | Temporal predicate treatment (E14) | 2 d |

## 7. Testing Strategy

1. **Existing suite remains the oracle** — `tests/` (golden KIF parse, CVE-provenance scenarios, and the five Python/jq-oracle gates in `tests/`) stays green on every commit; no expected-artifact may be edited to make a change pass.
2. **Parity test** (Phase 1) — T0 vs T1 byte-equal closure; catches semi-naive bugs immediately.
3. **Stratifier unit tests** — crafted cyclic/negative cases.
4. **Equivalence unit tests** — 10 subsumption cases via `equivalent`.
5. **Ingestion report** — committed JSON; CI diff fails if counts regress >10 % without human override (prevents silent drift of what gets ingested).
6. **proof-check.nix** — validates exported `proof.kif`; runs in CI; a shared-artifact gate.
7. **Synthesis tests** — crafted facts + `transitiveAttribute part` → expect derived 2-hop closure; negative case: `symmetricAttribute` not applied to `asymmetric` decls.
8. **Relaxation menu** — golden output on a fixed 6-toggle policy; exact match required.
9. **Performance floor** — closure eval ≤ 5 s reference hardware; peakFacts reported; CI fails on > 2× regression even if under floor.

## 8. Diagnostics & Observability (all new)

Engine returns: `{ facts; holds; ask; why; explain; diagnostics }` where

```
diagnostics = {
  rulesIngested    : int
  rulesRejected    : [ { rule = str; reason = str; } ]
  strata           : [ [ str ] ]          # predicates per stratum, ordered
  rounds           : int
  peakFacts        : int
  deltasPerRound   : [ int ]
  ingestedFromMerge: { total; keepHorn; rejectedByReason : { reason : int } }
}
```

Benchmarks print these; CI gates exist for `rulesRejected > threshold` (catch silent format drift in SUMO).

## 9. Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Merge.kif Horn yield tiny | medium | ingestion useless → demo value flat | Phase 0 measurement veto; fall back to manual curation (current files unchanged) |
| `equivalent` breaks subsumption | low | tests fail | Phase 2 isolated; parity+unit gates; rollback = single commit revert |
| Semi-naive bug (missed Δ) | medium | **unsoundness** | parity test mandatory; proof-check gates; fail-closed |
| Stratification rejects useful rules | medium | missing reasoning for some policies | rejection log visible; human override per rule (`manualAdmission = [ id ]` config) — explicit allow-list, always logged |
| Eval time blow-up after ingestion | medium | unusable REPL/nix eval | benchmark gate 5 s; if 2× over, drop ingestion default; identify hot rules via dict-sorted counters |
| Proof export drifts from engine | low | audit untrustworthy | proof-check re-verifies independently (§4, Phase 4) |
| SUMO version drift | low | CI surprise | pin `sumo.full` revision in `pins.nix` (already pinned path); ingestion report gates CI |
| Scope creep into T2/T3 | high | never ships | each T2/T3 is an independent commit; T1 ships and tags `v0.2-reasoner` |

## 10. Definition of Done

- [ ] Phase 0 report committed; numbers in commit msg
- [ ] `tests/` green (default, rules, scenario, bags, decide, hf, org, pyai gates); parity T0≡T1 green
- [ ] Merge ingestion default-on (or veto documented with numbers); rejection reasons all enumerable; zero `throw` paths
- [ ] `isSubclass` correct under `equivalent` (unit + full suite)
- [ ] `transitiveAttribute` synthesis proven on a real SUMO decl-derived case
- [ ] `proof.kif` exports and passes `proof-check.nix`
- [ ] Policy gate + relaxation menu working end-to-end on one demo package
- [ ] Bench ≤ 5 s; `diagnostics` wired into outputs; README documents architecture + limits + extension guide
- [ ] TODO2.b checkboxes updated on every commit; final summary lists rejected-rule counts and measured deltas vs T0

## 11. Effort Estimate

| Phase | Estimate | Depends on |
|---|---|---|
| 0 — measure & verdict | 2 h | available Merge.kif |
| 1 — T1 engine + stratifier + parity | 4–6 h | Phase 0 gate |
| 2 — equivalences + synthesis | 2 h | Phase 1 done (stratifier reused) |
| 3 — Horn ingestion | 2–3 h | Phase 0/1 |
| 4 — proof export + checker | 2 h | Phase 1 |
| 5 — policy gate + relaxation | 3–4 h | Phases 1–4 |
| 6 — differential CI | 2 h | Phase 1 (independent thereafter) |
| **Core total** | **~2–2.5 days** | |
| T2.x expansion set | 4–7 days | Core green |
| T3.x | 4–6 days | T2 green |

## 12. File Manifest (new + changed)

```
home/me/sumonix/TODO2.b.md                          # this plan
reasoner/engine.nix                                 # T1 engine (semi-naive, stratifier, builtins)
reasoner/ir.nix                                     # compiled rule/form IR types
reasoner/ingest.nix                                 # Merge.kif classification & horn filter
reasoner/stratify.nix                               # predicate dependency graph + strata + checks
reasoner/synthesize.nix                             # declaration → Horn synthesis
reasoner/naive.nix                                  # T0 kept for parity tests ONLY
reasoner/proof.nix                                  # proof.kif exporter
policy/build-gate.nix                               # policy enforcement derivation helper
policy/relax.nix                                    # relaxation menu
datalog.nix                                         # façade re-export (legacy API)
sumo.nix                                            # + equivalent union-find subsumption
tests/default.nix                                   # unchanged (oracle)
tests/unit/*.nix                                    # stratifier, equivalences, synthesis, builtins
tests/ingest-report.nix                             # committed JSON histogram
tests/perf/bench.nix                                # time + counters + CI gate
tests/semi-naive-parity.nix                         # T0≡T1 gate
proof-check.nix                                     # independent KIF proof checker
```

## 13. Decisions Needed From You

1. **Slice choice:** Phase 0 alone (measure, report, then decide), or Phases 0–2 (measure + engine + ontology upgrade), or full T1 core (0–4)?
2. **Merge revision:** keep current `sumo.full/Merge.kif` as the pinned corpus, or allow updating after Phase 0 (I recommend: **keep**; any change is a separate reviewed commit)?
3. **Ingestion default:** if Phase 0 verdict is "yes, Horn ≥ 300", should ingestion be default-on for `tests/` too (risk: golden drift) or CLI-only (`spike/`)? I recommend **default-on everywhere; tests remain the oracle; if any drift appears, it is a bug, not a judgment call** — but say the word if you prefer conservative.
4. **CI:** repo has no wired CI for this yet — add `.github/workflows` or leave as local-gate? (Affects Phase 6 scope.)

Operational rule for all phases: **one green test-suite run per commit; proof-check passes; benchmark numbers in the commit message.** No exceptions — the suite is the contract.
