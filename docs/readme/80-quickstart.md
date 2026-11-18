## 🚀 Quick Start

```bash
# All tests in one go (uses the local store; safe to re-run)
./run-tests.sh

# Or individually (this wrapper sets the local store dirs and --impure for you)
./nix-eval.sh --expr 'import ./tests/default.nix'       # "ok"
./nix-eval.sh --expr 'import ./tests/rules.nix'          # "ok"
./nix-eval.sh --expr 'import ./tests/ingest-smoke.nix'   # "ok"
./nix-eval.sh --expr 'import ./tests/proof-check.nix'    # "ok"
./nix-eval.sh --expr 'import ./tests/unit/relax.nix'     # "ok"

# Replay the 60-second demo
./demo/run

# Generate the CVE proof artifact (deterministic, byte-identical)
./nix-eval.sh --raw --expr 'import ./tests/proof-artifact.nix' > proof.kif

# Re-check it independently (zero shared code with the engine)
./nix-eval.sh --expr '(import ./proof-check.nix { file = ./proof.kif; })'
# → "proof: 9 steps, independently re-checked ✓"
```

**Unit tests:** `./run-tests.sh` runs every test in `tests/`, including the unit suites (`equivalents`, `synthesize`, `stratify`, `relax`, `congruence`, `builtins`, `disjunctive`, `soft-rules`, `wfs`, `existentials`, `temporal`, `lift-config`, `drift`, `repair`, `metavisor`) and the metavisor tick smoke test.

### Resident metavisor (M3A)

```bash
# On any NixOS host: declared facts are lifted from the live system config,
# observed facts come from the dumb observer, and one timer tick turns the
# difference into a proof, a journal line and an append-only JSON event.
# imports = [ inputs.sumonix.nixosModules.sumonix-metavisor ];
# services.sumonix-metavisor.enable = true;

# The same operations without the module:
sumo lift --configuration /etc/nixos/configuration.nix > declared.kif
tools/observe.sh > observed.kif
sumo drift --declared declared.kif --observed observed.kif

# Repairs: one option edit per candidate, re-lifted and re-gated.
sumo repair --configuration /etc/nixos/configuration.nix

# The gate alone: exits 1 with the why-tree when the config contradicts system.kif.
sumo gate --configuration /etc/nixos/configuration.nix

# The event log (append-only, one JSON line per new drift/violation):
cat /var/lib/sumonix-metavisor/events.jsonl
journalctl -t sumonix-metavisor
```
