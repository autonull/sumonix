# AGENTS.md — How to Develop This Repo Correctly

## Core Principle

**A Nix store path hash is computed over a derivation whose inputs already carry their store paths. The store directory string is baked into every hash. Binary caches (cache.nixos.org) are keyed on `/nix/store/...`. Any store mechanism that changes the logical path prefix breaks substitution completely — every fetch 404s.**

---

## Two Store Mechanisms — Do Not Mix

| Mechanism | Logical Paths | Substitutes from cache.nixos.org | Builds | Use |
|---|---|---|---|---|
| `NIX_STORE_DIR=$ROOT/.nix-store` | `$ROOT/.nix-store/...` | **NO** — hashes differ, every fetch 404s | Yes (no namespaces needed) | Eval-only, pre-populated closures (tests, `./demo/run`, `./bin/sumo`) |
| `--store local?root=$ROOT/.nix-root` | `/nix/store/...` | **YES** — hashes match | Only with mount namespaces | Anything that must fetch or build (the VM) |

### Verified on this repo

```bash
# Sample .drv from the local store — 84 local-prefix refs, 0 /nix/store refs
grep -o '/home/me/sumonix/.nix-store' .nix-store/foo.drv | wc -l   # → 84
grep -o '/nix/store'               .nix-store/foo.drv | wc -l   # → 0

# The root store: logical /nix/store, physical in repo
nix build --store local?root=$PWD/.nix-root \
  --impure --expr '(import <nixpkgs> {}).hello'
# → copies 5 paths from cache.nixos.org into .nix-root/nix/store
```

### The hard rule

- **Eval-only work** (tests, `sumo`, `demo/run`) → `NIX_STORE_DIR=$ROOT/.nix-store`
- **Build/fetch work** (VM, any derivation that might need a substitute) → `--store local?root=$ROOT/.nix-root`
- **Never** point `NIX_STORE_DIR` at a store you expect to substitute from.

---

## The Kernel Requirement

Building in a diverted store requires **mount namespaces** (`unshare -r`). This kernel has them disabled:

```bash
sysctl kernel.unprivileged_userns_clone   # → 0 (disabled)
```

`--check` now reports this honestly:

```bash
$ ./demo/vm.sh --check
KVM: available
user namespaces: UNAVAILABLE
  Nix cannot build in a diverted store without mount namespaces.
  Substitution still works into /home/me/sumonix/.nix-root/nix/store.
  To enable: sudo sysctl -w kernel.unprivileged_userns_clone=1
SKIP: VM build/boot prerequisites not met
```

**One line unblocks the VM build:**
```bash
sudo sysctl -w kernel.unprivileged_userns_clone=1
```

Without it, alternatives are:
1. A one-time root-created `/nix/store` (standard Nix install), or
2. A from-source build in the plain local store (full NixOS closure — hours).

---

## Environment Setup

```bash
# tools/env.sh — sourced by all scripts
export NIX_STORE_DIR="$ROOT/.nix-store"
export NIX_STATE_DIR="$ROOT/.nix-state"

# For BUILDS (substitutes work):
export SUMONIX_BUILD_ROOT="$ROOT/.nix-root"
export SUMONIX_BUILD_STORE="local?root=$SUMONIX_BUILD_ROOT"
export SUMONIX_SUBSTITUTERS="https://cache.nixos.org"
export SUMONIX_TRUSTED_KEYS="cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
```

Every script that needs Nix sources this file. No environment leaks.

---

## Build the VM

```bash
./demo/vm.sh build
```

Uses the flake through the root store. All output stays in `.nix-root/` and `demo/vm/result-vm/`. `.gitignore` excludes both.

---

## Record Demo Artifacts (No VM Needed)

```bash
./tools/shot.sh       # → docs/demo/dashboard.png (TUI --dump → PNG)
./tools/tour.sh       # → docs/demo/tour.cast    (asciinema of real session)
```

Both use the **curated facts** (`demo/vm/host-facts.kif`) and the real `sumo` CLI. They do not depend on a VM build.

---

## Tests

```bash
./run-tests.sh        # 21 tests, all eval-only through local store
```

The test suite never builds — it evaluates pinned expressions against the warm local store.

---

## Common Mistakes (With Fixes)

| Mistake | Symptom | Fix |
|---|---|---|
| `NIX_STORE_DIR=.nix-store` for a build | All cache fetches 404; builds from source fail at bootstrap | Use `--store local?root=.nix-root` |
| Forgetting `NIX_STORE_DIR` in a script | Uses system `/nix/store` (read-only here) | Source `tools/env.sh` first |
| Adding `sandbox = true` | Build fails (no namespaces) | `--option sandbox false` or enable namespaces |
| Using `nix build` without `--store` | Defaults to system store (unwritable) | Pass `--store $SUMONIX_BUILD_STORE` |
| Hardcoding store paths in Nix code | Breaks when store location changes | Use `builtins.storePath` or the standard APIs |

---

## Why This Works

1. **Everything stays in the repo** — `.nix-store/`, `.nix-root/`, `demo/vm/result-vm/`, `docs/demo/` are all git-ignored project state.
2. **No root required** — the root store is a normal directory; substitution works without `/nix`.
3. **Substitution is verified** — `cache.nixos.org` serves the exact hashes Nix computes for `/nix/store/...`.
4. **Eval is fast** — the warm local store has all the closures from `flake.lock` (6–8 s cold, ~1 s warm).
5. **The VM config is correct** — it just needs the one kernel switch to build.

---

## Quick Reference

```bash
# Eval (all working commands)
./run-tests.sh
./demo/run
./bin/sumo status --json
./bin/sumo caps
./bin/sumo closure nginx
./bin/sumo query '(vulnerable nginx CVE-2026-9999)'
./bin/sumo whatif
./demo/vm/tui/sumo-tui --dump --sumo=./bin/sumo

# Build (needs kernel.unprivileged_userns_clone=1)
./demo/vm.sh --check        # honest gate
./demo/vm.sh build          # builds VM into demo/vm/result-vm
./demo/vm.sh boot           # boots VM interactively
./demo/vm.sh --record       # records asciicast

# Artifacts
./tools/shot.sh             # → docs/demo/dashboard.png
./tools/tour.sh             # → docs/demo/tour.cast
./tools/build-readme.sh     # → README.md
./tools/check-readme.sh     # verifies README.md is generated
```

---

## The Mental Model

```
nix build --store local?root=.nix-root
       │
       ├── logical paths = /nix/store/...  (cache hashes match)
       └── physical NARs = .nix-root/nix/store/... (repo-contained)
```

vs.

```
NIX_STORE_DIR=.nix-store nix build
       │
       ├── logical paths = .nix-store/...  (cache hashes DO NOT match)
       └── physical NARs = .nix-store/...  (repo-contained but useless for subs)
```

**The prefix is part of the hash.** That is the only thing to remember.