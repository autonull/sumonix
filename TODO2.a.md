# TODO2.a.md — Critical-Path End-to-End Spike
**Self-contained development plan for a capability-demonstrating PoC using existing sumo-nix infrastructure, executed inside a NixOS VM.**

---

## 1. Spike Objective

Demonstrate **semantic reasoning over real Nixpkgs metadata** using the existing sumo-nix Datalog engine (`datalog.nix`), **running inside a NixOS virtual machine**, producing a verifiable proof that answers an inspiring question:
> *"What novel software capabilities can I compose from my available packages?"*

This proves the full pipeline: **real data → KIF facts → Datalog inference → explanation** — **inside a real NixOS system** — but framed as **capability discovery** (what's possible) rather than vulnerability tracking (what's broken).

---

## 2. Scope Boundaries (What This Spike Does NOT Do)

| Out of Scope | Reason |
|---|---|
| New Rust daemon / eBPF / LLM / NixOS module integration | Uses only existing Nix/mlnix evaluation |
| Full Nixpkgs bootstrap (100k packages) | Uses a curated subset (~50 packages) for speed |
| Persistent fact store / SQLite / TMS | In-memory Datalog per `datalog.nix` is sufficient |
| Policy engine / planning / overlays | Read-only query + explanation is the demo |
| Ontology versioning / migration | Uses pinned SUMO from `pins.nix` |

---

## 3. Critical Path (5 Tasks)

### Task A: Curate a Minimal Nixpkgs Snapshot (1–2 hrs) ✅ **DONE**
**Goal:** Extract metadata from ~50 real Nixpkgs packages into a KIF fact file, including **capabilities each package provides**.

**Method:** Single Nix expression that evaluates target packages and emits KIF directly to stdout (no intermediate file needed for VM).

**File:** `spike/nixpkgs-snapshot.nix` — **IMPLEMENTED**

```nix
{ pkgs ? import <nixpkgs> {} }:

let
  targets = [
    "openssl" "curl" "nginx" "git" "python3" "nodejs" "postgresql" "redis"
    "libssh2" "wget" "zlib" "libxml2" "libxslt" "sqlite" "readline" "ncurses"
    "gcc" "glibc" "coreutils" "bash" "grep" "sed" "awk" "findutils" "diffutils"
    "make" "cmake" "pkg-config" "autoconf" "automake" "libtool" "m4"
    "openssh" "gnutls" "libgcrypt" "libgpg-error" "pcre2" "icu" "libffi"
    "gettext" "expat" "bzip2" "xz" "zstd" "lz4" "libarchive" "gdbm" "dbus"
    "systemd" "util-linux" "e2fsprogs" "kbd" "less" "vim"
  ];

  # Map packages to capabilities they provide
  capabilities = {
    openssl = [ "TLS" "Crypto" "X509" ];
    curl = [ "HTTPClient" "FileTransfer" ];
    nginx = [ "HTTPServer" "ReverseProxy" "LoadBalancer" ];
    git = [ "VersionControl" "DistributedSync" ];
    python3 = [ "Scripting" "DataScience" "WebFramework" "ML" ];
    nodejs = [ "JavaScriptRuntime" "WebServer" "PackageManager" ];
    postgresql = [ "RelationalDB" "ACID" "SQL" ];
    redis = [ "KeyValueStore" "PubSub" "Cache" ];
    # ... (50 packages mapped)
  };

  toKIF = name: pkg:
    let
      deps = pkg.propagatedBuildInputs ++ pkg.buildInputs;
      depNames = lib.map (d: d.pname) deps;
      caps = capabilities.${name} or [];
      capFacts = lib.concatStringsSep "\n" (lib.map (c: "(providesCapability ${name} ${c})") caps);
    in ''
      (instance ${name} NIXPackage)
      ${lib.concatStringsSep "\n" (lib.map (d: "(dependsOn ${name} ${d})") depNames)}
      (hasLicense ${name} ${pkg.meta.license.spdxId or "unknown"})
      ${capFacts}
    '';

  kifFacts = lib.concatStringsSep "\n" (lib.mapAttrsToList (n: toKIF n) (lib.filterAttrs (n: v: lib.elem n targets) pkgs));
in
kifFacts
```

**Validation:** `nix eval --raw --expr '(import ./spike/nixpkgs-snapshot.nix {})' | head -20` prints valid KIF with `providesCapability` facts.

---

### Task B: Define Capability Composition Rules (30–60 min) ✅ **DONE**
**Goal:** Encode transitive dependency closure + capability composition inference in KIF using SUMO-aligned predicates.

**Files:** `spike/vuln-rules.kif` (composition rules) + `spike/capabilities.kif` (seed facts) — **IMPLEMENTED**

```kif
;; SUMO-aligned capability composition rules
;; Capability subclasses SoftwareCapability (per nix-domain.kif)
;; composesWith is a BinaryRelation; transitive closure via Datalog

;; Direct composition: A provides X, B provides Y, X composesWith Y
(=>
  (and
    (instance ?pkg NIXPackage)
    (providesCapability ?pkg ?capA)
    (composesWith ?capA ?capB)
    (providesCapability ?other ?capB)
    (dependsOn ?pkg ?other))
  (canCompose ?pkg ?capA ?capB))

;; Transitive composition chains
(=>
  (and (composesWith ?a ?b) (composesWith ?b ?c))
  (composesWithTransitive ?a ?c))

(=>
  (and (composesWith ?a ?b) (composesWithTransitive ?b ?c))
  (composesWithTransitive ?a ?c))

;; Find novel capability combinations a package enables
(=>
  (and
    (instance ?pkg NIXPackage)
    (providesCapability ?pkg ?cap)
    (composesWithTransitive ?cap ?otherCap)
    (providesCapability ?dep ?otherCap)
    (dependsOnTransitive ?pkg ?dep))
  (enablesCapability ?pkg ?otherCap))

;; Capability synergy: when 3+ capabilities combine
(=>
  (and
    (enablesCapability ?pkg ?cap1)
    (enablesCapability ?pkg ?cap2)
    (enablesCapability ?pkg ?cap3)
    (not (equal ?cap1 ?cap2))
    (not (equal ?cap1 ?cap3))
    (not (equal ?cap2 ?cap3)))
  (synergy ?pkg ?cap1 ?cap2 ?cap3))
```

Note the required 1-hop base rules — `(=> (dependsOn ?a ?b) (dependsOnTransitive ?a ?b))` and `(=> (composesWith ?a ?b) (composesWithTransitive ?a ?b))` — and SUO-KIF `equal` for the disequalities. See `spike/vuln-rules.kif`.

**Validation:** `nix eval --impure --raw --expr 'import ./spike/run-spike.nix { snapshot = builtins.readFile /tmp/opencode/facts.kif; }'` — prints the discovery report; no errors. (The earlier `mlnix eval` validation line was aspirational; this host has no `mlnix`, so testing used `nix eval`.)

---

### Task C: Spike Driver — Pure Nix, Uses Actual sumo-nix Library (1 hr) ✅ **DONE (verified locally)**
**Goal:** Single Nix expression that loads SUMO, adds facts/rules, runs capability discovery queries, returns formatted results.

**Files:** 
- `spike/run-spike.nix` — **IMPLEMENTED, tested** (queries for compositions, enabled capabilities, synergies; verified locally via `nix eval --impure --expr 'import ./spike/run-spike.nix { snapshot = builtins.readFile /tmp/opencode/facts.kif; }'`)
- `spike/vuln-rules.kif`, `spike/capabilities.kif` — **IMPLEMENTED, tested** (read by run-spike.nix; no duplication)

**Implementation (see `spike/run-spike.nix`):** Loads SUMO (`sumo.full/Merge.kif` + `nix-domain.kif`) via `kif.parse`, splits parsed forms into Horn rules (`head == "=>"`) and ground facts, and calls the real `datalog.nix` API:

- `ontology = import ../sumo.nix { forms = kif.parse (readFile ../sumo.full/Merge.kif) ++ kif.parse (readFile ../nix-domain.kif); }`
- `e = import ../datalog.nix { inherit ontology rules facts; };`
- `e.ask [ "canCompose" "?pkg" "?capA" "?capB" ]` (s-expression lists, not strings)
- facts/rules read from `spike/capabilities.kif` and `spike/vuln-rules.kif` (no duplicated strings)
- synergy triples deduplicated per (pkg, unordered caps); proof trees via `e.explain`

---

### Task D: NixOS VM — Minimal, Flake-Free (1–2 hrs) ✅ **DONE (impl) — ⏳ boot test blocked**
**Goal:** Boot a NixOS VM that generates facts on startup, runs the spike, prints proofs to console.

**Status:** Implemented and **the VM config evaluates cleanly** (`vm.drvPath` builds the derivation graph, assertions pass). The VM **cannot be built or booted in the current sandbox** (no writable `/nix/store`, no kernel namespaces for the build sandbox, no qemu on host). Boot verification must happen on a normal host or CI — see §12.

**File:** `spike/vm.nix` — **IMPLEMENTED** (standalone module, no flake needed)

**Implementation (see `spike/vm.nix`):** the current code — not the original sketch — does the following:

- Copies the repo into the VM with `builtins.path { path = ../.; filter = ...; }` excluding `.git`, `.nix-store`, `.nix-state`, build outputs — the old `cp -r /home/me/sumonix/*` copied the 831 MB local store into the image.
- Passes the building host's nixpkgs to the VM as `pkgs.path` (via `NIX_PATH` inside the runner) so `nixpkgs-snapshot.nix`'s `import <nixpkgs> {}` evaluates offline inside the guest.
- `sumo-spike` oneshot service (`after = [ "local-fs.target" ]`) runs: generate facts to `/run/sumo-facts.kif` (`nix --extra-experimental-features nix-command eval --impure`), then run the spike (`--impure` required — absolute `readFile /run/sumo-facts.kif` is forbidden in pure eval).
- Guest resources via `virtualisation.vmVariant.virtualisation.memorySize = 4096; cores = 4;` (the `virtualisation.cores` option exists only in the VM-variant module set, not top level).
- The classic VM direct-boots the kernel (`useBootLoader = false`); `boot.loader.grub.enable = false` + a tmpfs `/` satisfy eval-time assertions; no GRUB device needed.
- Serial console `console=ttyS0` + `getty@ttyS0` for the boot log; `journal+console` for the spike output.
- `<nixpkgs/nixos>` re-exports `vm` — the attribute to build is **`vm`** (the plan's original `system.build.vm` does not exist there).

**Build command (no flake):**
```bash
nix build -f "${NIXPKGS_PATH}/nixos" vm -I nixos-config=./spike/vm.nix
```
(Plain `nix build -f '<nixpkgs/nixos>' system.build.vm` was wrong twice: wrong attribute and `<nixpkgs>` unresolved — `spike/demo.sh` now resolves nixpkgs itself via `(builtins.getFlake "nixpkgs").outPath`.)

**Verification status:** `nix eval -f "$NIXPKGS_PATH/nixos" vm.drvPath -I nixos-config=./spike/vm.nix` **succeeds** (full module evaluation, assertions pass, image derivation produced). VM **build + boot not possible in the current sandbox** (see §12).

---

### Task E: Demo Script — Robust, Times Out Cleanly (30 min) ✅ **DONE (impl) — ⏳ boot test blocked**
**Goal:** One command builds VM, boots it, captures capability discovery output, exits cleanly.

**File:** `spike/demo.sh` — **IMPLEMENTED** (resolves nixpkgs via `(builtins.getFlake "nixpkgs").outPath`, builds `${NIXPKGS_PATH}/nixos` attribute **`vm`**, boots with a configurable `SPIKE_TIMEOUT` (default 180s), captures the banner-to-footer report via the same awk filter, fails loudly if the spike output never appears)

**Run:**
```bash
cd spike && ./demo.sh
```

---

## 4. File Manifest (Minimal)

```
spike/
├── nixpkgs-snapshot.nix     # Task A: emits KIF to stdout (50 packages + capabilities, dep-name aliases)
├── vuln-rules.kif           # Task B: capability composition rules (with 1-hop base cases)
├── capabilities.kif         # Task B: 24 composesWith seed facts
├── run-spike.nix            # Task C: driver, 2 closure queries + synergy, deduplicated, formatted output
├── vm.nix                   # Task D: NixOS module (no flake); vmVariant memory/cores
└── demo.sh                  # Task E: resolve nixpkgs, build `vm`, boot, capture
```

**6 spike files.** No generated files committed (facts generated at VM boot). The repo root gains a `.gitignore` for `.nix-store/`, `.nix-state/` and build outputs (this host builds nix with a diverted local store).

---

## 5. Dependencies & Prereqs

| Tool | Version | Notes |
|---|---|---|
| Nix | 2.18+ | `nix build -f "${NIXPKGS_PATH}/nixos" vm` (nixpkgs resolved via `builtins.getFlake`) |
| QEMU/KVM | any | VM runtime; used via `pkgs.qemu_kvm` inside the VM closure |
| writable `/nix/store` + kernel namespaces | — | **Required to build** — not available in the current sandbox |
| sumo-nix | local | Copied into the VM image; paths read via `builtins.readFile` at eval time |

---

## 6. Timeline & Milestones (Compressed)

| Time | Milestone | Status |
|---|---|---|
| 0:00–1:30 | Task A: `nix eval` prints valid KIF for 50 packages | ✅ **DONE — verified** |
| 1:30–2:30 | Task B: rules load, no syntax errors | ✅ **DONE — verified** |
| 2:30–3:30 | Task C: `nix eval` with manual facts file prints proofs | ✅ **DONE — verified** |
| 3:30–5:00 | Task D: VM config evaluates (`vm.drvPath`) | ✅ **DONE** — boot/build pending host |
| 5:00–5:30 | Task E: `./demo.sh` runs end-to-end, prints proof trees | ⏳ **BLOCKED** — needs host/CI with writable store + namespaces |

**Total: ~5.5 hours implementation.** The spike's reasoning pipeline is fully verified locally (facts → Datalog closure → synergies → proof trees). Only the VM image build/boot remains, blocked by the sandbox (see §12).

---

## 7. Why This Spike Motivates Further Work

| Dimension | What the Spike Proves |
|---|---|
| **Data realism** | Live Nixpkgs eval → KIF at boot (not static snapshot) |
| **Reasoning power** | Transitive closure + vuln propagation in 3 KIF rules |
| **Explainability** | `datalog.explain` → audit-ready proof trees |
| **NixOS integration** | Runs as systemd service, uses activation script, no flake |
| **Reproducibility** | Pure Nix build, no hidden state |
| **Extensibility** | Add a rule to `vuln-rules.kif` → rebuild VM → new query works |

---

## 8. Next Steps After Spike (Not Part of This Plan)

1. **Lazy incremental bootstrap** — Cache package facts, invalidate on metadata change.
2. **Policy pack registry** — Flake-based, signed KIF rule sets (security, license, caps).
3. **Live advisory ingest** — OSV/NVD fetchers → continuous `cve-seed.kif` updates.
4. **Reasoner daemon** — Rust/Ascent + TMS, replaces `mlnix eval` for latency.
5. **Self-healing overlay** — Spike output → Nix overlay → `nixos-rebuild switch --rollback`.
6. **Neuro-symbolic gateway** — LLM → typed Goal → Datalog plan → executor.

---

## 9. Quick Start (for Reviewer)

```bash
cd /home/me/sumonix/spike
./demo.sh                    # Builds VM, boots it, runs spike, prints proof trees
```

**Fallback (no QEMU — used on this host):**
```bash
# Facts (nixpkgs eval must run with flakes enabled)
nix --extra-experimental-features 'nix-command flakes' eval --impure --raw \
  --expr 'let pkgs = import (builtins.getFlake "nixpkgs") {}; in (import ./spike/nixpkgs-snapshot.nix { inherit pkgs; })' \
  > /tmp/facts.kif
# Reasoning (no VM needed — pure evaluation)
nix --extra-experimental-features 'nix-command flakes' eval --impure --raw \
  --expr 'import ./spike/run-spike.nix { snapshot = builtins.readFile /tmp/facts.kif; }'
```

---

## 10. Spike-to-Vision Traceability Matrix

This spike is not a throwaway demo — every artifact **directly seeds** the full architecture in TODO.md/TODO2.md.

| Spike Artifact | Full-System Evolution | Vision Reference |
|---|---|---|
| `nixpkgs-snapshot.nix` | **Epistemic Bootstrap** — lazy, cached, incremental Nixpkgs→KIF pipeline for 100k packages | TODO.md §3.1, TODO2.md §2 |
| `vuln-rules.kif` | **Policy Packs** — composable, versioned KIF rule sets (security, licensing, capability) loaded as flakes | TODO.md §25.4, TODO2.md §4 |
| `cve-seed.kif` | **Live Fact Ingestion** — OSV/NVD/GitHub Advisory APIs → continuous KIF streams via `sumo-nix` fetchers | TODO.md §18, TODO2.md §5 |
| `run-spike.nix` | **Reasoner Core** — `datalog.nix` generalized to incremental TMS, temporal Datalog, neuro-symbolic gateway | TODO2.md §4, §8, §11 |
| `vm.nix` (standalone module) | **Self-Referential NixOS Module** — `services.sumo-reasoner` managing its own config via overlays | TODO2.md §3, §9, §14 |
| `demo.sh` (VM boot) | **CI/CD Integration** — `nix flake check` runs policy queries on PR diffs; VM tests for integration | TODO.md §22, TODO2.md §10 |

### Growth Path: From Spike to System

```
Phase 0 (This Spike)          Phase 1 (Weeks 1-4)           Phase 2 (Weeks 5-12)          Phase 3 (Months 4-6)
────────────────────────      ────────────────────────      ────────────────────────      ────────────────────────
nixpkgs-snapshot.nix    →     Lazy incremental bootstrap    →     Epistemic flakes          →     Distributed ontology
    (50 pkgs, eager)            (100k pkgs, cached)             (signed, versioned)            (multi-node consensus)

vuln-rules.kif          →     Policy pack registry          →     PID-guarded policies      →     Cybernetic control loops
    (7 rules)                  (security, license, caps)         (hysteresis, cooldowns)         (Temporal Datalog)

cve-seed.kif            →     Live advisory ingest          →     Data derivations            →     Stateful transitions
    (1 static fact)             (OSV/NVD streams)                 (migrations, snapshots)         (ZFS/rsync checkpoints)

run-spike.nix           →     Reasoner daemon (Rust)        →     Self-healing overlays       →     Neuro-symbolic intent
    (mlnix eval)                (Ascent Datalog + TMS)            (nixos-rebuild trigger)         (LLM→Goal→Plan→Exec)

vm.nix                  →     services.sumo-reasoner        →     Self-management dogfood     →     Hardware-aware reasoning
    (oneshot service)            (daemon + eBPF + DBus)            (manages own resources)           (IPMI/Redfish)

demo.sh                 →     nix flake check + VM tests    →     Property-based verification →     Formal proof certificates
    (manual VM boot)             (CI integration)                  (Proptest + NixOS test driver)   (Coq/Lean export)
```

### Key Architectural Commitments Locked In By This Spike

1. **SUMO as upper ontology** — `NIXPackage` subclasses `SoftwareArtifact` (per `nix-domain.kif`)
2. **KIF as interchange** — All facts/rules/queries in SUO-KIF; no proprietary DSL
3. **Datalog as reasoning kernel** — `datalog.nix` is the reference; future Rust port preserves semantics
4. **Nix as executor** — Overlays → `nixos-rebuild`; no custom deployment tooling
5. **NixOS as substrate** — VM proves the reasoner runs *on* what it reasons *about*
6. **Explanation as first-class** — `datalog.explain` output is the audit trail; no black-box decisions

### Anti-Patterns Explicitly Avoided (Per TODO2.md §16)

| Forbidden | Spike Compliance |
|---|---|
| External schema mappers (TOML/YAML) | ✅ Native Nix eval → KIF |
| Custom event logs for config history | ✅ Nix Generations (via VM) |
| Secondary scripting (Rhai/Lua/Rego) | ✅ Pure KIF/Datalog |
| Abstract action graphs | ✅ Direct Nix overlay generation (Phase 1) |
| Graph databases (Neo4j) | ✅ In-memory Datalog + SQLite ring buffer (Phase 1) |

---

## 11. Success Criteria for "Seeding Complete"

The spike has successfully seeded the full potential when:

- [x] Capability discovery pipeline runs end-to-end (facts → Datalog → report) — **VERIFIED on this host** (see §12)
- [ ] `./demo.sh` runs end-to-end in a clean environment (CI-verified) — **BLOCKED in current sandbox** (no `/nix/store`, no build namespaces)
- [x] Capability discovery output is human-readable, inspiring, and cites source facts + rules — **IMPLEMENTED + VERIFIED**
- [x] All KIF uses SUMO classes per `nix-domain.kif` — **IMPLEMENTED** (`NIXPackage` subclass of `ComputerProgram`; relations `dependsOn`/`providesCapability`)
- [ ] VM builds on `x86_64-linux` and `aarch64-linux` (no flake required) — **VM config evaluates** (`vm.drvPath` OK); **build not possible here**; aarch64 untested
- [x] No modifications to `kif.nix`, `sumo.nix`, `datalog.nix` required — **CONFIRMED**
- [x] Next developer can add a new capability composition in 15 minutes by editing `capabilities.kif` — **DESIGNED FOR THIS + USED IT** (2 seeds added in this pass)

---

## 12. Implementation Notes (2026-11-04, second pass)

### Files Changed
| File | What changed |
|---|---|
| `spike/run-spike.nix` | **Rewritten against the real `datalog.nix` API**: `{ ontology rules facts }` args, Horn rules split by `head == "=>"`, queries as s-expression lists (`e.ask [ "canCompose" "?pkg" ... ]`), no phantom `lib`, repo-relative paths, `snapshot ? builtins.readFile /run/sumo-facts.kif` parameter for local testing, synergy triples deduplicated per (pkg, unordered caps), counts in section headers, `e.explain`-ready |
| `spike/vuln-rules.kif` | **Added missing 1-hop base cases** (`dependsOnTransitive`, `composesWithTransitive`) — without them no closure derives; disequalities use SUO-KIF `equal` instead of `=` (the engine's equality form; `=` matched nothing in facts) |
| `spike/capabilities.kif` | `"C++"` → `CPlusPlus` (quoted strings keep their quotes in this parser and never unified with the bare `C++` atom); added `(composesWith Crypto X509)` and `(composesWith VersionControl HTTPClient)`; restored mangled System compositions block |
| `spike/nixpkgs-snapshot.nix` | `C++` → `CPlusPlus`; **dep-name alias table** for nixpkgs renames: `zlib-ng→zlib`, `util-linux-minimal→util-linux`, `gnum4→m4`, `gmake→make`, `glibc-iconv-*→glibc` — deps now link to universe instances |
| `spike/vm.nix` | **Rewritten**: repo copied with `builtins.path` filter (excludes `.git`/`.nix-store`/`.nix-state` — old code copied 831 MB into the image); nixpkgs passed as `pkgs.path` for offline in-VM eval; `--impure` evals (absolute `readFile /run/sumo-facts.kif` is forbidden in pure eval); guest resources via `virtualisation.vmVariant` (the option does not exist at top level); classic VM direct-boots kernel, so `boot.loader.grub.enable = false` + tmpfs `/` satisfy eval assertions |
| `spike/demo.sh` | Resolves nixpkgs via `(builtins.getFlake "nixpkgs").outPath`; builds attribute **`vm`** (`system.build.vm` does not exist under `<nixpkgs/nixos>`); `SPIKE_TIMEOUT` (default 180s); fails loudly when the banner/completion marker is missing |
| `.gitignore` | **New**: `.nix-store/`, `.nix-state/`, build outputs — this host builds nix with a diverted local store |

### Verification (this host, diverted nix store at `./.nix-store`)
- **Facts**: `nix eval --impure --expr 'let pkgs = import (builtins.getFlake "nixpkgs") {}; in import ./spike/nixpkgs-snapshot.nix { inherit pkgs; }'` → valid KIF, 386 lines.
- **Reasoning**: `import ./spike/run-spike.nix { snapshot = builtins.readFile facts.kif; }` → report with:
  - 📦 6 direct compositions (nginx×3, automake, libarchive, git)
  - 🌐 10 enabled capabilities (nginx: TLS/Crypto/X509; git: SSHClient/SFTP/HTTPClient; postgresql: SQL via `postgresql→util-linux→sqlite` 2-hop closure; libgcrypt, libarchive, automake)
  - 💡 2 synergies (`git: HTTPClient + SFTP + SSHClient`, `nginx: Crypto + TLS + X509`)
- **Transitive closure verified** via `e.explain [ "enablesCapability" "postgresql" "SQL" ]` — full proof tree with asserted facts and rule names.
- **VM config evaluates**: `nix eval -f "$NIXPKGS_PATH/nixos" vm.drvPath -I nixos-config=./spike/vm.nix` → `/nix/store/w2lzna4aifzfc1c5qs51waabv5fyg3zf-nixos-vm.drv`. Assertions pass.

### Blocked here — needs a normal host or CI
- **VM build + boot**: this sandbox has no writable `/nix/store` (`creating directory "/nix/store": Permission denied`), and builds in a diverted store are impossible (`this system does not support the kernel namespaces that are required for sandboxing`); user namespaces are blocked (`unshare: Operation not permitted`); no qemu on host. The image build runs `qemu-img`/disk creation locally, so it cannot be substituted from the cache.
- **To finish**: on any NixOS/Linux host with nix ≥ 2.18 and KVM, run `cd spike && ./demo.sh` (or `SPIKE_TIMEOUT=180 ./spike/demo.sh`). Expected: VM builds, boots headless, `sumo-spike` oneshot service logs the report to console; awk extracts it; exit 0.
- **aarch64-linux**: untested; classic VM is x86_64-BIOS-oriented — for ARM use `virtualisation.useEFIBoot` or run on x86_64.

### Key Implementation Decisions (updated)
1. **Repo-relative paths everywhere** — `run-spike.nix` reads `../kif.nix`, `../sumo.nix`, `../sumo.full/Merge.kif`, `../nix-domain.kif`, `./vuln-rules.kif`, `./capabilities.kif`; works identically from the repo and from the VM image copy.
2. **Rules/seeds as files, not embedded strings** — single source of truth (`vuln-rules.kif`, `capabilities.kif`), parsed once at eval; duplication removed.
3. **`--impure` is required at runtime** — facts live at an absolute path (`/run/sumo-facts.kif`) outside the store; pure eval forbids `builtins.readFile` there.
4. **Synergy dedup at format time** — the engine derives all 6 orderings of a triple; output collapses by (pkg, sorted caps).
5. **Local facts injection** — `snapshot ?` parameter lets the exact VM code path be exercised locally without booting (used for all verification above).

### Next Steps After Spike (Per Plan)
1. **Lazy incremental bootstrap** — Cache package facts, invalidate on metadata change.
2. **Policy pack registry** — Flake-based, signed KIF rule sets (security, license, **capability**).
3. **Live advisory ingest** — OSV/NVD fetchers → continuous fact streams via `sumo-nix` fetchers.
4. **Reasoner daemon** — Rust/Ascent + TMS, replaces `mlnix eval` for latency.
5. **Self-healing overlay** — Spike output → Nix overlay → `nixos-rebuild switch --rollback`.
6. **Neuro-symbolic gateway** — LLM → typed Goal → Datalog plan → executor.

---

*End of spike plan. The spike is the seed; the architecture is the tree.*