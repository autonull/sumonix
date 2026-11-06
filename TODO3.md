# TODO.3 — A demo of SUMO reasoning, recorded as a movie

**Status:** the deliverable is a **host-native session**, recorded with `asciinema`.
The NixOS-in-Podman work is **parked** in `container/` (it builds and boots; it
does not yet pass its own gate). See `container/README.md`.

**Definition of done (current):**

```bash
./tools/tour.sh                 # → docs/demo/tour.cast   (the movie)
./tools/shot.sh                 # → docs/demo/dashboard.png
asciinema play docs/demo/tour.cast
```

The movie shows, in order: this host's own facts, the labelled fixture scenario
with its proof, the capability atlas, a package closure, a ground query with its
why-subtree, the what-if menu, the gate's exit status, an independent proof
check, and the TUI rendered from the same digest.

**Non-negotiables (current):**

- The demo runs on the host with `nix` only: no container, no VM, no QEMU, no
  `/nix` writes beyond what `nix eval` already does.
- Facts are labelled. `demo/host-facts.sh` emits `source: live` from systemd,
  `/proc`, `ss` and a Nix store if one exists. `demo/facts/host.kif` is
  `source: fixture`, and `sumo status` prints both counts.
- No canned transcript. The cast is recorded from the real CLI; the PNG is the
  TUI's own dump.
- `run-tests.sh`, `./demo/run` byte-identical, and `check-readme.sh` stay green.

---

## Workstream H — the host demo

| # | Task | Files | Acceptance | Status |
|---|---|---|---|---|
| H1 | Live host facts | `demo/host-facts.sh` | `source: live` header; services from systemd, kernel from `/proc`, listeners from `ss`, packages from `/nix/store` when present | **done** |
| H2 | Source accounting | `bin/_sumo.nix` | `status` prints `live N` / `fixture M`; section headers are counted, comments are not | **done** |
| H3 | Fixture scenario | `demo/facts/host.kif` | `source: fixture` header; nginx/CVE scenario; verdict + proof unchanged | **done** |
| H4 | Session script | `tools/tour-session.sh` | live pass, fixture pass, caps, closure, query, whatif, `guard` exit status, proof check, TUI dump | **done** |
| H5 | Recorder | `tools/tour.sh` | `docs/demo/tour.cast`, 110×50, exit 0 | **done** |
| H6 | Screenshot | `tools/shot.sh` | `docs/demo/dashboard.png` from `demo/tui/sumo-tui --dump` | **done** |
| H7 | CLI surface | `bin/sumo` | `guard` exits 1 on a violation; `refresh` explains itself off-NixOS; TUI resolved from PATH | **done** |
| H8 | Docs | `docs/readme/10-demo.md`, `README.md` | host demo + movie; live/fixture split; container mentioned only as deferred | **done** |

## Deferred — workstream N (container)

Parked in `container/`. Nothing there is required by the current definition of
done; nothing there should be deleted without reading `container/README.md`
first, which records what builds, what fails, and the five traps
(`tarball` needs the lxc module, `src` collides with `pkgs.src`, `nix build`
rejects `--impure`, never `git add .runtime/`, store paths are not filesystem
paths).

To resume: `container/setup.sh`, then `container/run.sh run`, then fix the
remaining failed unit from `systemctl --failed` and verify `sumo status --json`
inside the guest.

## Verification (current)

```bash
./run-tests.sh                  # 21 tests
./demo/run > /tmp/after.txt     # byte-stable
diff /tmp/before.txt /tmp/after.txt
./tools/check-readme.sh
./tools/tour.sh                 # the movie
./tools/shot.sh                 # the screenshot
asciinema play docs/demo/tour.cast
```

---

## Rev 5 — the real target

The previous revisions drifted in opposite directions: a full NixOS VM (heavy), then a host-native fixture session (too light, not NixOS). Rev 5 takes the middle path that actually matches the goal:

| Decision | Why |
|---|---|
| **Run a real NixOS system in a Podman container.** | Podman shares the host kernel. No kernel, initrd, firmware, or disk image is downloaded or booted. The container still has NixOS systemd, a Nix store, NixOS services, and NixOS configuration. |
| **Make the container the acceptance gate.** | `systemctl is-system-running` must report `running`; `/etc/os-release` must say `ID=nixos`; `nix-store -q --requisites /run/current-system` must return a real closure. A host-native run cannot pass these checks. |
| **Integrate SUMO through a NixOS module.** | The reusable surface is `nixosModules.default`: `services.sumonix.enable = true;` installs the CLI, TUI, facts service, MOTD, and optional guard. This is how a real NixOS user adopts it. The container imports the module; it is not an ad-hoc script. |
| **Keep only real NixOS services that the demo uses.** | `nginx` is a real service with a real closure; it is the policy subject. Do not install Redis, PostgreSQL, Python, OpenSSH, or `asciinema` in the image unless a scene specifically needs them. |
| **Generate live facts inside NixOS.** | The facts service reads `systemctl`, `/run/current-system`, `nix-store`, `/proc`, and `ss`. The CVE advisory and the pinned capability atlas stay explicit fixtures. |
| **Use Podman, not QEMU.** | Podman is the selected runtime. `qemu-system-x86_64` is not installed and is not required. |
| **Host-native is `--dev` only.** | It is useful for fast iteration on the CLI/TUI, but it must not be presented as the NixOS demo. |
| **Local build first.** | Build the NixOS container on the host with the restored Nix. A remote builder is not the plan and is not an excuse. If the local build fails, fix the prerequisite or report the exact blocker. |
| **Keep project state inside the repository.** | Build store in `.nix-root/`, image tarball in `.artifacts/`, Podman storage in `.runtime/podman/`, logs in `.logs/`. |

### Why the container is lighter than the VM

The VM plan needed:

- a Linux kernel, initrd, firmware, and a bootloader path;
- a full NixOS system closure duplicated into a disk image;
- QEMU or `make-disk-image`/`nixos-generators` image tooling;
- a download of the finished image.

The container needs:

- a NixOS userspace tarball (systemd, glibc, bash, coreutils, nginx, nix, SUMO);
- the host kernel (shared);
- Podman;
- no QEMU, no initrd, no firmware, no disk image.

The container image is still a real NixOS closure. Its size is measured, not promised. The point is that it contains the system the demo reasons about, not a canned transcript.

### What "real NixOS + SUMO" means here

The container must prove all of the following:

```bash
podman exec sumonix-demo cat /etc/os-release          # ID=nixos
podman exec sumonix-demo systemctl is-system-running # running
podman exec sumonix-demo systemctl status nginx      # active (running)
podman exec sumonix-demo nix-store -q --requisites /run/current-system | wc -l
podman exec sumonix-demo sumo status --json          # services observed live
podman exec sumonix-demo sumo dashboard --dump       # same digest as the CLI
podman exec sumonix-demo sumo query '(vulnerable nginx CVE-2026-9999)'
podman exec -it -u demo sumonix-demo bash -l         # logged-in NixOS session, MOTD
```

The policy advisory is still a fixture; the running nginx service, its dependency closure, the systemd state, and the package set are real NixOS facts. The output says which is which.

---

## 0. Why this milestone exists

`./demo/run` proves the engine works, but it is a slideshow. What is missing is a **real machine that SUMO is part of**: NixOS boots, systemd runs services, the Nix store is real, and `sumo status` answers questions about that machine with a proof. The dashboard is the face of the same live digest.

A host-native session cannot show NixOS integration. A full VM can, but it is heavier than necessary. A NixOS container is the smallest environment that still contains the real system: systemd, NixOS configuration, Nix store, and services.

---

## 1. The demo, as a user experiences it

### Build

```bash
./demo/container.sh build
```

This runs the Nix build for the NixOS container image, imports the tarball into Podman, and records the image digest.

### Run

```bash
./demo/container.sh run
```

This starts:

```bash
podman run --name sumonix-demo \
  --systemd=always \
  --memory=2g --cpus=2 \
  --rm -d \
  localhost/sumonix-demo:latest
```

The container starts NixOS systemd as PID 1 and runs detached. Use `./demo/container.sh exec` to log in. `./demo/container.sh run --attach` is the foreground variant.

### Log in

```bash
./demo/container.sh exec
# → podman exec -it -u demo sumonix-demo bash -l
```

The MOTD appears:

```
╔════════════════════════════════════════════════════════════╗
║  SUMO is reasoning about this NixOS system.                ║
║  Facts: live NixOS state + labelled nixpkgs/CVE fixture.   ║
║  Try:  sumo status   sumo caps   sumo closure openssl      ║
║        sumo query '(vulnerable nginx CVE-2026-9999)'       ║
║        sumo whatif   sumo dashboard                        ║
╚════════════════════════════════════════════════════════════╝
```

### Use

1. `sumo status` — real NixOS services, real packages from the system closure, live kernel, capability count, policy verdict, and proof location.
2. `sumo caps` — capability atlas from the pinned nixpkgs fixture.
3. `sumo closure openssl` — real NixOS dependency tree from the system closure, plus fixture facts for the policy scenario.
4. `sumo query '(vulnerable nginx CVE-2026-9999)'` — the why subtree.
5. `sumo whatif` — one counterfactual from the proof; two warm runs.
6. `sumo dashboard` — the TUI over the same digest: live services, capability atlas, policy proof, chart.
7. **A real NixOS state change** — inside the container:
   ```bash
   systemctl stop nginx
   sumo refresh          # re-read systemd and the Nix store
   sumo status           # nginx is gone; counts and verdict change
   systemctl start nginx
   sumo refresh
   ```
   This is a real service change on a real NixOS system. The demo says exactly what it executed.
8. **A real guard unit** — `systemctl start sumonix-guard` runs `sumo guard`; a violation makes the unit fail, and `journalctl -u sumonix-guard` shows the proof. The default demo can leave `failOnViolation = false` so the container remains `running`; the guard demo flips it explicitly.
9. **Independent proof verification** — run `proof-check.nix` inside the container against the generated proof.

### Fact-source labelling

Every output that mixes sources must say so:

```
Facts:  live 42 (NixOS systemd, nix-store, /proc, ss)
        fixture 5 (nixpkgs capability atlas, CVE advisory)
```

The TUI header shows the same `live + fixture` badge. A fixture fact must never be printed as an observed fact. The policy scene is explicitly a `fixture` scene layered on live NixOS state; it is not a fabricated live CVE.

---

## 2. Non-goals

- No QEMU, no VM, no kernel/initrd/firmware/disk image.
- No host-native session as the deliverable; `--dev` only.
- No canned transcript substituted for the container run.
- No Redis, PostgreSQL, Python, OpenSSH, or `asciinema` in the image unless a scene requires it.
- No browser dashboard, HTTP server, JS, or port forwarding. TUI only.
- No auth, TLS, or multi-tenant work.
- No host package installation by the agent.
- No remote builder as the primary path.
- No new reasoning capability; use the existing engine.

---

## 3. Current state

| Thing | Where | State |
|---|---|---|
| Engine, CLI, TUI | `bin/`, `demo/vm/tui/`, `lib/` | works in-repo; TUI binary 6.1 MB; `sumo dashboard` still looks only for `/run/sumo/bin/sumo-tui` |
| NixOS VM config | `demo/vm/vm.nix` | usable as the starting point for the container config; it carries VM-only options to remove |
| Existing facts service | `demo/vm/vm.nix` | copies `host-facts.kif`; **not live**; must be replaced by a NixOS exporter |
| NixOS module | — | **does not exist**; this is the main new integration surface |
| Container config | — | does not exist |
| Podman | host | 6.1.4, cgroup v2, user systemd running; rootless currently blocked by `unprivileged_userns_clone=0` |
| Nix | host | not on `PATH` in this shell; the user is reinstalling it |
| QEMU | host | absent; not required |
| Host tools | host | `go`, `asciinema`, `python3`, `systemd`, `pacman`, `ss` present |
| Recordings | `docs/demo/` | fixture-derived; must be regenerated from the container |

**Prerequisite policy:** the current shell lacks Nix and rootless Podman. These are prerequisites the user is fixing. They are not a reason to fall back to a canned host demo. `--check` reports them precisely and exits non-zero until they are met.

Podman prerequisites for the real run:

```bash
podman info --format '{{.Host.Security.Rootless}}'   # must print true
stat -fc %T /sys/fs/cgroup                           # must print cgroup2fs
podman run --rm --systemd=always localhost/test true # must start systemd
```

The host must have `/etc/subuid` and `/etc/subgid` entries for the user, cgroup v2 delegation, and user namespaces enabled. The user prepares these; the scripts do not run `sudo`.

---

## 4. Workstream N — the NixOS container

### 4.1 Components

```
N1  nixos/sumo.nix — the reusable NixOS module            (integration)
N2  demo/container/container.nix — minimal NixOS system    (image)
N3  live facts exporter + sumo-facts.service               (live data)
N4  demo/container.sh — build/run/exec/tour/teardown       (runner)
N5  TUI, recordings, docs                                  (surface)
N6  verification and measured report                       (close-out)
```

### 4.2 NixOS module — `nixos/sumo.nix`

The module is the point of "NixOS enhanced with SUMO". It is not a demo script.

```nix
{ config, lib, pkgs, ... }:
let
  cfg = config.services.sumonix;
in {
  options.services.sumonix = {
    enable = lib.mkEnableOption "SUMOnix reasoning and policy services";
    repo = lib.mkOption {
      type = lib.types.path;
      default = ../.;
      description = "SUMOnix source tree (bin/, lib/, sumo.full/, facts, rules).";
    };
    # The package derivation filters .git, .nix-store, .nix-root,
    # .artifacts, .runtime, and result* before copying the tree.
    factsFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Optional fixture facts file. Live facts are always generated from this system.";
    };
    advisoryFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Labelled advisory fixture, e.g. the CVE used by the policy scene.";
    };
    guard = {
      enable = lib.mkEnableOption "SUMOnix policy guard unit";
      failOnViolation = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Make the guard unit fail when a policy violation is derived.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      (pkgs.callPackage ../nix/sumo-cli.nix { src = cfg.repo; })
      (pkgs.callPackage ../nix/sumo-tui.nix { src = cfg.repo; })
    ];

    systemd.services.sumo-facts = {
      description = "Generate SUMOnix facts from this NixOS system";
      wantedBy = [ "multi-user.target" ];
      after = [ "nginx.service" ];
      before = [ "sumonix-guard.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.callPackage ../nix/sumo-facts.nix { inherit cfg; }}/bin/sumo-facts";
      };
    };

    systemd.services.sumonix-guard = lib.mkIf cfg.guard.enable {
      description = "SUMOnix policy guard";
      wantedBy = [ "multi-user.target" ];
      after = [ "sumo-facts.service" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.callPackage ../nix/sumo-cli.nix { }}/bin/sumo guard";
        # Exit 1 means "policy violation". Treat it as success only when the
        # demo is not configured to fail the unit.
        SuccessExitStatus = lib.optional (!cfg.guard.failOnViolation) 1;
      };
    };

    environment.etc."sumo-motd".text = ''
      SUMO is reasoning about this NixOS system.
      Try: sumo status   sumo caps   sumo closure openssl
           sumo query '(vulnerable nginx CVE-2026-9999)'
           sumo whatif   sumo dashboard
    '';

    environment.etc."profile.d/sumo-motd.sh".text = ''
      export SUMO_FACTS=/run/sumo/facts.kif
      export SUMO_RULES=/run/sumo/rules.kif
      cat /etc/sumo-motd
    '';
  };
}
```

The exact file layout is an implementation detail; the contract is:

- `services.sumonix.enable` installs `sumo` and `sumo-tui`.
- `sumo-facts.service` runs after the observed services and writes `/run/sumo/facts.kif`.
- `sumo refresh` re-runs the exporter.
- `sumo guard` exits non-zero on a policy violation.
- The module exports `nixosModules.default` from `flake.nix`.
- A real NixOS user can add:
  ```nix
  imports = [ inputs.sumonix.nixosModules.default ];
  services.sumonix.enable = true;
  services.nginx.enable = true;
  ```

### 4.3 Container configuration — `demo/container/container.nix`

Start from `demo/vm/vm.nix`, then remove VM-only pieces:

- remove `boot.loader.grub`, `fileSystems`, `boot.kernelParams`, `virtualisation.vmVariant`;
- add `boot.isContainer = true;`;
- remove `services.getty.autologinUser`, `services.openssh`, `networking.useDHCP`;
- keep `networking.hostName = "sumonix-demo";`;
- add `services.nginx.enable = true;` and a minimal site;
- add `services.sumonix.enable = true;` with the advisory fixture;
- add `services.sumonix.guard.enable = true;` with `failOnViolation = false` for the normal demo;
- install `pkgs.nix`, `pkgs.bashInteractive`, `pkgs.coreutils`, `pkgs.iproute2` (for `ss`), and the TUI;
- create the `demo` user for `podman exec -u demo`;
- set `nix.settings.experimental-features = [ "nix-command" "flakes" ];`;
- set `system.stateVersion`.

Minimal package audit:

| Package/service | In image? | Why |
|---|---|---|
| `nginx` | **Yes** | Real NixOS service and policy subject. |
| `nix` | **Yes** | `sumo` runs `nix eval` inside the guest. |
| `bash`, `coreutils` | **Yes** | Shell and CLI. |
| `iproute2` | **Yes** | `ss` for listeners. |
| `sumo`, `sumo-tui` | **Yes** | The product. |
| `redis`, `postgresql`, `python3` | **No** | No scene needs them. |
| `openssh` | **No** | `podman exec` is the login. |
| `asciinema` | **No** | Record on the host around `podman exec`. |

### 4.4 Live facts exporter — `nix/sumo-facts.nix`

The exporter runs inside NixOS and writes `/run/sumo/facts.kif`:

- `systemctl list-units --type=service --state=running --no-legend` → `HostService`/`NIXService` facts.
- `nix-store -q --requisites /run/current-system` → real `NIXPackage` instances and `dependsOn` edges from the system closure. Filter to the demo's relevant subset (`nginx openssl curl bash coreutils nix` and their direct dependencies); do not emit the whole closure as thousands of facts.
- The capability atlas must use the **live closure** where possible, with the pinned 60-package fixture only as a fallback for deterministic tests. Label which was used.
- `/proc/sys/kernel/osrelease` → `runningKernel`; label that the kernel is the host kernel shared by the container.
- `ss -ltn` → `listensOn`.
- `/run/current-system` → prove the NixOS system closure exists.
- Advisory fixture (`advisoryFile`) → appended under a `;; source: fixture` header.
- Optional `factsFile` fixture → appended under `;; source: fixture`.

Requirements:

- The service is oneshot and `RemainAfterExit = true`.
- It runs after `nginx.service`.
- It creates `/run/sumo/` and `/run/sumo/nix-state` with permissions that let the `demo` user run `sumo` (Nix eval needs a writable state directory).
- `sumo refresh` invokes the same exporter manually.
- The file has a header that says `source: live` or `source: fixture`; the CLI reports the counts.
- No `cp host-facts.kif` as the primary path. The old behavior is removed.

**CLI contract inside the container.**

| Command | Behaviour |
|---|---|
| `sumo status [--json]` | Live NixOS services/packages, fixture counts, verdict, proof, source summary. |
| `sumo caps [--json]` | Pinned nixpkgs capability atlas (fixture). |
| `sumo closure <pkg> [--json]` | Real NixOS dependency tree plus fixture edges where needed. |
| `sumo query <goal> [--json]` | Verdict and why subtree. |
| `sumo whatif` | One counterfactual; two warm runs; exit 1 on a flip. |
| `sumo dashboard` | Runs `sumo-tui` from `PATH`; `--dump` for screenshots. |
| `sumo refresh` | Re-runs the live exporter and rewrites `/run/sumo/facts.kif`. |
| `sumo guard` | Exits 1 when the policy verdict is a violation; 0 when clean. |
| `sumo version` / `--help` | Version and subcommand list. |

The NixOS wrapper sets `NIX_REMOTE=local`, `NIX_STORE_DIR=/nix/store`, a writable `NIX_STATE_DIR` under `/run/sumo/nix-state`, and `NIX_PATH=nixpkgs=${pkgs.path}`. `tools/env.sh` must respect those pre-set values instead of overwriting them. The container image must include a valid Nix database; if the tarball does not, add a `nix-store --load-db` step at image build. Verify with `nix eval --expr '1+1'` and `nix-store -q --requisites /run/current-system`.

**Live vs fixture by command.**

| Command | Live source | Fixture source |
|---|---|---|
| `status` | NixOS services, real package closure, kernel, listeners | advisory verdict, capability count fallback |
| `caps` | real package closure + capability rules | pinned 60-package atlas fallback |
| `closure` | real `dependsOn` edges from the system closure | none, unless the live edge is unavailable |
| `query` | derived from live facts | advisory fact |
| `whatif` | proof leaves from the live goal | advisory fact |
| `dashboard` | same digest as `status` | same labelled fixture |

The synthetic CVE is a fixture because the demo must be deterministic. The package, its dependency edge, and the running service are real NixOS facts. A real OSV/NVD feed is future work; do not imply that the demo queried one.

### 4.5 Runner — `demo/container.sh`

| Command | Behaviour |
|---|---|
| `./demo/container.sh --check` | Read-only: `nix --version`, `podman info` rootless, cgroup v2, `--systemd=always` smoke test, image builder, disk, no QEMU. No downloads. |
| `./demo/container.sh --estimate` | `nix build --dry-run --json` for the container tarball; report download size, image size estimate, disk. No download. |
| `./demo/container.sh build` | `nix build .#nixosConfigurations.sumonix-container.config.system.build.tarball`; write `.artifacts/container/manifest.json`; `podman import`/`load` into `.runtime/podman` storage; print the image digest. |
| `./demo/container.sh run` | `podman run --name sumonix-demo --systemd=always --memory=2g --cpus=2 --rm -it localhost/sumonix-demo:latest`; wait for `systemctl is-system-running`; print the exec command. |
| `./demo/container.sh exec` | `podman exec -it -u demo sumonix-demo bash -l`. |
| `./demo/container.sh --tour` | Run the scripted sequence inside the container; optionally record with host `asciinema`. |
| `./demo/container.sh --teardown` | `podman stop sumonix-demo`; `podman rm -f sumonix-demo`; remove `.runtime/`; no broad `pkill`. |

Self-containment:

- Build store: `--store local?root=$ROOT/.nix-root` (logical `/nix/store`, physical under repo). If the restored Nix is a system installation, the image still contains its own `/nix/store`; the host store is only the build input.
- Podman storage: set `CONTAINERS_STORAGE_CONF` or pass `--root "$ROOT/.runtime/podman/storage" --runroot "$ROOT/.runtime/podman/runroot"` so image layers stay inside `.runtime/`.
- Image tarball: `.artifacts/container/`.
- Logs: `.logs/`.
- Do not write to host `/nix` beyond the Nix prerequisite itself; the demo does not populate it.

### 4.6 TUI

- Move `demo/vm/tui/` → `demo/tui/`.
- Build with `pkgs.buildGoModule`; fix the placeholder hash in `demo/vm/sumo-tui.nix` or replace it with `nix/sumo-tui.nix`.
- Install the binary in the NixOS image; `sumo dashboard` resolves `sumo-tui` via `command -v`, then `/run/sumo/bin/sumo-tui`, then `demo/tui/sumo-tui`.
- Keep `--dump` for the screenshot and the digest test.
- Header: `NixOS sumonix-demo`, live/fixture source badge, service/package counts, verdict.
- Panes: live services, fixture capability atlas, proof, activity, sparkline.
- Refresh every 5 s; re-run the memoized digest; recount only when the facts file changes.

### 4.7 Recordings and docs

- `docs/demo/tour.cast`: host `asciinema` recording of `podman exec -it -u demo sumonix-demo bash -l` running the tour.
- `docs/demo/dashboard.png`: `podman exec sumonix-demo sumo-tui --dump` piped to `tools/shot.sh`.
- The README says these come from the NixOS container, not a VM and not a host fixture.
- The fixture tour remains available for test determinism; the live tour is the demo.

### 4.8 Tasks

| # | Task | Files | Acceptance | Status |
|---|---|---|---|---|
| N1 | NixOS module | `nixos/sumo.nix`, `nix/sumo-cli.nix`, `nix/sumo-tui.nix`, `nix/sumo-facts.nix`, `flake.nix` | `services.sumonix.enable` installs CLI/TUI/facts; `sumo guard` exits non-zero on violation; `nixosModules.default` exported | **done** |
| N2 | container config | `demo/container/container.nix`, `flake.nix` | tarball builds; `/etc/os-release` says `ID=nixos`; systemd PID 1; nginx active; `nix eval --expr '1+1'` works; `nix-store -q --requisites /run/current-system` works; minimal packages only | **config done, build pending** |
| N3 | live facts | `nix/sumo-facts.nix`, `bin/_sumo.nix` | live NixOS services/packages/kernel/listeners; `sumo caps` uses the live closure with a labelled fixture fallback; fixture headers; `sumo refresh`; source counts in `--json` | **exporter done, container verify pending** |
| N4 | runner | `demo/container.sh`, `tools/env.sh` | `--check`/`--estimate`/`build`/`run`/`exec`/`--tour`/`--teardown`; Podman storage in `.runtime`; no QEMU | **done** |
| N5 | TUI + recordings | `demo/tui/`, `tools/shot.sh`, `tools/tour.sh`, `docs/demo/` | `sumo dashboard` runs in container; `--dump` matches CLI digest; cast/PNG regenerated from container | **TUI moved, recordings pending** |
| N6 | verification/report | this file, `docs/` | §8 and §14 complete with measured values | **todo** |
| N7 | fixture facts | `demo/fixtures/policy.kif`, `demo/fixtures/rules.kif` | nginx/CVE advisory + pinned nixpkgs capability atlas; labelled `source: fixture` | **done** |
| N8 | CLI integration | `bin/sumo`, `bin/_sumo.nix`, `tools/env.sh` | `sumo dashboard` finds TUI in container; `sumo refresh` re-runs exporter; `sumo guard` exists; `tools/env.sh` respects pre-set NIX_* vars | **done** |
| N9 | flake + repo wiring | `flake.nix`, `nix/sumo-packages.nix` | `nixosConfigurations.sumonix-container` + `nixosModules.default` exported; repo copied with `.git/.nix-store/.nix-root/.artifacts/.runtime/result*` filtered | **done** |
| N10 | docs + cleanup | `docs/readme/10-demo.md`, `demo/transcripts/*.txt`, `demo/README.md` | no VM/QEMU claims; container-based; live/fixture labels; fixture tour byte-stable; live tour explicit | **todo** |

### 4.9 Complete file manifest (turn-key target)

These files must exist for `./demo/container.sh build && ./demo/container.sh run && ./demo/container.sh exec` to work end-to-end.

**New NixOS module + packages (`nixos/`, `nix/`):**

| File | Purpose |
|---|---|
| `nixos/sumo.nix` | NixOS module: `services.sumonix.enable`, `repo`, `factsFile`, `advisoryFile`, `guard.enable`, `guard.failOnViolation` |
| `nix/sumo-cli.nix` | Derivation for `sumo` shell wrapper + `_sumo.nix` dispatcher; filters repo; sets NIX_* in wrapper |
| `nix/sumo-tui.nix` | Derivation for `sumo-tui` Go binary via `buildGoModule`; real `vendorHash`/`modSha256` |
| `nix/sumo-facts.nix` | Derivation for `sumo-facts` exporter script; reads systemd/nix-store/proc/ss; writes `/run/sumo/facts.kif` |
| `nix/sumo-packages.nix` | Aggregates the four packages; used by module and flake |
| `flake.nix` | Adds `nixosConfigurations.sumonix-container`; exports `nixosModules.default`; repoRoot = self.outPath |

**Container configuration (`demo/container/`):**

| File | Purpose |
|---|---|
| `demo/container/container.nix` | Minimal NixOS: `boot.isContainer=true`, nginx, `services.sumonix.enable`, `sumoPackages = pkgs.callPackage ../nix/sumo-packages.nix {}`; demo user; `system.stateVersion` |

**Runner + scripts (`demo/`, `tools/`, `bin/`):**

| File | Purpose |
|---|---|
| `demo/container.sh` | `--check`, `--estimate`, `build`, `run`, `exec`, `--tour`, `--teardown`; Podman storage in `.runtime/podman/` |
| `tools/env.sh` | Respects pre-set `NIX_STORE_DIR`, `NIX_STATE_DIR`, `NIX_PATH`, `NIX_REMOTE` (uses `${VAR:-default}`) |
| `bin/sumo` | `sumo dashboard` resolves TUI via `command -v sumo-tui` → `/run/sumo/bin/sumo-tui` → `demo/tui/sumo-tui` |
| `bin/_sumo.nix` | Adds `sumo refresh` (re-runs exporter), `sumo guard` (policy check); source counts in `--json` |
| `demo/fixtures/policy.kif` | Advisory: `(vulnerable openssl CVE-2026-9999)` + `(severity CVE-2026-9999 critical)`; header `source: fixture` |
| `demo/fixtures/rules.kif` | Copy of `rules.kif` for the container; header `source: fixture` |

**TUI + recordings:**

| File | Purpose |
|---|---|
| `demo/tui/` | Moved from `demo/vm/tui/`; `go.mod`/`go.sum`/`main.go`; builds to `sumo-tui` |
| `tools/shot.sh` | Updated: `podman exec sumonix-demo sumo-tui --dump` → PNG |
| `tools/tour.sh` | Updated: `asciinema rec podman exec -it -u demo sumonix-demo bash -lc 'source /run/sumo/tour.sh'` |
| `demo/tour.sh` | Container tour script (like `demo/vm/session.sh` but for container) |

**Container tour script — `demo/tour.sh`:**

```bash
#!/usr/bin/env bash
# /run/sumo/tour.sh — scripted tour inside the NixOS container.
# Installed by sumo-facts.service (or module) at /run/sumo/tour.sh.
# Run: podman exec -it -u demo sumonix-demo bash -lc 'source /run/sumo/tour.sh'

set -euo pipefail
export TZ=UTC LANG=C
PS1='demo@sumonix:~$ '

run() { printf '%s%s\n' "$PS1" "$1"; eval "$1"; printf '\n'; }

printf '%s\n' 'sumonix reasons about this NixOS system.'
printf '%s\n' 'Facts: live NixOS state + labelled nixpkgs/CVE fixture.'
printf '\n'

run 'sumo status'
run 'sumo caps'
run 'sumo closure openssl'
run "sumo query '(vulnerable nginx CVE-2026-9999)'"
run 'sumo whatif'
run 'echo "Starting dashboard (press q to quit)..."'
run 'timeout 10 sumo dashboard || true'

printf '%s\n' 'Tour complete. Interactive session ready.'
```

Installed by `nix/sumo-facts.nix` to `/run/sumo/tour.sh` in the container.

**Cleanup targets (delete after container works):**

```
demo/vm.sh demo/vm/build.sh demo/vm/vm.nix demo/vm/session.sh demo/vm/vm-wrapper.nix
demo/vm/sumo-tui.nix demo/vm/tui/  (moved to demo/tui/)
flake.nix VM output (nixosConfigurations.demo)
```

**Verification additions (§7):**

```bash
# NixOS module test
nix build .#nixosConfigurations.sumonix-container.config.system.build.tarball
podman import result/tarball/nixos-system-*.tar.xz localhost/sumonix-demo-test
podman run --name test --systemd=always --rm -d localhost/sumonix-demo-test
podman exec test cat /etc/os-release
podman exec test systemctl is-system-running
podman exec test systemctl status nginx
podman exec test nix eval --expr '1+1'
podman exec test nix-store -q --requisites /run/current-system
podman exec test sumo status --json
podman exec -it -u demo test bash -lc 'sumo dashboard --dump'
podman stop test
```

---

## 5. Build and run details

### Build the NixOS container

Prefer the NixOS system tarball attribute. If the configuration does not expose it, use `nixos-generators -f container`; do not use the VM/qcow2 format.

```bash
nix build .#nixosConfigurations.sumonix-container.config.system.build.tarball
# result/tarball/nixos-system-*.tar.xz
```

The container config must set `boot.isContainer = true`. The tarball contains `/nix/store`, `/etc`, systemd units, and the SUMO module's services.

### Import into Podman

```bash
podman import \
  --change 'CMD ["/sbin/init"]' \
  result/tarball/nixos-system-*.tar.xz \
  localhost/sumonix-demo:latest
```

If the tarball already carries the correct config, `podman load` is preferred. The runner records which path was used.

### Run

```bash
podman run --name sumonix-demo \
  --systemd=always \
  --memory=2g --cpus=2 \
  --rm -d \
  localhost/sumonix-demo:latest
```

Use `podman exec -it -u demo sumonix-demo bash -l` for the session. Add `-it` in place of `-d` only for the `--attach` variant.

Rootless systemd requirements:

- cgroup v2 (`cgroup2fs`);
- user namespaces enabled;
- `/etc/subuid` and `/etc/subgid` entries;
- cgroup delegation for the user session;
- `podman info` reports `Rootless: true`;
- `--systemd=always` starts `/sbin/init`.

The user prepares these. The runner checks them and reports exact failures; it never runs `sudo`.

### Verify the real system

```bash
podman exec sumonix-demo cat /etc/os-release
podman exec sumonix-demo systemctl is-system-running
podman exec sumonix-demo systemctl status nginx
podman exec sumonix-demo nix-store -q --requisites /run/current-system | wc -l
podman exec sumonix-demo sumo status --json
podman exec sumonix-demo sumo dashboard --dump
podman exec -it -u demo sumonix-demo bash -l
```

### Teardown

```bash
./demo/container.sh --teardown
podman ps -a --filter name=sumonix-demo   # empty
```

---

## 6. Workstreams B, C, D

### B — README from parts

- Keep `docs/readme/*.md`, `demo/transcripts/*.txt`, `tools/build-readme.sh`, `tools/check-readme.sh`.
- Update `10-demo.md` to describe the NixOS container, `services.sumonix.enable`, and the live/fixture split.
- State that the cast and PNG come from the container.
- Remove VM/QEMU/host-native claims.
- `./tools/check-readme.sh` stays in `run-tests.sh`.

### C — Shared helper refactor

Complete. `lib/kif.nix` exists; `proof-check.nix` untouched; suite green; `./demo/run` byte-identical. Do not reopen unless a bug appears.

### D — Repository coherence

- Move `demo/vm/tui/` → `demo/tui/`.
- Add `nixos/` and `nix/` for the module and packages.
- Replace `demo/vm/` with `demo/container/`; keep `spike/vm.nix` only as history.
- Delete `demo/vm.sh`, `demo/vm/build.sh`, `demo/vm/vm.nix`, `demo/vm/session.sh`, `demo/vm/vm-wrapper.nix`, and the VM output from `flake.nix` after the container path works.
- Keep `demo/session --dev` as an optional host harness; it must print a warning that it is not the NixOS demo.
- Update `.gitignore`:
  - keep `.nix-store/`, `.nix-state/`, `.nix-root/`;
  - add `.artifacts/`, `.runtime/`, `.logs/`;
  - remove VM image entries.

---

## 7. Verification requirements

```bash
nix --version
podman --version
podman info --format '{{.Host.Security.Rootless}}'   # true
stat -fc %T /sys/fs/cgroup                            # cgroup2fs

./run-tests.sh
./demo/run > /tmp/after.txt && diff /tmp/before.txt /tmp/after.txt
./tools/check-readme.sh

./demo/container.sh --check
./demo/container.sh --estimate
./demo/container.sh build
./demo/container.sh run
./demo/container.sh exec
./demo/container.sh --tour
./demo/container.sh --teardown
```

Required assertions:

- [ ] `nix --version` works; `podman info` reports rootless; cgroup v2 is active.
- [ ] `./demo/container.sh --check` is read-only and exits non-zero on a missing prerequisite.
- [ ] The NixOS tarball builds; the image imports into Podman storage under `.runtime/`.
- [ ] The container starts systemd as PID 1.
- [ ] `/etc/os-release` reports `ID=nixos`.
- [ ] `systemctl is-system-running` reports `running`.
- [ ] `nginx.service` is active.
- [ ] `/run/current-system` exists and `nix-store -q --requisites` returns a real closure.
- [ ] `sumo status --json` reports live services/packages and fixture sources separately.
- [ ] `sumo caps`, `sumo closure`, `sumo query`, and `sumo whatif` run inside the container.
- [ ] `sumo dashboard --dump` renders the same digest as the CLI.
- [ ] `podman exec -it -u demo ... bash -l` shows the MOTD and a usable session.
- [ ] `systemctl stop nginx; sumo refresh; sumo status` changes the live facts; `systemctl start nginx` restores them.
- [ ] `sumonix-guard` runs and reports the proof; a violation fails the unit when configured.
- [ ] The independent proof checker validates the generated proof.
- [ ] `--teardown` leaves no container and no `.runtime` state.
- [ ] No QEMU is invoked.
- [ ] No host `/nix` population by the demo (a pre-existing Nix installation is allowed).
- [ ] No `sudo` is invoked by the scripts.
- [ ] §14 report contains measured values.

Two-run eval budget inside the container:

```bash
podman exec sumonix-demo sh -c 'time sumo status'
```

---

## 8. Milestones, order, and effort

| Order | Milestone | Effort | Gate | Status |
|---|---|---|---|---|
| 1 | C1–C4 | 1–2 h | suite green; demo diff empty | ✅ |
| 2 | A1 (`sumo` CLI) | 1 h | all subcommands run; dashboard path; `sumo guard`; `sumo refresh` | ✅ |
| 3 | A5/A6 (TUI) | 1–2 h | real terminal; mouse; `q`; charts; `--dump` | ✅ |
| 4 | N1 (NixOS module) | 1–2 h | module installs CLI/TUI/facts/guard | ✅ |
| 5 | N2 (container image config) | 1–2 h | tarball builds; systemd; nixos; nginx | ✅ (config), pending build |
| 6 | N3 (live facts exporter) | 1 h | real NixOS facts; fixture labels; refresh | ✅ (exporter), pending container verify |
| 7 | N4 (runner) | 1 h | build/run/exec/tour/teardown | ✅ |
| 8 | N5 (recordings/docs) | 1 h | cast + PNG from container; README correct | pending container |
| 9 | N6 (verification) | 1 h | §7 and §14 complete | todo |

Remaining work: approximately **4–6 h**, excluding the first NixOS container build. The first build may be the longest step; measure it and report it.

---

## 9. Risks and mitigations

| Risk | L | Impact | Mitigation |
|---|---|---|---|
| Rootless Podman cannot run systemd | high | no real NixOS container | User prepares userns, subuid/subgid, cgroup delegation; `--check` reports exact failure; do not fall back to a canned demo. |
| NixOS container build needs sandbox/namespaces | high | build fails | User restores Nix; enable userns if needed; prefer binary substitutes; report exact missing paths. Do not use QEMU. |
| Container image is large | med | slow download/build | Measure; include only nginx + nix + bash/coreutils + iproute2 + SUMO; no kernel; no redis/postgres/python/openssh/asciinema. |
| systemd in container is degraded | med | demo looks broken | `--check` and boot wait for `is-system-running`; inspect `systemctl --failed`; fix units before recording. |
| Live facts race services | med | wrong counts | `sumo-facts.service` runs after `nginx.service`; `sumo refresh` re-reads on demand. |
| Fixture presented as live | high | dishonest demo | Source headers; live/fixture badge; policy scene explicitly labelled fixture. |
| Host `/nix` population | high | violates self-containment | Build with `--store local?root=.nix-root`; image contains its own store; a pre-existing host Nix is a prerequisite only. |
| TUI binary/derivation breaks | med | no dashboard | Build with `pkgs.buildGoModule`; fix `vendorHash`; `--dump` test. |
| Podman storage outside repo | med | project state leaks | Set `CONTAINERS_STORAGE_CONF` or `--root/--runroot` to `.runtime/podman`. |
| "Host harness" mistaken for demo | med | misses the goal | `--dev` prints a warning; acceptance requires the NixOS container. |
| README drift | high | doc rots | Generated README + `check-readme.sh` in the suite. |

---

## 10. Definition of done

Already true (re-verify):

- [x] `lib/kif.nix` exists; `proof-check.nix` untouched; suite green; `./demo/run` byte-identical.
- [x] `bin/sumo` CLI with all subcommands and JSON.
- [x] `bin/_sumo.nix` dispatcher.
- [x] TUI with `--dump`, charts, 5 s refresh, what-if card.
- [x] README generated; `check-readme.sh` in `run-tests.sh`.
- [x] Tools coherence.

Required for TODO3 completion:

- [ ] `nixosModules.default` exports `services.sumonix`.
- [ ] The container image builds from the NixOS configuration.
- [ ] The container runs NixOS systemd as PID 1; `/etc/os-release` says `ID=nixos`.
- [ ] `nginx` is a real active service; `nix-store -q --requisites /run/current-system` is real.
- [ ] `sumo status/caps/closure/query/whatif/dashboard` all run inside the container.
- [ ] Live facts are generated from NixOS systemd, the Nix store, `/proc`, and `ss`.
- [ ] The advisory and capability atlas are labelled fixtures.
- [ ] A real `systemctl stop nginx` / `sumo refresh` change is demonstrated and restored.
- [ ] `sumonix-guard` runs and reports the proof; failure is optional.
- [ ] The proof checker validates the generated proof.
- [ ] The cast and PNG are generated from the container.
- [ ] `--teardown` leaves no container and no `.runtime` state.
- [ ] No QEMU; no VM; no canned host demo as acceptance.
- [ ] No `sudo` from the scripts; no host `/nix` population by the demo.
- [ ] §14 report contains measured values.

---

## 11. Open questions (with recommendations)

1. **Container image format** — recommend the NixOS `system.build.tarball` (container format); `podman import` with `/sbin/init` if needed. Do not use qcow2.
2. **Rootless systemd** — recommend `--systemd=always`, cgroup v2, delegated user cgroups, subuid/subgid. Verify with `podman info`.
3. **NixOS module scope** — recommend `enable`, `factsFile`, `advisoryFile`, `guard.enable`, `guard.failOnViolation`. Keep it small.
4. **Live package extraction** — recommend `nix-store -q --requisites /run/current-system` filtered by an allowlist; do not emit thousands of facts.
5. **Policy fixture** — recommend the nginx/CVE advisory as an explicit fixture input, not a fake live vulnerability. Label it.
6. **Host harness** — recommend keeping `--dev` only; it must warn and is not acceptance.
7. **Recording** — recommend `asciinema` on the host around `podman exec`; `--dump` for the PNG. No VM.
8. **First build time** — measure; if it exceeds the budget, report the exact closure and ask before raising limits. Do not silently switch to a canned demo.

---

## 12. Sequencing summary

N1 (module) → N2 (container config) → N3 (live facts) → N4 (runner) → N5 (TUI/recordings/docs) → N6 (verification).

Each step ends with the eval suite green. The container is not "done" until `systemctl is-system-running` reports `running`, `/etc/os-release` says `ID=nixos`, `nginx` is active, and `sumo status` observes the live system.

Do not reintroduce QEMU, a VM, or a host-native acceptance path.

---

## 13. Required implementation report

Fill with measured values.

| Measurement | Value | How measured |
|---|---|---|
| Container image compressed size | TBD | `du -h .artifacts/container/*` |
| Container image unpacked size | TBD | `podman image inspect --format '{{.Size}}'` |
| NixOS system closure size | TBD | `nix path-info --closure-size` |
| Build duration | TBD | build log timestamps |
| Container startup to systemd `running` | TBD | `podman run` + `systemctl is-system-running` |
| Idle memory | TBD | `podman stats --no-stream` |
| Peak memory | TBD | `podman stats` during tour |
| CPU usage | TBD | `podman stats` |
| QEMU/VM image size | **0 (not used)** | — |
| Host prerequisites | TBD | `./demo/container.sh --check` |
| Remaining limitations | TBD | rootless Podman, cgroup delegation, host kernel shared |

Also report:

- exact NixOS/nixpkgs revision used for the image;
- image digest after `podman import`/`load`;
- whether `/nix` existed before and after (a pre-existing Nix installation is allowed);
- whether any `sudo`, `sysctl`, `qemu`, or package-install command was executed by the scripts;
- the measured fixture-tour and live-tour durations.

---

## 14. Priority

1. Preserve the engine, CLI, TUI, proof checker, and tests.
2. Add the NixOS module (`services.sumonix`) — the real integration surface.
3. Build the minimal NixOS container image.
4. Generate live facts from NixOS systemd, the Nix store, `/proc`, and `ss`.
5. Run the complete session inside the container: status, caps, closure, query, whatif, dashboard, state change, guard, proof check.
6. Record the container session and regenerate the README.
7. Verify and report measured image size, startup, memory, and CPU.

Do not substitute a host-native canned demo for the NixOS container. The container is the point.
