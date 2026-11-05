## 📦 Repository Layout (Stable)

```
├── kif.nix                    # SUO-KIF parser
├── sumo.nix                   # Ontology: ancestors, classOf, isSubclass, isInstance, equivalent union-find
├── datalog.nix                # Naive engine + trace (round, bindings, proof)
├── pins.nix                   # Pinned SUMO corpus (SHA-256 verified)
├── nix-domain.kif             # NIX classes/relations under SUMO
├── rules.kif                  # Hand-written rules for the CVE demo
├── reasoner/
│   ├── synthesize.nix         # Declaration → Horn rules (TransitiveRelation, subrelation, inverse, …)
│   ├── ingest.nix             # Merge.kif classification + transforms + stratifier cut
│   ├── stratify.nix           # Predicate graph + strata + neg-cycle rejection
│   ├── proof.nix              # KIF certificate generator
│   └── proof-artifact.nix     # Deterministic proof.kif for the CVE scenario
├── proof-check.nix            # Independent checker (zero shared code)
├── policy/
│   ├── build-gate.nix         # check / mkPolicyChecked (both polarities)
│   └── relax.nix              # Relaxation menu (flips + supports)
├── tests/
│   ├── default.nix            # Oracle: 5,505 forms, 712/714 classes, Human ancestors, etc.
│   ├── rules.nix              # CVE scenario on hand-written rules
│   ├── ingest-smoke.nix       # CVE scenario WITH ingestion ON
│   ├── proof-check.nix        # Committed proof.kif + 4 tamper tests
│   └── unit/
│       ├── equivalents.nix    # Equivalence subsumption
│       ├── synthesize.nix     # Declaration-driven synthesis
│       ├── stratify.nix       # Stratifier behavior
│       └── relax.nix          # Relaxation menu behavior
├── proof.kif                  # Committed artifact (9 steps, independently re-checked)
├── demo/                      # The 60-second demo: scenes, transcripts, asciinema casts
│   ├── run                    # ./demo/run [scene ...] — replay the whole demo
│   ├── record                 # Re-record all scenes (asciinema)
│   ├── gen-facts.sh           # Refresh demo/facts/nixpkgs.kif from pinned nixpkgs
│   ├── scenes/                # 01-30-seconds, 02-capabilities, 03-pages, 04-crosswalk, 05-when-the-build-breaks
│   ├── nix/                   # Nix-side digests the scenes print (org digest, crosswalk, policy)
│   └── facts/nixpkgs.kif      # Pinned real-nixpkgs facts (committed, offline)
├── nix-eval.sh                # Convenience wrapper (local store dirs, --impure)
├── run-tests.sh               # Whole suite in one go
├── spike/                     # Capability discovery VM (optional)
└── org/ hf/ bags.nix tq.nix   # Other demos (Hugging Face tags, org pages, test bags)
```