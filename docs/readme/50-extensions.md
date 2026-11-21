## Extension contract

**Rule zero:** a capability that needs unbounded FOL or unbounded
satisfiability on this ontology belongs in **offline tooling** or
**validation-only CI**, never in `nix eval`.

Every capability below is an accepted obligation. It either has a test or a
documented reject path. Nothing is admitted by accident.

### Implemented in the engine (T2.x / P3)

| Capability | Extension point | Milestone | Termination | Proof tag |
|------------|-----------------|-----------|-------------|-----------|
| Disjunctive consequent | IR `disjunct [B C]` | T2.1 | branch enumeration + per-branch fixpoint | `by disjunct#<i>` |
| Well-founded negation | three-valued eval + alternating fixpoint | T2.2 | bounded by strata size | `by unknown#neg` |
| Existential consequent / Skolem | bounded grounding (finite domain) | T2.3 | finite domain ⇒ terminates | `by exists-witness` |
| Antecedent disjunction | compile-time `or` → two Horn rules | P3 (free) | unchanged | `by or-split` |
| `iff` / `<=>` | compile-time split into two `=>` | P3 | unchanged | both directions |
| Equality & congruence | generated schemas over fact terms | T2.4 | finite terms ⇒ finite closure | congruence paths |
| Knuth–Bendix completion | offline `completion.nix` | T2.5 | offline; depth-limited | n/a |
| Aggregates & arithmetic | builtins registry (`greaterThan`, `subsetOf`, …) | P3 / T2.6 | pure Nix comparisons | `by builtin#<name>` |
| Non-ground `ask` + aggregates | IR `aggregate` with group-by | T2.6 | finite solutions | `by aggregate#count` |

### Planned extensions (T3.x)

| Capability | Extension point | Milestone | Termination | Proof tag |
|------------|-----------------|-----------|-------------|-----------|
| Weighted/soft rules & MaxSAT | rule weights + violation minimization | T3.1 | bounded candidate set | `by soft#<w>` |
| Abductive repair | minimal failing sets (hitting-set) | P5 (menu) | bounded candidates | `by abduced` |
| External compiled backend | differential CI (Soufflé) | T2.7 | n/a | proofs must match |
| Parallel eval | semi-naive rounds are set-parallel | T3.2 | unchanged | unchanged |
| Temporal/Modal | binary predicates + dedicated module | T3.3 | finite time atoms | modal tags |

### Excluded from the eval path

| Capability | Reason |
|------------|--------|
| Full FOL / disjunctive stable models | unbounded satisfiability; requires offline tooling |

> **Every row is an accepted obligation with a test or a documented reject
> path. Nothing is admitted by accident.**

**Want to help?** Start with one planned extension — soft rules / MaxSAT,
abductive repair, Soufflé differential CI, or parallel evaluation. Each is an
independent module with its own test and demo, and it stays off the eval path
unless explicitly enabled.
