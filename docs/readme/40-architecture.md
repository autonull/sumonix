## Architecture

sumonix is a small pipeline with a hard boundary at every stage. Facts go in;
rules and a forward-chaining engine go to work; proofs, verdicts, and repairs
come out. Each layer is replaceable without touching the layers around it.

### Data flow

```text
Merge.kif ──┐
nix-domain ─┤──► ingest.classify ──► { ontology │ horn rules │ rejected }
SEEDS ──────┘          │                     │
                       ▼                     ▼
                 sumo.nix (+ equiv)     engine.run (naive; proven fast enough)
                                               │
                    ┌──────────────────────────┼──────────────────────────┐
                    ▼                          ▼                          ▼
              policy gate                relaxation menu            proof export
              (build fails on            (flip candidates,          (proof.kif →
               violation)                 minimal supports)          proof-check.nix)

┌────────────────────────────── Phase 3 extensions ──────────────────────────────┐
│                                                                                │
│  JSON ──► schema.nix ──► KIF facts ──► engine ──► violations                   │
│  (YAML/TOML schema forms)                                                       │
│         │                                  │                                   │
│         ▼                                  ▼                                   │
│  policy-pack.nix ◄── schema.kif       audit.nix (5 stages)                      │
│         │                                  │                                   │
│         ▼                                  ▼                                   │
│  transition-bundle.nix ──► verified changes (preconditions, edits,             │
│                            simulation, compensation, idempotency)              │
│                                                                                │
└────────────────────────────────────────────────────────────────────────────────┘
```

**One sentence:** facts and rules go into a pure forward-chaining engine; the
engine returns a verdict, a proof tree, and — when the verdict is a violation —
the set of flips that changes it.

### The chain of trust

1. **Facts** carry provenance. Every fact names its source class, source id,
   snapshot, and confidence.
2. **Rules** are derived from SUMO declarations or written by you. The
   stratifier rejects every rule that would make the dependency graph
   inconsistent.
3. **Derivations** carry rule, round, bindings, and ancestor facts.
4. **Proofs** are exported as KIF and re-checked by `proof-check.nix`, which
   shares zero code with the engine.
5. **Policies** are Horn rules. A violation is a derived fact; the build gate
   turns it into a failed derivation with the proof attached.

### Invariants

1. **Pure evaluation.** The reasoning path is deterministic, offline, and free
   of hidden state. Anything that needs unbounded search runs outside `nix eval`.
2. **Narrow, total interfaces.** Each layer hands the next a value it fully
   defines. No layer reaches back into another's internals.
3. **Every answer has provenance.** A derived fact names the rule, the round,
   the bindings, and the ancestor facts that produced it.
4. **Proofs are portable.** The certificate is KIF, and the checker can re-run
   it without importing the engine.
5. **Rejections are explicit.** An unsupported form is rejected with a reason,
   never silently dropped.

### Replaceability

The engine is the kernel, not the product. The parser, ontology, engine, proof
format, and checkers are independent modules. A different ontology, a different
unification strategy, or a compiled backend can replace one layer as long as it
keeps the interface and the proof contract.

**Interfaces are narrow and total; layers replace independently.**
