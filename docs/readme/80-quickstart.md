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
```

**Replay the 60-second demo:**
```bash
./demo/run
```

**Generate the CVE proof artifact (deterministic, byte-identical):**
```bash
./nix-eval.sh --raw --expr 'import ./tests/proof-artifact.nix' > proof.kif
```

**Re-check it independently (zero shared code with the engine):**
```bash
./nix-eval.sh --expr '(import ./proof-check.nix { file = ./proof.kif; })'
# → "proof: 9 steps, independently re-checked ✓"
```

**Unit tests:** `./run-tests.sh` runs every test in `tests/`, including the unit suites (`equivalents`, `synthesize`, `stratify`, `relax`, `congruence`, `builtins`, `disjunctive`, `soft-rules`, `wfs`, `existentials`, `temporal`, `lift-config`, `drift`, `repair`, `metavisor`, `diag`, `runtime-policy`) and the metavisor tick smoke test.

---

### 🛰 Resident Metavisor (M3A) — Live Drift Detection

```bash
# On any NixOS host: enable the systemd timer
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

---

### 🔬 Phase 3 Commands (New)

```bash
# Schema Mapper: parse JSON to KIF
sumo pack add github:myorg/policy-pack

# Audit: vulnerabilities + licenses from flake.lock
sumo audit --json

# Plan: create a verified transition bundle
sumo plan --goal '(policyViolation "nginx" "NoFirewallAllowance")' --json

# Apply: verify and apply a bundle (L2: human-approved)
sumo apply --bundleId <id>
```