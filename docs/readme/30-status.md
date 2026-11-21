## Status

### Shipping today

| Milestone | What you get |
|-----------|--------------|
| **V1** ✅ | Horn ingestion runs; full test suite green. |
| **V2** ✅ | Every derived fact has an exported, independently re-checked proof. |
| **V3** ✅ | **Build-time enforcement with a proof-of-violation and a relaxation menu** — the demo that justifies this project. |
| **Phase 3** ✅ | **Schema Mapper, Policy Packs, Transition Bundles, Audit Pipeline** — schema adapters, composable packs, verified changes, five-stage audit. Modules complete; CLI surfaces partial. |
| **V4** ⏳ | Differential CI (Soufflé) — deferred. |

### What is actually running

| Capability | State | Evidence |
|------------|-------|----------|
| Parser, ontology, equivalence union-find | ✅ | `tests/default.nix` |
| Declaration-driven synthesis | ✅ | 166 rules from SUMO's own `TransitiveRelation` / `subrelation` / `inverse`; `tests/unit/synthesize.nix` |
| Stratifier | ✅ | 337 negative-cycle rejections on 989 pinned rules, each with a reason; `tests/unit/stratify.nix` |
| Ingestion | ✅ | 146 Horn rules from Merge.kif, default-on; 903 forms rejected with reasons; `tests/ingest-smoke.nix` |
| Naive engine | ✅ | 316 rules and 37 rounds in the demo digest; warm cache |
| Proof export + independent checker | ✅ | 9-step certificate; `tests/proof-check.nix` plus 4 tamper tests |
| Build gate | ✅ | Fails the derivation with the proof tree |
| Relaxation menu | ✅ | Single flips, size-2 flips, minimal supports |
| Schema mapper | ✅ module | JSON ⇄ KIF; YAML/TOML schema forms; `reasoner/schema.nix` |
| Policy packs | ✅ module / 🧪 CLI | Composable flake inputs; `pack list` / `remove` storage is not implemented |
| Transition bundles | ✅ module / 🚧 CLI | Verification module tested; `plan` / `apply` are stubs |
| Audit pipeline | ✅ | Five stages; `sumo audit --json` |
| Live drift + resident metavisor | ✅ | `tests/unit/drift.nix`, `tests/unit/metavisor.nix`, D1 container demo |

`./run-tests.sh` reports **27 tests passed**. The test suite is eval-only: it
evaluates pinned expressions against the warm local store and never builds a
derivation.

### Benchmark

| Measure | Value |
|---------|-------|
| Demo path | 146 ingested + 166 synthesized + 4 user rules (316 total) |
| Cold `sumo status` | ~2–4.5 s on this host, no cache |
| Warm `sumo status` | ~0.1 s from the evaluation cache |
| Gate budget | 5 s |
| Strategy | Naive forward chaining ships; semi-naive is skipped |

Times are wall clock on the development host, not a promise. A cold run
re-evaluates the digest; a warm run reuses the cache.

### Honest limits

- **Evaluation cost.** The engine runs under `nix eval`; a cold subcommand
  takes a few seconds and a warm one is near-instant. `sumo dashboard`
  refreshes on a timer rather than on keystroke.
- **Naive engine.** It is fast enough for this ontology, and the interface
  allows a compiled backend later. Differential CI with Soufflé is V4.
- **Eval path is deliberately bounded.** Full FOL, disjunctive stable models,
  and unbounded satisfiability are excluded. They belong in offline tooling or
  validation-only CI.
- **Phase 3 CLI is partial.** The modules are complete and tested; `pack list`,
  `pack remove`, `plan`, and `apply` are not production surfaces yet. `apply`
  verifies a simulated bundle and says so.
- **Evidence envelopes are verbose.** `sumo status` prints full `FactMeta`
  provenance. The committed demo transcripts are normalized for readability.

The honest summary: **the core proof pipeline is solid, the policy product
ships, and the extension surfaces are complete at the module level.** The
remaining work is listed, not hidden.
