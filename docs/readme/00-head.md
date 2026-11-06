# sumo-nix 🦙

<p align="center">
  <img src="docs/demo/tour.gif" alt="sumo walkthrough — live facts from this host, the fixture scenario and its proof, the capability atlas, what-if flips, the policy gate refusing the build, an independent proof check, and the dashboard" width="900">
</p>

> That is the real CLI, recorded with `asciinema`: `./tools/tour.sh` records the session to `docs/demo/tour.cast`, `./tools/movie.sh` rasterises it to the GIF above. No mock, no canned transcript — the first commands read this machine.

> **A semantic operating system: where every package, vulnerability, capability, and policy is a fact in a shared knowledge graph, reasoned over by a capable, auditable engine — and the build fails with a proof when policy is violated.**

> **The vision:** NixOS configurations, nixpkgs derivations, CI pipelines, and runtime telemetry all contribute facts to a single SUMO-native knowledge base. A forward-chaining engine derives transitive closures (dependencies, vulnerabilities, capabilities), subsumes through equivalences, and answers queries with full provenance. Policies are Horn rules; violations halt the build with an independently re-checkable proof. A relaxation menu shows exactly which overrides flip the verdict. Extensions for disjunction, aggregates, soft rules, temporal logic, and congruence closure are admitted by design — each a pure Nix module behind a flag, never touching the eval path unless explicitly enabled.

> **What runs today (V3):** parser, ontology with equivalence union-find, declaration-driven synthesis (166 rules from SUMO's own `TransitiveRelation`/`subrelation`/`inverse`…), stratifier (349 neg-cycle rejections with reasons), ingestion (116 Horn rules from Merge.kif, default-on), naive engine (~1.1 s), proof export + zero-shared-code checker, build gate with proof-of-violation, relaxation menu (single flips + size-2 flips + minimal supports).

> **What's next (pick one):** congruence closure (equal things interchangeable), aggregates/builtins (version ranges, counts), disjunctive heads (choice), soft rules/MaxSAT (minimize violations), well-founded negation, bounded existentials, temporal logic — each an independent module with its own test and demo, never touching the eval path unless explicitly enabled.