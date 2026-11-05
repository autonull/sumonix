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