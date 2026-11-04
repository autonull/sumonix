# sumo-nix 🦙

> **The SUMO upper ontology as a capable, auditable reasoner in pure Nix.**
> No external deps. No hand-curation. Just a pinned KIF file and ~1,000 lines of Nix.

---

## 🎯 What This Is

| Layer | What It Does |
|-------|--------------|
| 📖 **Parser** (`kif.nix`) | SUO-KIF text → S-expressions (atoms = strings, lists = lists) |
| 🧠 **Ontology** (`sumo.nix`) | `subclass`/`instance`/`equivalent` → ancestors, classOf, `isSubclass`, `isInstance`, domains, well-typedness |
| ⚙️ **Engine** (`datalog.nix`) | Naive forward chaining over Horn rules; every derived fact carries `{ rule, from, round, bindings }` |
| 🔬 **Synthesis** (`reasoner/synthesize.nix`) | Reads SUMO's own declarations (`TransitiveRelation`, `SymmetricRelation`, `subrelation`, `inverse`, `subAttribute`…) and *writes* Horn rules — no hand-curation |
| 🛡️ **Stratifier** (`reasoner/stratify.nix`) | Predicate dependency graph; rejects every rule on a negative cycle with a reason; assigns strata |
| 📥 **Ingestion** (`reasoner/ingest.nix`) | Classifies all `=>`/`<=>`/`forall` forms from Merge.kif; strips quantifiers, splits `or`/`and`, drops ancestor-prop duplicates, applies stratifier cut |
| 📜 **Proof Export** (`reasoner/proof.nix`) | Emits a KIF certificate: ontologies, rules (engine IDs), axioms, steps in round order, bindings, goal |
| ✅ **Independent Checker** (`proof-check.nix`) | Zero shared code. Re-parses, re-derives subsumption, re-evaluates each step. Tamper → loud failure. |
| 🚧 **Policy Gate** (`policy/build-gate.nix`) | `check { goal; passWhen }` → pass/fail with proof tree. `mkPolicyChecked` → derivation that fails the *build* with the proof when policy is violated. |
| 🧭 **Relaxation Menu** (`policy/relax.nix`) | When a gate fails: lists every single toggle whose removal flips the verdict (with proof sketch), size-2 flips when no single does, and minimal supports for a passing goal. |

---

## 🏆 V3 — The Policy Product (Shipping Now)

| Milestone | What You Get |
|-----------|--------------|
| **V1** ✅ | Horn ingestion runs; full test suite green |
| **V2** ✅ | Every derived fact has an exported, independently re-checked proof |
| **V3** ✅ | **Build-time enforcement with a proof-of-violation + a relaxation menu** — the demo that justifies this project |
| **V4** ⏳ | Differential CI (Soufflé) — deferred |

> **Benchmark:** ~1.1 s on 286 rules / 23–185 derived facts (ingestion scenario). Well under the 5 s gate. The naive engine ships; semi-naive is skipped.

---

## 🏗️ Architecture

```
Merge.kif ──┐
nix-domain  ├─► ingest.classify ──► { ontology │ horn-rules │ rejected(+reasons) }
SEEDS       ┘       │                    │
                    ▼                    ▼
              sumo.nix (+equiv)    engine.run (naive; proven fast enough)
                                        │
                   ┌────────────────────┼────────────────────┐
                   ▼                    ▼                    ▼
             policy gate          relaxation menu        proof export
             (build fails on      (flip-candidates,      (proof.kif →
              violation)          min-drop set)           proof-check.nix)
```

**Interfaces are narrow and total; layers replace independently.**

---

## 📜 Extension Contract — Everything Admitted by Design

Rule zero: needs unbounded FOL or unbounded satisfiability on this ontology ⇒ **offline tooling** or **validation-only CI**, never `nix eval`.

| Capability | Extension Point | Milestone | Termination | Proof |
|------------|-----------------|-----------|-------------|-------|
| Disjunctive consequent | IR `disjunct [B C]` | T2.1 | branch enumeration + per-branch fixpoint | `by disjunct#<i>` |
| Well-founded negation | three-valued eval + alternating fixpoint | T2.2 | bounded by strata size | `by unknown#neg` |
| Existential consequent / Skolem | bounded grounding (finite domain) | T2.3 | finite domain ⇒ terminates | `by exists-witness` |
| Antecedent disjunction | compile-time `or` → two Horn rules | P3 (free) | unchanged | `by or-split` |
| `iff` / `<=>` | compile-time split into two `=>` | P3 | unchanged | both directions |
| Equality & congruence | generated schemas over fact terms | T2.4 | finite terms ⇒ finite closure | congruence paths |
| Knuth–Bendix completion | offline `completion.nix` | T2.5 | offline; depth-limited | n/a |
| Aggregates & arithmetic | builtins registry (`greaterThan`, `subsetOf`, …) | P3 / T2.6 | pure Nix comparisons | `by builtin#<name>` |
| Weighted/soft rules & MaxSAT | rule weights + violation minimization | T3.1 | bounded candidate set | `by soft#<w>` |
| Abductive repair | minimal failing sets (hitting-set) | P5 (menu) | bounded candidates | `by abduced` |
| Non-ground `ask` + aggregates | IR `aggregate` with group-by | T2.6 | finite solutions | `by aggregate#count` |
| External compiled backend | differential CI (Soufflé) | T2.7 | n/a | proofs must match |
| Parallel eval | semi-naive rounds are set-parallel | T3.2 | unchanged | unchanged |
| Temporal/Modal | binary predicates + dedicated module later | T3.3 | finite time atoms | modal tags |
| Full FOL / disjunctive stable models | **excluded from eval path** | — | n/a | n/a |

> Every row is an accepted obligation with a test or a documented reject path. Nothing is admitted by accident.

---

## 🧪 What's Covered (and What's Not)

| ✅ Covered | ❌ Not Yet |
|------------|------------|
| `subclass` / `instance` / `domain` / `equivalent` → full taxonomy | `Mid-level-ontology.kif` (separate file) |
| `TransitiveRelation`, `SymmetricRelation`, `ReflexiveRelation` → synthesized Horn rules | `documentation`, `termFormat`, `format` (human-readable only) |
| `subrelation`, `inverse`, `subAttribute` → synthesized Horn rules | `exhaustiveAttribute`, `contraryAttribute`, `disjoint` (need disjunction → E1) |
| Horn rules from Merge.kif (`=>` with grounded consequent) | quantified / negated / function consequents (rejected with reasons) |
| `and`, `exists`, `not` (NAF), `equal`, `instance` (with subsumption) | `or` in antecedent (E4), `forall` in consequent (E1) |
| Proof export + independent re-check | Knuth–Bendix completion (offline tool) |
| Build-time gate with proof-of-violation | Aggregates / arithmetic (E8, registry ready) |
| Relaxation menu (single + size-2 flips + supports) | Soft rules / MaxSAT (E9) |

**Honesty of rejection:** every unsupported form is rejected **with a reason**; nothing is silently dropped; no `throw` on user data paths.

---

## 🚀 Quick Start

```bash
# All tests (pure Nix, no sandbox needed)
nix --extra-experimental-features nix-command eval --impure --expr 'import ./tests/default.nix'      # "ok"
nix --extra-experimental-features nix-command eval --impure --expr 'import ./tests/rules.nix'        # "ok"
nix --extra-experimental-features nix-command eval --impure --expr 'import ./tests/ingest-smoke.nix' # "ok"
nix --extra-experimental-features nix-command eval --impure --expr 'import ./tests/proof-check.nix'  # "ok"
nix --extra-experimental-features nix-command eval --impure --expr 'import ./tests/unit/relax.nix'   # "ok"

# Generate the CVE proof artifact (deterministic, byte-identical)
nix --extra-experimental-features nix-command eval --impure --raw --expr 'import ./tests/proof-artifact.nix' > proof.kif

# Re-check it independently (zero shared code with the engine)
nix --extra-experimental-features nix-command eval --impure --expr '(import ./proof-check.nix { file = ./proof.kif; })'
# → "proof: 9 steps, independently re-checked ✓"
```

**Unit tests:**
```bash
nix --extra-experimental-features nix-command eval --impure --expr 'import ./tests/unit/equivalents.nix'
nix --extra-experimental-features nix-command eval --impure --expr 'import ./tests/unit/synthesize.nix'
nix --extra-experimental-features nix-command eval --impure --expr 'import ./tests/unit/stratify.nix'
```

---

## 📦 Repository Layout (Stable)

```
├── kif.nix                    # SUO-KIF parser
├── sumo.nix                   # Ontology: ancestors, classOf, isSubclass, isInstance, equivalent union-find
├── datalog.nix                # Naive engine + trace (round, bindings, proof)
├── pins.nix                   # Pinned SUMO corpus (SHA-256 verified)
├── nix-domain.kif             # NIX classes/relations under SUMO
├── rules.kif                  # Hand-written rules for the CVE demo
├── reasoner/
│   ├── synthesize.nix         # Declaration → Horn rules (TransitiveRelation, subrelation, inverse, …)
│   ├── ingest.nix             # Merge.kif classification + transforms + stratifier cut
│   ├── stratify.nix           # Predicate graph + strata + neg-cycle rejection
│   ├── proof.nix              # KIF certificate generator
│   └── proof-artifact.nix     # Deterministic proof.kif for the CVE scenario
├── proof-check.nix            # Independent checker (zero shared code)
├── policy/
│   ├── build-gate.nix         # check / mkPolicyChecked (both polarities)
│   └── relax.nix              # Relaxation menu (flips + supports)
├── tests/
│   ├── default.nix            # Oracle: 5,505 forms, 712/714 classes, Human ancestors, etc.
│   ├── rules.nix              # CVE scenario on hand-written rules
│   ├── ingest-smoke.nix       # CVE scenario WITH ingestion ON
│   ├── proof-check.nix        # Committed proof.kif + 4 tamper tests
│   └── unit/
│       ├── equivalents.nix    # Equivalence subsumption
│       ├── synthesize.nix     # Declaration-driven synthesis
│       ├── stratify.nix       # Stratifier behavior
│       └── relax.nix          # Relaxation menu behavior
├── proof.kif                  # Committed artifact (9 steps, independently re-checked)
├── spike/                     # Capability discovery VM (optional)
└── org/ hf/ bags.nix tq.nix   # Other demos (Hugging Face tags, org pages, test bags)
```

---

## 📖 Further Reading

| Doc | What's Inside |
|-----|---------------|
| `TODO2.b.md` | The full plan (Phases 0–7), decisions, risks, file manifest, DONE checkboxes |
| `nix_sumo.md` (gist) | The original design notes: sections 3.1, 6, 11, 18 |
| `spike/demo.sh` | Capability discovery VM (boots NixOS, runs the reasoner inside) |
| `sumo.full/NOTICE.md` | SUMO license (IEEE) |

---

## ⚖️ License

**LGPL-2.1** — same as Nix and mlnix. `COPYING` is a byte-for-byte copy of Nix's `COPYING`.

Some files are copies or snapshots of other projects and keep their terms:
- `sumo.full/` `sumo.tests/` — ontologyportal/sumo (see `sumo.full/NOTICE.md`)
- `hf/tags.json` — snapshot of Hugging Face's public tag lists
- `org/pages.json` `pyai/fields.json` — Pick-Your-AI repositories at pinned commits

---

## 🙏 Acknowledgments

- **SUMO** — the Suggested Upper Merged Ontology (ontologyportal/sumo)
- **mlnix** — the MLIR-based Nix frontend that inspired the dialect stack
- **TrikeShed** — the pinned corpus and the 13-term spine that showed what *not* to do
- **Nix** — for being a pure, lazy, typed functional language that can also be a reasoner

---

> **Built for audit-grade reasoning. Ships a policy gate with a proof. Extends by design, not by accident.** 🦙