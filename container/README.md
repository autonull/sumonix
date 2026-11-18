# container/ — a real NixOS system under Podman

**Status: the D1 harness.** `tools/metavisor-tour.sh` builds this image, boots
it, and drives the three metavisor scenes against its real systemd:
`sumo gate` fails on a contradicting module, a stopped postgres unit becomes
proven drift after one timer tick, and the ranked repair patch rebuilds the
whole system through the same gate. The host-native demo (`tools/tour.sh`)
stays the default; this container is the live regression test.

## What works

| Step | Evidence |
|---|---|
| Module, packages, TUI, exporter evaluate and build | `nix build .#sumo-cli`, `.#sumo-tui`, `.#sumo-facts` |
| NixOS tarball builds | `nix build .#nixosConfigurations.sumonix-container.config.system.build.tarball` → `nixos-image-lxc-*.tar.xz`, 231 MB |
| Image imports and boots | `podman import --change 'CMD ["/sbin/init"]' …` then `podman run --systemd=always -d` |
| systemd is PID 1 | `podman exec … /run/current-system/sw/bin/systemctl is-system-running` |

## What is verified

| Scene | Evidence |
|---|---|
| Gate | `sumo gate --configuration nixos/d1-bad.nix` exits 1 with a proof naming `services.postgresql.settings.listen_addresses` and `networking.firewall.allowedTCPPorts`; the image build itself is gated (module assertion) |
| Drift | stop `postgresql`, force one `sumonix-metavisor.service` tick → `sumo status` says `drift`, the journal gets a structured line, `events.jsonl` gains one JSON line |
| Violation | `nc -l 0.0.0.0 9999` → the next tick reports `rogueListener` with a proof |
| Repair | `sumo repair --configuration /etc/nixos/bad.nix` → 3 ranked single-option patches, each re-lifted and re-gated in ~5 s |
| Rebuild | apply patch #1, `nixos-rebuild build` with `NIXOS_CONFIG=/tmp/patched.nix` → the gate passes and the system builds (~1.5 min) |

Known limits: `systemctl is-system-running` reports `degraded`
(`sys-kernel-debug.mount` and `sys-kernel-tracing.mount` fail in a rootless
container; they are kernel filesystems, not the demo); the rebuild is slower than
the image because `nixos-rebuild` labels the system `26.11pre-git`, so the store
relinks a few paths.

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
