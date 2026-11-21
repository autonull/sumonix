## What it is

NixOS made the machine a **declared value**. It did not make the *implications*
of that value inspectable. A configuration can be valid and still contradict a
policy. A host can be declared healthy and still drift. A lockfile can resolve
and still ship a critical CVE. Today those questions are answered by a mix of
linters, ad-hoc scripts, and human memory.

sumonix puts the declarations, the package graph, and the observations into
**one SUMO-native knowledge base**, then reasons over them with Horn rules. It
does not replace Nix. It gives Nix a semantic layer: a place where facts are
typed, conclusions are derived, and every ground conclusion has a proof.

**It holds a semantic model of itself — declared and observed.** The
configuration is the declared side. The running host is the observed side. The
engine reasons over both, so a contradiction is a fact before the build, and a
drift is a fact while the system runs.

**Who it is for:**

- **Platform engineers** who want a build to fail for a reason, not a log line.
- **Security and release engineers** who need to prove that a CVE path, a
  license, or a firewall rule is what they think it is.
- **Nix tooling developers** who want a small, pure kernel to build semantic
  layers on, without adopting a solver or a service.

**The long view:** configuration, nixpkgs derivations, CI pipelines, cloud
plans, APIs, data lineage, and runtime telemetry all contribute facts to one
knowledge base. The kernel does not change. Each new source is a converter, a
policy pack, and a demo query — see
[Application bootstraps](#application-bootstraps).

**The shape of the system:**

```text
facts  +  rules  +  a forward-chaining engine  →  { verdict, proof, repair }
```

Facts are data (declarations, observations, external evidence). Rules are logic
(SUMO axioms, synthesized relation properties, and your policy rules). The
engine is small and deterministic. The proof is the product.

### Core layers

| Layer | Component | What it does |
|-------|-----------|--------------|
| 📖 **Parser** | `kif.nix` | SUO-KIF text → S-expressions (atoms = strings, lists = lists) |
| 🧠 **Ontology** | `sumo.nix` | `subclass` / `instance` / `equivalent` → ancestors, classOf, `isSubclass`, `isInstance`, domains, well-typedness |
| ⚙️ **Engine** | `datalog.nix` | Naive forward chaining over Horn rules; every derived fact carries `{ rule, from, round, bindings }` |
| 🔬 **Synthesis** | `reasoner/synthesize.nix` | Reads SUMO's own declarations (`TransitiveRelation`, `SymmetricRelation`, `subrelation`, `inverse`, `subAttribute`…) and *writes* Horn rules — no hand-curation |
| 🛡️ **Stratifier** | `reasoner/stratify.nix` | Predicate dependency graph; rejects every rule on a negative cycle with a reason; assigns strata |
| 📥 **Ingestion** | `reasoner/ingest.nix` | Classifies all `=>` / `<=>` / `forall` forms from Merge.kif; strips quantifiers, splits `or` / `and`, drops ancestor-prop duplicates, applies the stratifier cut |
| 📜 **Proof export** | `reasoner/proof.nix` | Emits a KIF certificate: ontologies, rules (engine IDs), axioms, steps in round order, bindings, goal |
| ✅ **Independent checker** | `proof-check.nix` | Zero shared code. Re-parses, re-derives subsumption, re-evaluates each step. Tamper → loud failure. |
| 🚧 **Policy gate** | `policy/build-gate.nix` | `check { goal; passWhen }` → pass/fail with proof tree. `mkPolicyChecked` → a derivation that fails the *build* with the proof when policy is violated. |
| 🧭 **Relaxation menu** | `policy/relax.nix` | When a gate fails: every single toggle whose removal flips the verdict (with proof sketch), size-2 flips when no single does, and minimal supports for a passing goal. |
| 🔄 **Schema mapper** | `reasoner/schema.nix` | JSON ⇄ KIF adapter with YAML/TOML schema forms — parse, emit, validate, and generate predicate signatures |
| 📦 **Policy packs** | `reasoner/policy-pack.nix` | Composable policy packs as flake inputs (schema + rules + ontology + metadata) |
| 📋 **Transition bundles** | `reasoner/transition-bundle.nix` | Verified change operations: preconditions, edits, simulation, compensation, idempotency check |
| 🔍 **Audit pipeline** | `reasoner/audit.nix` | Five-stage ingestion: runtime closure, config closure (flake.lock), vulnerabilities (OSV), licenses (SPDX), policy check |

> **Interfaces are narrow and total; layers replace independently.** The full
> data flow, chain of trust, and invariants are in
> [Architecture](#architecture).

### What makes it different

- **Not a linter.** A linter matches patterns. sumonix derives conclusions from
  a typed ontology and tells you which facts produced them.
- **Not a model.** There is no LLM in the reasoning path. The result is
  deterministic and reproducible from pinned inputs.
- **Not a dashboard.** A dashboard shows state. sumonix shows *why* the state is
  what it is, and what would have to change for the verdict to flip.
- **Not a new package manager.** The input is your existing NixOS configuration,
  `flake.lock`, nixpkgs metadata, and runtime telemetry.

### Design principles

1. **The proof is the product.** A verdict without a re-checkable proof is an
   opinion.
2. **Honest by construction.** Unknown is a first-class answer. Unsupported
   forms are rejected with a reason, never dropped.
3. **Pure and offline.** Reasoning runs under `nix eval`; fetching is a separate,
   visible step.
4. **Extend by design.** New capabilities arrive as modules with their own test
   and demo, behind a flag, never on the eval path by default.
