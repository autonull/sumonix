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