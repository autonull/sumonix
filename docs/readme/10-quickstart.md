## Quick start

### Try it in 60 seconds

```bash
git clone https://github.com/autonull/sumonix
cd sumonix

./run-tests.sh     # 27 tests, eval-only
./demo/run         # five scenes, ~30 seconds, offline facts committed
```

There is no install step for the repository checkout: `./bin/sumo` sources
`tools/env.sh`, points Nix at the repository-local store, and runs
`nix eval`. `nix develop` puts the packaged `sumo` CLI on `PATH`.

**Requirements:** Nix; enable flakes for `nix develop` and `nix run`.
Evaluation needs no root and no daemon. The container demo
(`./container/run.sh`) additionally needs unprivileged user namespaces; see
[Metavisor live loop](#metavisor-live-loop).

### Run the full proof loop

```bash
# 1. Derive, export a certificate, and re-check it independently.
./nix-eval.sh --raw --expr 'import ./tests/proof-artifact.nix' > proof.kif
./nix-eval.sh --expr '(import ./proof-check.nix { file = ./proof.kif; })'
# → "proof: 9 steps, independently re-checked ✓"

# 2. Ask the machine what it knows.
./bin/sumo status
./bin/sumo caps
./bin/sumo closure openssl
./bin/sumo whatif

# 3. Gate a real NixOS configuration (exits 1 with the proof on violation).
./bin/sumo gate --configuration /etc/nixos/configuration.nix
```

> **Why `sumo status` reports a violation on a fresh checkout:** the default
> facts are the labelled nginx/critical-CVE fixture, so the policy gate has
> something to prove. `sumo refresh` writes live host facts to
> `.runtime/facts-live.kif`; read them with
> `SUMO_FACTS=.runtime/facts-live.kif sumo status`.

### Run one test, or the whole suite

```bash
./nix-eval.sh --expr 'import ./tests/default.nix'       # ontology oracle
./nix-eval.sh --expr 'import ./tests/proof-check.nix'   # committed proof + tamper tests
./nix-eval.sh --expr 'import ./tests/unit/relax.nix'    # one unit suite
./run-tests.sh                                          # all 27
```

### Demo scenes

```bash
./demo/run                     # all five scenes, in order
./demo/run 02-capabilities.sh  # just one
./demo/record                  # re-record every scene (needs asciinema)
```

### Use it from a flake

In your `flake.nix`:

```nix
{
  inputs.sumonix.url = "github:autonull/sumonix";

  # NixOS module: installs the CLI and the live-facts service.
  # imports = [ inputs.sumonix.nixosModules.default ];

  # Resident metavisor: timer, observer, and append-only event log.
  # imports = [ inputs.sumonix.nixosModules.sumonix-metavisor ];
}
```

The packaged CLI is available with `nix run github:autonull/sumonix`, or as
the derivation `nix build .#sumo-cli`.

### What to read next

- [CLI cheatsheet](#cli-cheatsheet) — every command, flag, and environment variable.
- [Status](#status) — what ships today, the benchmark, and the honest limits.
- [The demo](#the-demo) — the five scenes and what each one proves.
- [Metavisor live loop](#metavisor-live-loop) — the real NixOS-in-Podman run.
