# AGENTS.md — How to Develop This Repo Correctly

> **Status (current).** The demo ships **host-native**: `./tools/tour.sh` records
> `docs/demo/tour.cast` from the real CLI on this machine, and `./tools/shot.sh`
> renders the TUI. The NixOS-in-Podman work is **parked** in `container/` — it
> builds and boots but does not yet pass its own gate. The VM instructions below
> describe `container/vm/` (superseded) and are kept only for the store mechanics
> that still apply to any future build.

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

---

## Nix Development Best Practices

### 1. Always Pin, Never Float

```nix
# BAD — will break when nixpkgs updates
{ pkgs ? import <nixpkgs> {} }:

# GOOD — pinned via flake.lock
{ pkgs ? import (builtins.getFlake "github:NixOS/nixpkgs/nixos-unstable") {} }:

# BEST — flake inputs with explicit rev
inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
```

Every build must be reproducible from `flake.lock`. `nix build .#nixosConfigurations.demo` is the contract.

### 2. Separate Eval from Build

```nix
# Eval-only (fast, no store writes, no substitutes needed)
nix eval --impure --expr '(import <nixpkgs> {}).stdenv.outPath'

# Build (needs store, substitutes, possibly namespaces)
nix build --store local?root=.nix-root --impure --expr '(import <nixpkgs> {}).hello'
```

This repo uses the local store (`.nix-store/`) for all eval work — tests, `sumo`, `demo/run`. The VM build is the **only** thing that uses the root store (`.nix-root/`).

### 3. Use `--impure` Only When Necessary

```nix
# Pure evaluation (preferred) — no external state
nix eval --expr 'builtins.currentTime'          # FAILS: time is impure

# Impure evaluation — explicitly opt in
nix eval --impure --expr 'builtins.currentTime' # WORKS
```

In this repo: `--impure` is needed for `<nixpkgs>` lookup and `builtins.path` with absolute paths. Document why when you add it.

### 4. Write Nix, Not Shell, for Logic

```bash
# BAD — shell string manipulation on Nix data
nix eval --raw --expr '...' | jq -r '.[] | select(.foo == "bar")'

# GOOD — Nix does the filtering
nix eval --raw --expr '
  let pkgs = import <nixpkgs> {}; in
  builtins.filter (p: p.foo == "bar") pkgs.allPackages
'
```

Shell is for orchestration (`tools/env.sh`, `demo/vm.sh`), Nix is for computation (`bin/_sumo.nix`, `rules.kif`).

### 5. Explicit Is Better Than Implicit

```nix
# BAD — relies on NIX_PATH, ambiguous
import <nixpkgs/nixos>

# GOOD — explicit path, reproducible
import /path/to/nixpkgs/nixos { system = "x86_64-linux"; }
```

In `_sumo.nix`: the dispatcher receives `facts` and `rules` as explicit string paths, not via environment or global state.

### 6. Don't Fight the Store

| Pattern | Why It's Wrong | Correct Alternative |
|---|---|---|
| `builtins.storePath "/nix/store/...foo"` in expressions | Hardcodes a hash that changes | Pass the path as an argument |
| `import /nix/store/...` in a derivation | Same hash problem | Use `builtins.getFlake` or flake inputs |
| `system.build.vm` without pinning nixpkgs | Non-reproducible image | Pin via flake input |
| `nix build` without `--store` in this repo | Defaults to system `/nix/store` (unwritable) | Use `--store $SUMONIX_BUILD_STORE` |

---

## SUMONix-Specific Patterns

### 1. The Dispatcher Pattern (`bin/_sumo.nix`)

A single Nix file exports an attrset of all subcommands:

```nix
# bin/_sumo.nix — returns { status, caps, closure, query, whatif, topology, ... }
{ facts, rules, json ? false }:
let
  # all the engine logic here
in
{
  status = ...;
  caps = ...;
  # ...
}
```

The shell wrapper (`bin/sumo`) just:
1. Sources `tools/env.sh` for store paths
2. Calls `nix eval --impure --expr "(import ./_sumo.nix { facts = \"...\" rules = \"...\" json = true; }).status"`
3. Prints the result

**Why:** Nix is the engine, shell is the CLI. The boundary is a single `nix eval` call per subcommand.

### 2. Facts Are Data, Rules Are Logic

```kif
# demo/vm/host-facts.kif — asserted facts (data)
(instance nginx NIXPackage)
(dependsOn nginx openssl)
(vulnerable openssl CVE-2026-9999)
(severity CVE-2026-9999 critical)
(instance nginx NIXService)
(serviceState nginx running)

# rules.kif — derives conclusions (logic)
(rule vulnerable (pkg cve)
  (when (instance pkg NIXPackage))
  (when (vulnerable dep cve))
  (when (dependsOnTransitive pkg dep)))

(rule policyViolation (pkg name)
  (when (instance pkg NIXPackage))
  (when (instance pkg NIXService))
  (when (serviceState pkg running))
  (when (vulnerable pkg cve))
  (when (severity cve critical))
  (then (policyViolation pkg name)))
```

Facts change per-machine. Rules are universal. The dispatcher loads both and runs the engine.

### 3. The Proof Is the Output

Every `sumo` subcommand that answers a question prints the **proof tree**, not just the conclusion:

```bash
$ sumo query '(vulnerable nginx CVE-2026-9999)'
(verdict violation)
  (vulnerable nginx CVE-2026-9999) by vulnerable#3
    (instance nginx NIXPackage) asserted
    (dependsOnTransitive nginx openssl) by dependsOnTransitive#2
      (dependsOn nginx openssl) asserted
    (vulnerable openssl CVE-2026-9999) asserted
    (severity CVE-2026-9999 critical) asserted
```

**If there's no proof, it's not a valid answer.** The TUI renders the same proof.

### 4. `--json` for Machine Consumption

Every subcommand supports `--json`:

```bash
$ sumo status --json
{"services":1,"packages":6,"capabilities":10,"rounds":29,"verdict":"violation","proof":"..."}
```

The TUI (`demo/vm/tui/`) calls `sumo status --json`, `sumo caps --json`, `sumo whatif --json` and parses the structured output. No screen-scraping.

### 5. Curated Facts for Reproducible Demos

The VM runs with `demo/vm/host-facts.kif` — 30 lines of curated facts that mirror the engine's test facts. This makes the demo deterministic and recordable without a VM:

```bash
# Same output, no VM needed
./tools/tour.sh   # → docs/demo/tour.cast (asciinema)
./tools/shot.sh   # → docs/demo/dashboard.png (TUI dump)
```

The VM's `sumo-facts.service` copies the same file to `/run/sumo/facts.kif` at boot. The session is identical whether you're in the VM or on the host.

---

## Testing Philosophy

### 1. Tests Are Eval-Only

```bash
$ ./run-tests.sh
# 21 tests, all nix eval, zero builds
```

Tests evaluate pinned expressions against the warm local store. They never:
- Build derivations
- Write to the store (except the eval cache)
- Depend on external services

### 2. Byte-Identical Demo Is a Test

```bash
$ ./demo/run > /tmp/before.txt
# ... make changes ...
$ ./demo/run > /tmp/after.txt
$ diff /tmp/before.txt /tmp/after.txt   # MUST be empty
```

The offline demo (`demo/`) is the integration test. If its output changes, the engine semantics changed.

### 3. README Generation Is a Test

```bash
$ ./tools/check-readme.sh   # exits 0 iff README.md == build-readme.sh output
```

The README is generated from parts. Drift is a failing test.

### 4. The Two-Run Budget

```bash
$ time ./bin/sumo status      # cold: ~3 s (first eval)
$ time ./bin/sumo status      # warm: ~1 s (memoized)
```

Policy eval must stay under 3 s cold, 1 s warm. This is the pacing budget for the demo.

---

## Code Organization

```
bin/
  sumo                # shell CLI wrapper (sources tools/env.sh, calls nix eval)
  _sumo.nix           # Nix dispatcher: all subcommands as attrset
demo/
  run                 # orchestrator for 5 demo scenes
  scenes/             # individual scene scripts (bash + nix eval)
  vm/
    vm.nix            # NixOS VM configuration
    build.sh          # builds VM via flake + root store
    host-facts.kif    # curated machine facts (30 lines)
    session.sh        # scripted tour (keystrokes)
    tui/
      main.go         # Go TUI (tcell + tui-go), --dump for screenshots
      sumo-tui        # built binary
  lib.sh              # shared bash helpers (sources tools/env.sh)
lib/
  kif.nix             # shared Nix helpers (isVar, show, headOf, unique, ...)
policy/
  relax.nix           # what-if counterfactuals
  soft-rules.nix      # relaxation menu
rules.kif             # universal rules (engine logic)
tools/
  env.sh              # shared environment (NIX_STORE_DIR, SUMONIX_BUILD_STORE)
  build-readme.sh     # concatenates docs/readme/*.md + includes
  check-readme.sh     # verifies README.md is generated
  shot.sh             # TUI --dump → PNG (chromium headless)
  tour.sh             # asciinema of tour-session.sh
  tour-session.sh     # the exact demo session commands
spike/                # exploration (not production)
tests/
  *.nix               # 21 eval-only tests
```

### Import Rules

- `bin/` → sources `tools/env.sh`, imports `lib/kif.nix` via flake
- `demo/` → sources `tools/env.sh` (for `run-tests.sh`, `demo/lib.sh`)
- `lib/` → pure Nix, no shell, no store assumptions
- `tools/` → pure bash, sources `tools/env.sh`
- `spike/` → anything goes, not in test suite

---

## Debugging Tips

### 1. Inspect a `.drv` to See Store Paths

```bash
# What store prefix is baked in?
grep -o '/home/me/sumonix/.nix-store' .nix-store/some.drv | wc -l
grep -o '/nix/store'                .nix-store/some.drv | wc -l
```

### 2. Check Substitutability

```bash
# Does cache.nixos.org have this path?
curl -sI https://cache.nixos.org/pa6rydwgjxxmmvdxap7qk9c85h8jbimy.narinfo
# → 200 = yes, 404 = no (wrong hash / not built yet)
```

### 3. Trace Nix Evaluation

```bash
# Show what Nix is evaluating
nix eval --impure --show-trace --expr '...'
```

### 4. Debug the Dispatcher

```bash
# Raw Nix output for a subcommand
nix eval --impure --raw -I nixpkgs=channel:nixos-unstable \
  --expr '(import ./bin/_sumo.nix { facts = "./demo/vm/host-facts.kif"; rules = "./rules.kif"; }).status'
```

### 5. Demo Diff Checklist

When a test fails or demo output changes:

```bash
# 1. Run the full demo
./demo/run > /tmp/after.txt
diff /tmp/before.txt /tmp/after.txt

# 2. Check the dispatcher directly
./bin/sumo status --json | jq .

# 3. Check the engine trace
./bin/sumo status 2>&1 | grep -A 20 'proof'

# 4. If policy verdict changed, check what-if
./bin/sumo whatif --json | jq .
```

---

## Workflow Guidelines

### 1. Every Change Must Pass the Suite

```bash
./run-tests.sh              # 21 tests
./tools/check-readme.sh     # README drift
./demo/run                  # byte-identical output
```

Commit only when all three pass.

### 2. One Logical Change Per Commit

```bash
# Good: extract helper, verify demo diff empty
git commit -m "C1: extract isVar to lib/kif.nix

- Moved isVar from datalog.nix, reasoner/*.nix to lib/kif.nix
- datalog.nix uses isEngineVar (? only), reasoners use isVar (? or @)
- demo diff empty, tests green"

# Bad: "fix stuff"
git commit -m "fixes"
```

### 3. Document the Why, Not the What

```bash
# BAD
git commit -m "add sandbox false"

# GOOD
git commit -m "demo/vm/build.sh: add --option sandbox false

Without it, nix refuses to build in the diverted root store on this
kernel (unprivileged_userns_clone=0). Substitution works; only the
build step is blocked."
```

### 4. Update AGENTS.md When You Discover a New Pattern

If you hit a Nix behavior that isn't documented here, add it. This file is the institutional memory.

---

## Quick Debugging Reference

```bash
# "Why is my build not substituting?"
curl -sI https://cache.nixos.org/<hash>.narinfo   # 404 = wrong hash

# "What store prefix is in my .drv?"
grep -o '/home/me/...' .nix-store/foo.drv | head -1

# "Is my eval using the right store?"
nix eval --impure --expr 'builtins.getEnv "NIX_STORE_DIR"'

# "Why is the demo output different?"
diff <(./demo/run) /tmp/baseline.txt

# "What does the dispatcher actually return?"
nix eval --impure --raw -I nixpkgs=channel:nixos-unstable \
  --expr '(import ./bin/_sumo.nix { facts = "./demo/vm/host-facts.kif"; rules = "./rules.kif"; }).status'

# "What's in the local store vs root store?"
ls .nix-store/nix/store/ | head -5    # .drv files, no outputs
ls .nix-root/nix/store/ | head -5     # real outputs from cache.nixos.org
```

---

## The Mental Model (Complete)

```
┌─────────────────────────────────────────────────────────────────────┐
│                        DEVELOPER MACHINE                            │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  .nix-store/              .nix-root/              demo/vm/         │
│  ─────────────            ─────────────           ─────────────    │
│  logical: .nix-store/...  logical: /nix/store/...  result-vm/      │
│  physical: same           physical: .nix-root/...   (VM image)     │
│  ─────────────            ─────────────           ─────────────    │
│  purpose: EVAL ONLY       purpose: BUILD/FETCH      purpose: BOOT  │
│  ─────────────            ─────────────           ─────────────    │
│  populated by:            populated by:           built by:        │
│  flake.lock eval cache    cache.nixos.org +       flake build      │
│  (tests, demo, sumo)      local builds            via --store      │
│                                                                     │
│  NO substitutes           YES substitutes          uses curated    │
│  (hashes don't match)     (hashes match)          facts at boot    │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
                    ┌─────────────────────┐
                    │    cache.nixos.org  │
                    │  (binary cache)     │
                    │  keys: /nix/store/  │
                    └─────────────────────┘
```

**The prefix is part of the hash.** That is the only thing to remember.