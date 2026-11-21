## CLI cheatsheet

`sumo` is a wrapper around one `nix eval`. Every command accepts `--json`
where noted; `--help` prints the same surface from the binary.

### Inspect

| Command | What it answers |
|---------|-----------------|
| `sumo status [--json]` | Services, packages, capabilities, rounds; policy verdict and proof file. |
| `sumo caps [--json]` | Capability atlas of the installed closure: direct compositions, enabled capabilities, synergies. |
| `sumo closure <pkg> [--json]` | Dependency tree for one package, indented. |
| `sumo dashboard` | Build and run the TUI over the digest; `--dump` renders without a TTY. |
| `sumo refresh` | Re-collect live facts (`sumo-facts` on NixOS, `demo/host-facts.sh` elsewhere). |

```bash
sumo status
sumo caps
sumo closure openssl
sumo dashboard
sumo refresh
```

### Ask

| Command | What it answers |
|---------|-----------------|
| `sumo query '<goal>' [--json]` | Ground goal → verdict and why subtree. |
| `sumo ask '<pattern>' [--json]` | Non-ground query → all bindings, e.g. `(vulnerable ?pkg ?cve)`. |
| `sumo why '<goal>' [--json]` | Proof tree for a ground goal. |
| `sumo proof '<goal>' [--json]` | Export a KIF certificate for `sumo check`. |
| `sumo check <file.kif>` | Independent re-check of a certificate. |

```bash
sumo query '(vulnerable nginx CVE-2026-9999)'
sumo ask '(vulnerable ?pkg ?cve)'
sumo why '(policyViolation nginx NoCriticalRunningCVE)'
sumo proof '(policyViolation nginx NoCriticalRunningCVE)' > proof.kif
sumo check proof.kif
```

### Decide

| Command | What it answers |
|---------|-----------------|
| `sumo relax [--json]` | Which single fact or rule flip changes the verdict; size-2 flips and minimal supports when no single does. |
| `sumo whatif [--json]` | One counterfactual from the proof (two warm runs). Exits 1 when a flip exists. |
| `sumo guard [--json]` | Policy check: exits 1 on violation, 0 when clean. |

```bash
sumo relax
sumo whatif
sumo guard
```

### Operate

| Command | What it answers |
|---------|-----------------|
| `sumo lift [--configuration FILE] [--json]` | Lift a NixOS config to declared facts with option-path provenance. |
| `sumo drift [--declared FILE --observed FILE] [--now N] [--json\|--journal]` | Source-labeled drift and rogue-listener report. Exits 1 on drift or violation. |
| `sumo repair [--configuration FILE] [--json]` | Ranked single-option repairs, each re-lifted and re-gated. |
| `sumo gate [--configuration FILE] [--json]` | Config gate: exits 1 with the proof when the config violates `system.kif`. |

```bash
sumo lift --configuration /etc/nixos/configuration.nix > declared.kif
tools/observe.sh > observed.kif
sumo drift --declared declared.kif --observed observed.kif
sumo repair --configuration /etc/nixos/configuration.nix
sumo gate --configuration /etc/nixos/configuration.nix
```

### Extend

| Command | What it answers | State |
|---------|-----------------|-------|
| `sumo pack add <flake-url>` | Load a policy pack and validate its schema, rules, and ontology. | ✅ module |
| `sumo pack list` / `sumo pack remove` | List or remove installed packs. | 🧪 storage not implemented |
| `sumo audit [--json]` | Five-stage audit from `flake.lock`: runtime closure, config closure, vulnerabilities, licenses, policy. | ✅ |
| `sumo plan <goal> [--json]` | Create a verified transition bundle for a goal. | 🚧 stub |
| `sumo apply <bundleId> [--json]` | Verify and apply a bundle (L2: human-approved). | 🧪 simulated |
| `sumo init [dir] [--force]` | Scaffold a project: facts, rules, policies, pre-commit, CI. | ✅ |
| `sumo lint [file...]` | KIF diagnostics: `file:line:col`, typo suggestions. | ✅ |

```bash
sumo pack add github:myorg/policy-pack
sumo audit --json
sumo plan '(policyViolation nginx NoCriticalRunningCVE)' --json   # stub
sumo apply <bundleId>                                              # simulated
sumo init my-project
sumo lint facts.kif policies.kif
```

### Utilities

| Command | What it does |
|---------|--------------|
| `sumo version` | Print the CLI version. |
| `sumo --help` | Print the command surface. |

### Environment

| Variable | Purpose | Default |
|----------|---------|---------|
| `SUMO_FACTS` | Facts KIF | `/run/sumo/facts.kif`, then `demo/facts/host.kif` |
| `SUMO_RULES` | Rules KIF | `/run/sumo/rules.kif`, then `rules.kif` |
| `SUMO_POLICIES` | Policies KIF | `./policies.kif`, then none |
| `SUMO_DECLARED` | Lifted declared facts | `/etc/sumo/declared.kif`, then `.runtime/declared.kif` |
| `SUMO_OBSERVED` | Observer output | `/run/sumo/observed.kif`, then `.runtime/observed.kif` |
| `SUMO_CACHE_DIR` | Evaluation cache root | `.runtime/cache` |
| `SUMO_NO_CACHE` | Bypass the cache (`1`) | unset |

### Exit codes

| Code | Meaning |
|------|---------|
| `0` | Success; the query derived, the gate passed, the proof checked. |
| `1` | The answer is a violation, a drift, a failed gate, or a failed proof check. |
| `2` | Usage error: missing argument or unknown command. |

### NixOS modules

| Option | Purpose |
|--------|---------|
| `services.sumonix.enable` | Install the CLI, TUI, and live-facts service. |
| `services.sumonix.repo` | Source tree used by the module. |
| `services.sumonix.factsFile` | Optional fixture facts. Live facts are always generated. |
| `services.sumonix.advisoryFile` | Optional labelled advisory fixture. |
| `services.sumonix.guard.enable` | Run the policy guard unit. |
| `services.sumonix.guard.failOnViolation` | Make the guard unit fail on a violation. |
| `services.sumonix-metavisor.enable` | Resident metavisor: timer, observer, event log. |
| `services.sumonix-metavisor.repo` | Source tree used by the lift, observer, and CLI. |
| `services.sumonix-metavisor.package` | The `sumo` CLI package that carries `reasoner/` and `tools/`. |
| `services.sumonix-metavisor.gate` | Run the config gate at build time (default `true`). |
| `services.sumonix-metavisor.interval` | Seconds between refresh ticks (default `60`). |

### Troubleshooting

| Symptom | Cause and fix |
|---------|---------------|
| `sumo status` reports a violation on a fresh checkout | The default facts are the labelled nginx/CVE fixture. Use `SUMO_FACTS=.runtime/facts-live.kif sumo status` after `sumo refresh`. |
| Evaluation uses `/nix/store`, or fails with an unwritable store | Source `tools/env.sh`, or call `./bin/sumo` / `./nix-eval.sh`; they set the repository-local store. |
| A build fails with "cannot build in a diverted store" | Enable unprivileged user namespaces (`sudo sysctl -w kernel.unprivileged_userns_clone=1`), or build in CI. |
| `sumo refresh` writes a file but `status` is unchanged | Pass the file explicitly: `SUMO_FACTS=.runtime/facts-live.kif sumo status`. |
| A cold command takes a few seconds | The cache is cold. Re-run; `SUMO_NO_CACHE=1` bypasses the cache on purpose. |
| `sumo plan` errors | It is a stub. Use `sumo proof` + `sumo check` for the working proof loop. |
