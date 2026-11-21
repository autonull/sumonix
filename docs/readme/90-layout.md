## Repository layout

```text
├── kif.nix                    # SUO-KIF parser
├── sumo.nix                   # Ontology: ancestors, classOf, isSubclass, isInstance, equivalent union-find
├── datalog.nix                # Naive engine + trace (round, bindings, proof)
├── pins.nix                   # Pinned SUMO corpus (SHA-256 verified)
├── nix-domain.kif             # NIX classes/relations under SUMO
├── rules.kif                  # Hand-written rules for the CVE demo
├── system.kif                 # System policy rules (R1-R5: firewall, drift, user, secrets, licenses)
├── reasoner/
│   ├── synthesize.nix         # Declaration → Horn rules (TransitiveRelation, subrelation, inverse, …)
│   ├── ingest.nix             # Merge.kif classification + transforms + stratifier cut
│   ├── stratify.nix           # Predicate graph + strata + neg-cycle rejection
│   ├── lift-config.nix        # Pure nixosConfig → KIF with option-path provenance
│   ├── config-gate.nix        # Well-typedness + policy gate (throws with the why-tree)
│   ├── drift.nix              # Attested drift + rogue listeners (Horn + NAF)
│   ├── metavisor.nix          # Source labels + proof IDs over drift (M3A)
│   ├── repair.nix             # One option edit per candidate, verified by re-lifting
│   ├── proof.nix              # KIF certificate generator
│   ├── proof-artifact.nix     # Deterministic proof.kif for the CVE scenario
│   ├── schema.nix             # JSON ⇄ KIF adapter (+ YAML/TOML schema forms)
│   ├── policy-pack.nix        # Composable policy packs as flake inputs
│   ├── transition-bundle.nix  # Verified change operations (preconditions, edits, simulation)
│   ├── audit.nix              # 5-stage audit pipeline (vulns + licenses)
│   ├── builtins.nix           # Builtin registry (versionInRange, licensePolicy, etc.)
│   ├── wfs.nix                # Well-founded semantics (three-valued logic)
│   ├── congruence.nix         # Congruence closure (equivalence classes)
│   ├── temporal.nix           # Temporal reasoning (before, after, within, holdsAt)
│   ├── soft-rules.nix         # Weighted rules + MaxSAT relaxation
│   ├── existential.nix        # Bounded existential reasoning
│   └── well-typed.nix         # Well-typedness gate for lifted facts
├── proof-check.nix            # Independent checker (zero shared code)
├── policy/
│   ├── build-gate.nix         # check / mkPolicyChecked (both polarities)
│   └── relax.nix              # Relaxation menu (flips + supports)
├── tests/
│   ├── default.nix            # Oracle: 5,505 forms, 712/714 classes, Human ancestors, etc.
│   ├── rules.nix              # CVE scenario on hand-written rules
│   ├── ingest-smoke.nix       # CVE scenario WITH ingestion ON
│   ├── proof-check.nix        # Committed proof.kif + 4 tamper tests
│   ├── unit/
│   │   ├── equivalents.nix    # Equivalence subsumption
│   │   ├── synthesize.nix     # Declaration-driven synthesis
│   │   ├── stratify.nix       # Stratifier behavior
│   │   ├── relax.nix          # Relaxation menu behavior
│   │   ├── lift-config.nix    # Lift + gate on real NixOS configs
│   │   ├── drift.nix          # Drift / rogue / stale observation
│   │   ├── repair.nix         # Verified single-option repair
│   │   ├── metavisor.nix      # Source-labeled surface + NixOS module wiring
│   │   ├── diag.nix           # KIF diagnostics (typos, unknown preds)
│   │   ├── builtins.nix       # Builtin registry tests
│   │   ├── disjunctive.nix    # Disjunctive consequent tests
│   │   ├── soft-rules.nix     # Soft rules / MaxSAT tests
│   │   ├── wfs.nix            # Well-founded semantics tests
│   │   ├── existentials.nix   # Bounded existential tests
│   │   ├── temporal.nix       # Temporal reasoning tests
│   │   ├── congruence.nix     # Congruence closure tests
│   │   └── runtime-policy.nix # R3/R4/R5 runtime policy tests
├── container/nixos/
│   ├── sumo.nix               # services.sumonix (CLI, facts, guard)
│   └── metavisor.nix          # services.sumonix-metavisor (timer + event log)
├── container/run.sh           # D1 harness: build|run NixOS-in-Podman VM
├── proof.kif                  # Committed artifact (9 steps, independently re-checked)
├── demo/                      # The 60-second demo: scenes, transcripts, asciinema casts
│   ├── run                    # ./demo/run [scene ...] — replay the whole demo
│   ├── record                 # Re-record all scenes (asciinema)
│   ├── gen-facts.sh           # Refresh demo/facts/nixpkgs.kif from pinned nixpkgs
│   ├── scenes/                # 01-30-seconds, 02-capabilities, 03-pages, 04-crosswalk, 05-when-the-build-breaks
│   ├── nix/                   # Nix-side digests the scenes print (org digest, crosswalk, policy)
│   └── facts/nixpkgs.kif      # Pinned real-nixpkgs facts (committed, offline)
├── tools/
│   ├── env.sh                 # Shared environment (local store dirs)
│   ├── build-readme.sh        # Generates README.md from docs/readme/*.md
│   ├── tour.sh                # Records asciinema tour
│   ├── shot.sh                # TUI dump → PNG
│   ├── movie.sh               # Cast → animated GIF
│   ├── metavisor-tour.sh      # Drives D1 container demo
│   ├── observe.sh             # Live observer (systemd, /proc, ss)
│   └── host-facts.sh          # Demo host facts (live + fixture)
├── nix-eval.sh                # Convenience wrapper (local store dirs, --impure)
├── run-tests.sh               # Whole suite in one go
├── spike/                     # Capability discovery VM (optional)
├── org/ hf/ bags.nix tq.nix   # Other demos (Hugging Face tags, org pages, test bags)
├── flake.lock                 # Pinned nixpkgs (used by audit pipeline)
├── .osv-cache.json            # OSV vulnerability cache (for audit)
└── .spdx-cache.json           # SPDX license cache (for audit)
```

### The local store, in one paragraph

This repository keeps two Nix stores inside the checkout. `.nix-store/` is the
**eval store**: store paths are rewritten to the repository prefix, so it is
fast and self-contained, but it can never fetch a substitute. `.nix-root/` is
the **build store**: logical paths stay `/nix/store/...`, so binary-cache
hashes match and substitution works, but builds need mount namespaces. The rule
is simple: **eval-only work uses the local store; anything that must fetch or
build uses the root store.** `AGENTS.md` documents the mechanics and the
failure modes.
