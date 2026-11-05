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

**Unit tests:** `./run-tests.sh` runs every test in `tests/`, including the unit suites (`equivalents`, `synthesize`, `stratify`, `relax`, `congruence`, `builtins`, `disjunctive`, `soft-rules`, `wfs`, `existentials`, `temporal`).