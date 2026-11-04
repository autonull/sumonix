# Technical Specification: Semantic NixOS
**Architecture, implementation roadmap, development environment, reasoning engine, and performance requirements · Version 3.0 (The Self-Referential Architecture) · November 2026**

---

## 1. Vision

Build a NixOS system that understands what it is, understands what it should be, can reason about the difference, and can safely make changes to bring reality into alignment with intent.

**Version 3.0: Semantic Closure**
Previous iterations introduced parallel architectures (custom event logs, external schema mappers, secondary scripting languages) that duplicated capabilities Nix and NixOS already possess natively. 

Version 3.0 achieves **maximal elegance and simplicity** through *Semantic Closure*. The system practices absolute "dogfooding": it uses its own semantic mechanisms to configure, observe, and heal itself. It possesses no secondary mechanisms for what it already provides. The semantic layer is not a wrapper around NixOS; it is a *lens* through which NixOS observes and modifies itself.

The central idea combines:
1. **SUMO:** General-purpose knowledge about the world.
2. **NixOS:** A declarative, reproducible representation of an operating system.
3. **Semantic NixOS:** A semantic, self-referential representation of the machine.
4. **Reasoner:** A unified Datalog inference engine for ontology, state, and policy.
5. **Executor:** NixOS itself, acting on dynamically generated configuration overlays.

The ultimate goal is a **semantically addressable, self-healing, self-managing operating system**.

---

## 2. Fundamental Architectural Principles

### 2.1 SUMO is the semantic foundation
Use SUMO as the upper-level ontology. Develop a NixOS domain ontology that specializes it. Do not build a competing OS ontology from scratch.

### 2.2 NixOS is the concrete semantic domain
Treat the NixOS module system as the primary source of semantic information. The semantic layer enriches NixOS's existing representations natively, without external mapping files.

### 2.3 Separation of Knowledge, Reasoning, Policy, and Execution
| Layer        | Responsibility                            | Implementation |
| ------------ | ----------------------------------------- | -------------- |
| Knowledge    | What things are and how they relate       | SUMO + Datalog |
| State        | What is actually true now                 | eBPF + Nix Generations |
| Reasoning    | What follows from available knowledge     | Datalog Engine |
| Policy       | What is permitted or forbidden            | Datalog Constraints |
| Planning     | What changes would achieve an objective   | Nix Overlay Generation |
| Execution    | Applying approved changes                 | `nixos-rebuild` |
| Verification | Establishing whether they worked          | eBPF / D-Bus   |

### 2.4 Semantic Closure (Maximal Dogfooding)
The system must manage itself using the exact same pipeline it uses for user services. If the Reasoner detects that its own inference latency is too high, it generates a Nix overlay to allocate more resources to itself, evaluates it, and applies it.

### 2.5 Neuro-Symbolic Intent Translation
Large Language Models (LLMs) are excellent at parsing fuzzy human intent but dangerous for direct system execution. The architecture enforces a **Neuro-Symbolic boundary**: the LLM translates natural language into a strictly typed, formal Semantic Goal. The deterministic Datalog Reasoner then takes over to plan and execute.

---

## 3. Recommended Technology Stack

*V3.0 collapses the stack. We eliminate external schema mappers, custom event logs, and secondary scripting languages.*

| Category | Technology | Purpose |
| :--- | :--- | :--- |
| **Host OS** | NixOS + Flakes | Reproducible builds, declarative config, state history |
| **Core Language** | Rust (Tokio) | Async daemon, memory safety, eBPF integration |
| **Inference & Policy** | Ascent / Datafrog | Pure Datalog for ontology, rules, and guardrails |
| **Observation** | Aya (eBPF) + D-Bus | Zero-overhead kernel/user-space telemetry |
| **Telemetry Buffer** | SQLite (Ring Buffer) | High-frequency runtime observation caching |
| **State History** | Nix Generations | Time-travel, rollback, declarative provenance |
| **Tracing** | OpenTelemetry | Visualizing inference DAGs and plan traces |
| **Testing** | Proptest + NixOS Test Driver | Property-based logic testing, VM integration |
| **VM Orchestration** | microvm.nix + QEMU | Fast disposable dev environments |

---

## 4. The Reasoner: Unified Datalog

A pure Datalog engine is sufficient for complex OS logic if we abandon the need for imperative scripting. V3.0 uses **Pure Datalog** for *everything* logical.

### 4.1 Ontology, Inference, and Policy in One Language
We do not use Rego, Rhai, or Lua for guardrails. We use Datalog constraints.
```rust
// Datalog rule for inference
rule!(
    capability_provided(Capability) :-
        service_enabled(Service),
        service_provides(Service, Capability)
);

// Datalog rule for policy (Guardrails)
rule!(
    deny_action(Action) :-
        action_type(Action, "OpenPort"),
        action_port(Action, 22),
        action_source(Action, "0.0.0.0/0")
);
```
**Result:** One unified logical language for ontology, inference, and policy. 

### 4.2 Incremental Evaluation & Truth Maintenance
The engine uses **Truth Maintenance Systems (TMS)**. When an eBPF probe reports a process crash, the engine retracts the `ProcessRunning` fact, triggers the TMS to retract dependent facts (`ServiceHealthy`), and fires the `ServiceDown` rule in microseconds.

---

## 5. Semantic Data Model & State Management

*V3.0 collapses the "Time Machine" and "State" models back into native NixOS capabilities.*

### 5.1 Declarative State: Nix Generations
We do not build a custom SQLite Event Log for configuration history. NixOS *already* has a cryptographically hashed, append-only, time-traveling state machine: **The Nix Store and Generations.**
- The Reasoner reads `/nix/var/nix/profiles/system-*` to understand "what changed and when."
- Rollbacks are executed natively via `nixos-rebuild switch --rollback`.
- Provenance is guaranteed by Nix's cryptographic hashing.

### 5.2 Runtime State: SQLite Ring Buffer
SQLite is used *strictly* as a high-frequency ring buffer for eBPF/D-Bus observations. It holds the "current reality" of the running machine, which is continuously diffed against the "declarative intent" of the active Nix Generation.

### 5.3 Three-Valued Truth & Temporal Validity
Facts have `valid_from` and `valid_until`. Observations from eBPF have a Time-To-Live (TTL). If a fact expires and isn't refreshed, it transitions to `Unknown`, triggering a re-evaluation or active probe.

---

## 6. NixOS Semantic Integration (Native)

*V3.0 eliminates external TOML/YAML mappers. The Nix evaluator becomes the semantic registry.*

### 6.1 Native `mkOption` Semantic Submodules
Extend the NixOS module system natively. Add a `semantic` attribute to `mkOption`. 

```nix
# In a standard NixOS module
options.services.nginx.enable = mkOption {
  type = types.bool;
  default = false;
  semantic = {
    class = "SoftwareApplication";
    predicate = "configuredEnabled";
    provides = [ "Capability.HTTP" ];
    requires = [ "Resource.Network" ];
  };
};
```
**Result:** Zero external mapping files. The semantic graph is extracted natively via `nix eval --json .#nixosConfigurations.host.options`. When a developer writes a new NixOS module, the semantic support is born with it.

---

## 7. Runtime Observation: eBPF and D-Bus

*Polling `/proc` or `systemctl` is inefficient and misses transient states. V3.0 utilizes eBPF for zero-overhead observation.*

### 7.1 Aya (eBPF) Integration
Use the Rust `aya` library to load eBPF programs into the kernel.
- **Process Tracker:** Hook `sched_process_exec` and `sched_process_exit` to instantly update `ProcessRunning` facts.
- **Network Tracker:** Hook socket bindings to instantly map `PortBound` facts to `ServiceExposingCapability`.
- **Error Tracker:** Hook kernel OOM kills or segfaults to immediately trigger `ServiceDegraded` inferences.

### 7.2 Event Bus Architecture
eBPF probes and D-Bus listeners push events to an internal Tokio broadcast channel. The Reasoner subscribes to this channel, updates the SQLite ring buffer, and triggers incremental TMS evaluation.

---

## 8. Planning and Execution (Nix Overlays)

*V3.0 collapses the Planner. The Reasoner’s output is not an abstract action graph; it is a **NixOS Module Overlay**.*

### 8.1 Generation of Nix Code
When the Reasoner determines that a goal requires configuration changes, it generates a snippet of Nix code (an overlay).
```nix
# The Reasoner generates this overlay dynamically
{
  services.nginx.enable = true;
  networking.firewall.allowedTCPPorts = [ 443 ];
}
```

### 8.2 Execution via NixOS
The "Executor" simply invokes:
`nixos-rebuild switch --flake .#host --override-input overlay ./generated-overlay.nix`

**Result:** The NixOS module system handles all type-checking, merging, and dependency resolution. The Reasoner remains purely semantic; Nix remains the compiler.

---

## 9. The Ultimate Dogfood: Self-Management

If Semantic NixOS is a system that manages services, **it must manage itself using the exact same pipeline.**

1. **Self-Observation:** The eBPF probes observe the `semantic-nixos-daemon` process. They track its memory usage and inference latency.
2. **Self-Inference:** The Datalog engine derives: `Service.Degraded(SemanticDaemon)` because `inference_latency > threshold`.
3. **Self-Planning:** The Planner generates a NixOS overlay to allocate more resources to itself:
   ```nix
   { services.semantic-nixos.reasoner.threads = 8; }
   ```
4. **Self-Execution:** It triggers a self-rebuild, hot-reloading its own configuration without dropping the semantic state.

---

## 10. Developer Experience & Testing

### 10.1 OpenTelemetry & Visual Proofs
Every reasoning cycle emits OpenTelemetry spans. Developers can open **Jaeger** and visually trace exactly *why* the system decided to restart Nginx, viewing the DAG of facts as a trace timeline.

### 10.2 Property-Based Testing (Proptest)
Use `proptest` to generate random, valid ontological graphs and NixOS configurations. Assert that the Reasoner *never* produces contradictory facts or violates core axioms.

### 10.3 Declarative Test Harness
Write integration tests in a semantic DSL rather than imperative Python.
```yaml
# tests/scenarios/webserver.yaml
initial_state:
  - fact: services.nginx.enable = false
intent: "Provide HTTPS"
expected_actions:
  - overlay_generated: services.nginx.enable = true
expected_final_state:
  - fact: capability.http_server.available = true
```

---

## 11. Security and Threat Model

| Threat | Mitigation |
| :--- | :--- |
| **Reasoner Hallucination** | Strict Neuro-Symbolic boundary. LLMs only output typed Goals; Reasoner only executes verified Datalog derivations. |
| **Privilege Escalation** | The Reasoner daemon runs as an unprivileged user. Execution is delegated to a privileged `snx-executor` helper via Polkit/DBus, which strictly validates the generated Nix overlay signature. |
| **Malicious Ontologies** | SUMO and domain ontologies are cryptographically signed and verified before loading. |
| **Infinite Inference Loops** | Strict depth-limits and cycle-detection in the Datalog evaluation engine. |
| **State Corruption** | Nix Store guarantees declarative state integrity. SQLite ring buffer is ephemeral and can be safely wiped. |

---

## 12. Project Organization

```text
semantic-nixos/
├── flake.nix                 # Nix flake for reproducible dev environments
├── justfile                  # Task runner (dev, test, build, trace)
│
├── core/                     # Domain-agnostic Reasoner
│   ├── reasoner/             # Ascent/Datafrog Datalog engine
│   ├── tms/                  # Truth Maintenance System
│   └── otel/                 # OpenTelemetry instrumentation
│
├── adapters/                 # Domain-specific implementations
│   ├── nixos/                # NixOS Adapter (Option introspection, overlay generation)
│   ├── observation/          # eBPF (Aya) probes, D-Bus listeners
│   └── traits/               # Rust definitions for DomainAdapter
│
├── intent/                   # Neuro-symbolic translator
│   ├── llm_gateway/          # Ollama/OpenAI API integration
│   └── goal_parser/          # Formal Goal schema validation
│
├── ontology/                 # SUMO + NixOS domain mappings (SUO-KIF)
│
├── cli/                      # `snx` binary (clap, REPL, TUI)
│
├── tests/
│   ├── proptest/             # Property-based logic fuzzing
│   ├── scenarios/            # Declarative YAML test scenarios
│   └── vm/                   # NixOS test driver multi-VM setups
│
└── docs/
```

---

## 13. User Interface and API

### 13.1 The `snx` CLI
```bash
# Inspect semantic state
snx state describe

# Time-travel debugging (Reads Nix Generations)
snx state rewind --generation 42
snx state diff HEAD~1

# Visualize reasoning
snx trace open  # Opens Jaeger UI to the latest inference trace

# Inject mock events for testing
snx inject event "service.nginx.processRunning = false"
```

### 13.2 Neuro-Symbolic Chat Interface
A local TUI backed by a local LLM (e.g., Llama 3 via Ollama).
```text
User: "My database is too slow, fix it."
LLM -> Goal: OptimizeResource(target=Database, metric=Latency)
Reasoner -> Plan: Generate Nix overlay to enable PostgreSQL query caching.
Policy -> Check: Ensure memory limits are not exceeded (Datalog).
Executor -> Apply NixOS config.
```

---

## 14. Development Roadmap

### Phase 1: Core & Native Introspection (Weeks 1-4)
- Rust workspace setup, Tokio async runtime.
- Implement Ascent Datalog engine and TMS.
- Build the native Nix `mkOption` semantic submodule and JSON introspector.
- **Milestone:** The Reasoner can accurately ingest a NixOS config and output a semantic graph.

### Phase 2: eBPF Observation & Self-Healing (Weeks 5-8)
- Integrate `aya` for process and network eBPF probes.
- Implement the SQLite ring buffer for runtime state.
- **Milestone:** The system detects a killed process via eBPF, updates the graph in <10ms, and triggers a self-healing Nix overlay.

### Phase 3: Planning, Policy & Execution (Weeks 9-12)
- Implement Nix Overlay generation.
- Integrate Datalog Policy Constraints.
- Build the privileged `snx-executor` helper.
- **Milestone:** The "Turn a minimal VM into an HTTPS web server" demonstrator works end-to-end with automatic rollback on failure.

### Phase 4: Neuro-Symbolic Intent & Property Testing (Weeks 13-16)
- Integrate local LLM for natural language -> Formal Goal translation.
- Implement `proptest` suites for the Reasoner.
- **Milestone:** User types "Make it a secure web server", system plans, validates, executes, and verifies.

---

## 15. Major Architectural Risks & Mitigations

| Risk | Mitigation |
| :--- | :--- |
| **eBPF Overhead / Kernel Panics** | Strictly limit eBPF maps, use ring-buffers, and fallback to D-Bus polling if eBPF fails to load. |
| **LLM Hallucination in Intent** | The LLM *only* outputs a strictly typed Rust Enum (`Goal`). If it outputs invalid JSON or unknown goals, the system rejects it and asks for clarification. |
| **Nix Evaluation Latency** | Cache the semantic graph extraction. Only re-evaluate Nix options when the underlying flake or module files change. |
| **Overlay Conflicts** | The generated overlay is strictly scoped to the target service. NixOS's native module system handles the merging and conflict resolution. |

---

## 16. What Not to Build

To maintain maximal elegance and simplicity, we explicitly forbid:
- **External Schema Mappers (TOML/YAML):** Use native Nix `mkOption` submodules.
- **Custom Event Logs for Config History:** Use Nix Generations.
- **Secondary Scripting Languages (Rhai/Lua/Rego):** Use pure Datalog for all logic and policy.
- **Abstract Action Graphs:** Generate Nix Overlays directly.
- **Distributed Reasoning Clusters:** Keep it single-node. NixOS is inherently node-centric.
- **Graph Databases (Neo4j):** SQLite + In-Memory Datalog is faster and requires zero infrastructure.

---

## 17. Final Technology Decisions

| Area | Selected Technology |
| :--- | :--- |
| **Core Language** | Rust (Tokio) |
| **Inference & Policy** | Ascent (Pure Datalog) |
| **Observation** | Aya (eBPF), systemd D-Bus |
| **Telemetry Buffer** | SQLite (Ring Buffer) |
| **State History** | Nix Generations |
| **Planning/Execution** | Nix Overlays + `nixos-rebuild` |
| **Intent Translation** | Local LLM (Ollama) -> Typed Rust Enums |
| **Tracing** | OpenTelemetry + Jaeger |
| **Testing** | Proptest, NixOS Test Driver |
| **VM Orchestration** | microvm.nix |

---

## 18. Conclusion: The Self-Referential Architecture

This architecture is profoundly elegant because **there is no "shadow system."** 

By collapsing external tools back into the core Nix/Datalog loop, the Rust codebase shrinks dramatically. The Rust daemon does only three things:
1. **Ingest:** Read eBPF/D-Bus telemetry.
2. **Reason:** Run Datalog over the Nix-generated semantic graph + telemetry.
3. **Emit:** Generate Nix code overlays and invoke `nixos-rebuild`.

Semantic NixOS is not a "Smart NixOS Wrapper". It is a **Semantic State Machine** that happens to use NixOS as its first actuator. By enforcing this self-referential loop, we ensure that Semantic NixOS is not a dead-end research project, but a foundational architecture that can eventually manage entire cloud topologies, using the exact same unified reasoning core.
