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