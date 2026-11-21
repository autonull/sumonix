## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         SUMONIX DATA FLOW                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  Merge.kif ──┐                                                              │
│  nix-domain  ├─► ingest.classify ──► { ontology │ horn-rules │ rejected }   │
│  SEEDS       ┘       │                    │                                 │
│                      ▼                    ▼                                 │
│                sumo.nix (+equiv)    engine.run (naive; proven fast enough)  │
│                                          │                                   │
│                   ┌────────────────────┼────────────────────┐               │
│                   ▼                    ▼                    ▼               │
│             policy gate          relaxation menu        proof export       │
│             (build fails on      (flip-candidates,      (proof.kif →       │
│              violation)           min-drop set)          proof-check.nix)   │
│                                                                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                        PHASE 3 EXTENSIONS                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  JSON/YAML/TOML ──► schema.nix ──► KIF facts ──► engine ──► violations     │
│       │                                    │                                 │
│       ▼                                    ▼                                 │
│  policy-pack.nix ◄── schema.kif      audit.nix (5 stages)                   │
│       │                                    │                                 │
│       ▼                                    ▼                                 │
│  transition-bundle.nix ──► verified changes (preconditions, edits,         │
│                          simulation, compensation, idempotency)             │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Interfaces are narrow and total; layers replace independently.**