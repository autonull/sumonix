# sumo-nix 🦙

> **A semantic operating system: where every package, vulnerability, capability, and policy is a fact in a shared knowledge graph, reasoned over by a capable, auditable engine — and the build fails with a proof when policy is violated.**

> **The vision:** NixOS configurations, nixpkgs derivations, CI pipelines, and runtime telemetry all contribute facts to a single SUMO-native knowledge base. A forward-chaining engine derives transitive closures (dependencies, vulnerabilities, capabilities), subsumes through equivalences, and answers queries with full provenance. Policies are Horn rules; violations halt the build with an independently re-checkable proof. A relaxation menu shows exactly which overrides flip the verdict. Extensions for disjunction, aggregates, soft rules, temporal logic, and congruence closure are admitted by design — each a pure Nix module behind a flag, never touching the eval path unless explicitly enabled.

> **What runs today (V3):** parser, ontology with equivalence union-find, declaration-driven synthesis (166 rules from SUMO's own `TransitiveRelation`/`subrelation`/`inverse`…), stratifier (349 neg-cycle rejections with reasons), ingestion (116 Horn rules from Merge.kif, default-on), naive engine (~1.1 s), proof export + zero-shared-code checker, build gate with proof-of-violation, relaxation menu (single flips + size-2 flips + minimal supports).

> **What's next (pick one):** congruence closure (equal things interchangeable), aggregates/builtins (version ranges, counts), disjunctive heads (choice), soft rules/MaxSAT (minimize violations), well-founded negation, bounded existentials, temporal logic — each an independent module with its own test and demo.

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

## 🌍 Application Bootstraps — The Complete Vision

The core engine is the **kernel**. Each bootstrap below is an independent pure-Nix module (converter + policy pack + demo) that plugs into it. No CI, no external deps — just `sumo-nix` as the universal proof layer.

| # | Bootstrap | What It Lifts | Demo Query | Effort |
|---|-----------|---------------|------------|--------|
| 🟢 **B1** | **Nixpkgs Ontology** | 100k+ packages, deps, licenses, meta | "Find all BSD-licensed web servers with no network deps" | 2–4 h |
| 🟢 **B2** | **Epistemic Flakes** | Compliance rules as flake inputs | "Build fails: PII package depends on network-transmitter" | 1–2 h |
| 🟢 **B3** | **json2kif / yaml2kif** | Any JSON/YAML → KIF facts | "Which services use secrets AND expose public ports?" | 1–2 h |
| ☁️ **B4** | **Terraform Plan** | `terraform show -json` | "Prove this plan has no public sensitive data" | 2–3 h |
| ☁️ **B5** | **K8s / Docker Compose** | Manifests → KIF | "Which containers are privileged AND exposed?" | 2–3 h |
| 🔗 **B6** | **Lockfile + OSV/NVD** | package-lock.json + OSV API | "Is my-app exposed to CVE-2024-1234 via transitive deps?" | 2–4 h |
| ⚖️ **B7** | **License Oracle** | SPDX + dep graph | "Can this proprietary artifact ship?" | 2–3 h |
| 📡 **B8** | **OpenAPI / JSON Schema** | OpenAPI v1/v2 → KIF | "Is v2 backward compatible with v1 clients?" | 2–4 h |
| 🗄️ **B9** | **SQL / dbt Lineage** | DDL / dbt manifest → KIF | "Which BI models contain email addresses?" | 3–4 h |
| 📝 **B10** | **Git + CODEOWNERS** | Git log + CODEOWNERS → KIF | "Who must review changes to payment code?" | 1–2 h |
| 🔥 **B11** | **Firewall / SG Analyzer** | iptables, AWS SG, K8s NetworkPolicy | "Is SSH exposed? Which rules are shadowed?" | 2–3 h |
| 🔐 **B12** | **RBAC / ABAC Explainer** | IAM, groups, roles, resources | "Can alice read prod-db? Why/why not?" | 1–2 h |
| ⚙️ **B13** | **CI Pipeline Optimizer** | GitHub Actions / GitLab CI → KIF | "Does deploy run before tests? Any fork secrets?" | 1–2 h |
| 🔧 **B14** | **Env Validator** | .env + app meta → KIF | "Is production fully configured?" | <1 h |
| 🧹 **B15** | **Git Hygiene** | Git ls-files + patterns → KIF | "Are secret-like files tracked?" | <1 h |
| 🔍 **B16** | **Semantic Grep** | Repo files → KIF concepts | `sumo grep . "PII fields"` | 1–2 h |
| 📋 **B17** | **Ontology Task Runner** | Task declarations → KIF | "What tasks to build running-service?" | 1–2 h |
| 💥 **B18** | **Change Impact** | Dependency graph + facts → KIF | "What breaks if I remove redis?" | 2–3 h |
| 📄 **B19** | **Compliance Receipt** | Check results → signed receipt | "Audit artifact for GDPR" | 1–2 h |
| 🏷️ **B20** | **Proof Badges** | Check results → SVG badges | `![No CVE](badge.svg)` links to proof | <1 h |
| 🎯 **B21** | **Semantic Package Select** | Nixpkgs ontology + constraints | `selectPackage { provides="WebServer"; NoGPL }` | 2–3 h |
| 🔐 **B22** | **Crypto Epistemology** | HW state, network, user → KIF | "Secret only exists on corp Wi-Fi + disk unlocked" | 2–3 h |
| 📡 **B23** | **API Evolution** | OpenAPI + client contracts → KIF | "Is v2 backward compatible?" | 2–3 h |
| ⚙️ **B24** | **Config Contradiction** | NixOS modules → KIF | "Postgres needs 5432 but StrictFirewall denies all" | 2–3 h |
| 📦 **B25** | **Policy-as-Flakes** | Flake inputs → KIF rules | `inputs.gdpr.url = "github:org/gdpr-kif"` | 1–2 h |
| ✅ **B26** | **sumo flake check** | Checks → Nix flake checks | `nix flake check` fails with proof | <1 h |
| 🛡️ **B27** | **sumo assert** | `sumo.assert { query; }` in Nix | Build fails with proof in Nix eval | <1 h |
| 🤔 **B28** | **Why-does-this-exist** | Resource facts → generated docs | "Why does redis-cache exist?" | 1–2 h |

---

### How They Compose

| Milestone | What It Means |
|-----------|---------------|
| **V2** | Core engine + **1 bootstrap** (e.g., B3 json2kif + B14 env validator) |
| **V3** ✅ | V2 + policy product (build gate + relaxation menu) + **3 bootstraps** composing |
| **V4** | V3 + **3 bootstraps** composing + T2.4/T2.6 engine extensions |
| **V5** | All **26 bootstraps** + T2.1/T2.6/T3.1 + T2.7 (Soufflé CI) |

Each bootstrap = converter + policy pack (KIF rules) + demo query. Pure Nix, no CI, no external deps.

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