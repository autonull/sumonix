# container/ — deferred: a real NixOS system under Podman

**Status: parked, not part of the current deliverable.** The demo ships as a
host-native session (`tools/tour.sh`). This directory keeps the work that was
done on the container so it can be finished later without rediscovering it.

Everything here builds and boots. It does not yet pass its own acceptance gate:
one systemd unit still fails and `sumo` inside the guest is unverified.

## What works

| Step | Evidence |
|---|---|
| Module, packages, TUI, exporter evaluate and build | `nix build .#sumo-cli`, `.#sumo-tui`, `.#sumo-facts` |
| NixOS tarball builds | `nix build .#nixosConfigurations.sumonix-container.config.system.build.tarball` → `nixos-image-lxc-*.tar.xz`, 231 MB |
| Image imports and boots | `podman import --change 'CMD ["/sbin/init"]' …` then `podman run --systemd=always -d` |
| systemd is PID 1 | `podman exec … /run/current-system/sw/bin/systemctl is-system-running` |

## What is unfinished

1. `systemctl is-system-running` reports `degraded`, not `running`.
   Units are masked in `container.nix` one at a time as they fail
   (`run-wrappers.mount`, `nix-channel-init.service`, `systemd-logind.service`,
   `suid-sgid-wrappers.service`, and D-Bus is disabled). The next failing unit
   must be identified from `systemctl --failed` after each rebuild.
2. `sumo status` inside the guest is **not** verified. `nix eval` as the `demo`
   user in a rootless container is the open question: `NIX_STATE_DIR` is
   `/run/sumo/nix-state` (created 0777 by `systemd.tmpfiles.rules`), and the
   wrapper sets `NIX_REMOTE`, `NIX_STORE_DIR`, `NIX_PATH`.
3. `nginx` is configured but not yet asserted active inside the running image.
4. No recordings or measurements were taken from the container.

## Layout

```
container/
  setup.sh              prereq check → build tarball → podman import → manifest
  run.sh                --check --estimate build run run-attach exec --tour --teardown
  container.nix         minimal NixOS: boot.isContainer, nginx, module, demo user
  tour.sh               scripted session for `podman exec`
  fixtures/             policy.kif (CVE advisory), rules.kif — both `source: fixture`
  nix/
    sumo-packages.nix   aggregates the three packages
    sumo-cli.nix        filtered repo + makeWrapper (NIX_*, PATH)
    sumo-tui.nix        buildGoModule, vendorHash pinned
    sumo-facts.nix      packages sumo-facts.sh
    sumo-facts.sh       live collector: systemctl, /proc, /nix, ss
  nixos/
    sumo.nix            services.sumonix: installs interp, service units, MOTD

  vm/                   superseded VM experiment, kept only for reference
```

## Traps found the hard way

1. **`system.build.tarball` does not exist by default.** It comes from
   `nixpkgs/nixos/modules/virtualization/lxc-container.nix`, which `flake.nix`
   adds to the module list before `nixosModules`/`container.nix`. Without it Nix
   reports "flake does not provide attribute".
2. **Never name a build argument `src`.** `callPackage` fills it from
   `pkgs.src`, which is a deprecated alias, and the error is a confusing
   "package has been renamed to src". The consumers use `repo`.
* **`nix build` does not accept `--impure`.** Use `--expr`/`getFlake`, or a
  clean worktree, when crossing contexts.
* **Don't add the runtime store to git.** `.runtime/` holds a Podman store with
   millions of files; a `git add .` makes every Nix operation crawl it.
5. **A local store path is not a filesystem path.** `.artifacts/container/result`
   points at `/nix/store/…-tarball`, but the bytes live in
   `.nix-root/nix/store/…`. `run.sh`/`setup.sh` resolve through
   `SUMONIX_BUILD_ROOT`.
