# sumonix — a semantic OS for NixOS 🦙

> **Your configuration already declares the truth. sumonix makes it provable.**
>
> Audit-grade reasoning over machines, packages, and organizations — every ground verdict carries a proof that a separate checker can re-run.

<p align="center">
  <img src="docs/demo/tour.gif" alt="sumo walkthrough — live facts from this host, the fixture scenario and its proof, the capability atlas, what-if flips, the policy gate refusing the build, an independent proof check, and the dashboard" width="900">
</p>

**sumonix turns declarations and observations into facts, reasons over them with Horn rules, and returns proofs.** Ask why a build fails, whether a CVE reaches production, or what must change to ship. You get an answer, a proof tree, and a ranked repair — not an opinion.

| | |
|---|---|
| 🚧 **Gate** | Policy violations stop the build with a proof-of-violation that names the exact option paths. |
| ✅ **Proof** | Every derived fact carries rule, round, bindings, and provenance. `proof-check.nix` shares zero code and rejects tampering. |
| 🔭 **Observe** | Declared config and live state become one source-labeled model; drift and rogue listeners are found, not guessed. |
| 🧭 **Repair** | Ranked single-option edits, each re-lifted and re-gated before a human applies it. |
| 🧩 **Extend** | SUMO declaration synthesis, a JSON ⇄ KIF adapter with YAML/TOML schema forms, policy packs, verified transitions, and 28 bootstraps. |
| ⚡ **Small** | Pure Nix: no daemon, no external solver, no LLM in the reasoning path. 27 tests green; warm runs are near-instant. |

**See the trust anchor in one command:**

```console
$ ./nix-eval.sh --expr '(import ./proof-check.nix { file = ./proof.kif; })'
"proof: 9 steps, independently re-checked ✓"
```

**Contents:** [Quick start](#quick-start) · [What it is](#what-it-is) · [Status](#status) · [Architecture](#architecture) · [CLI cheatsheet](#cli-cheatsheet) · [Extension contract](#extension-contract) · [Application bootstraps](#application-bootstraps) · [Coverage](#coverage) · [The demo](#the-demo) · [Metavisor live loop](#metavisor-live-loop) · [Repository layout](#repository-layout) · [Documentation map](#documentation-map)
