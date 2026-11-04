# Technical Specification: Semantic NixOS

Architecture, implementation roadmap, development environment, reasoning engine, and performance requirements · Version 1.0 · November 2026

## 1. Vision

Build a NixOS system that understands what it is, understands what it should be, can reason about the difference, and can safely make changes to bring reality into alignment with intent.

This is not simply a NixOS configuration manager with an ontology attached.

The central idea is to combine:

1. SUMO: General-purpose knowledge about the world.
2. NixOS: A declarative, reproducible representation of an operating system.
3. Semantic NixOS: A semantic representation of the machine, its resources, services, capabilities, constraints, and relationships.
4. Reasoner: An inference engine that derives facts, evaluates constraints, and determines what actions are appropriate.
5. Executor: A controlled mechanism for translating decisions into actual system changes.

The important architectural decision is that NixOS is both the initial application domain and the execution environment. SUMO supplies general-purpose semantics, while NixOS supplies the concrete operating-system model.

The result should be a system in which an administrator can express an objective, and the system can:

- Understand the objective.
- Determine what is currently true.
- Infer what needs to change.
- Identify dependencies and constraints.
- Construct a valid desired configuration.
- Test the proposed configuration.
- Execute the changes.
- Verify that the intended result was achieved.
- Explain every important conclusion and action.

The ultimate goal is a semantically addressable operating system.

## 2. Fundamental architectural principles

Before choosing tools, establish several principles that should govern the entire project.

### 2.1 SUMO is the semantic foundation

Do not build a competing operating-system ontology from scratch.

Use SUMO as the upper-level ontology, then develop a NixOS domain ontology that specializes it.

For example:

```
SUMO
 ├── Object
 │    ├── Device
 │    │    ├── Computer
 │    │    │    └── ComputerSystem
 │    │    │         └── NixOSHost
 │    │    └── StorageDevice
 │    │
 │    └── Software
 │         ├── OperatingSystem
 │         ├── SoftwareApplication
 │         └── SystemService
 │
 ├── Process
 │    └── RunningProcess
 │
 └── Attribute
      ├── ResourceCapacity
      └── SystemState
```

This is illustrative, not a claim that these exact subclass relationships already exist in SUMO. The domain ontology must use the actual SUMO definitions and relations.

### 2.2 NixOS is the concrete semantic domain

NixOS already has a declarative model of operating-system configuration.

Its module system provides:

- Typed options.
- Option declarations.
- Defaults.
- Conditional definitions.
- Configuration merging.
- Dependency relationships.
- Derived configuration values.

The module system should be treated as a primary source of semantic information, not replaced by a second configuration language.

The semantic layer should enrich NixOS's existing representations.

For example:

```
services.nginx.enable = true;
```

should be understood as more than an assignment.

It implies a set of semantic facts:

```
Nginx is a software application.
Nginx provides a web-server capability.
Nginx is configured to be enabled.
Nginx requires certain runtime resources.
Nginx can expose network services.
Nginx participates in system startup.
```

The reasoner can derive consequences from these facts.

### 2.3 Separate knowledge, reasoning, and execution

These must be independently testable components.

| Layer        | Responsibility                            |
| ------------ | ----------------------------------------- |
| Knowledge    | What things are and how they relate       |
| State        | What is actually true now                 |
| Reasoning    | What follows from available knowledge     |
| Planning     | What changes would achieve an objective   |
| Validation   | Whether those changes satisfy constraints |
| Execution    | Applying approved changes                 |
| Verification | Establishing whether they worked          |

This separation is essential.

The reasoner should never directly modify the operating system. It should produce justified conclusions and proposed actions. A separate executor should enforce permissions and perform changes.

### 2.4 Everything should have provenance

Every important fact should carry enough information to establish:

- Where it came from.
- Whether it was declared, observed, or inferred.
- Which rule derived it.
- Which supporting facts were used.
- When it was observed.
- Whether it is still valid.

For example:

```
{
  "subject": "service.nginx",
  "predicate": "providesCapability",
  "object": "capability.http-server",
  "source": "nixos-module",
  "confidence": 1.0,
  "provenance": {
    "rule": "nginx-provides-http",
    "inputs": [
      "services.nginx.enable=true"
    ]
  }
}
```

This is an illustrative interchange format, not a proposed replacement for KIF.

## 3. Recommended technology stack

The overriding requirement is fast development iterations without sacrificing runtime efficiency.

My recommendation is a predominantly Nix-native system, with Rust for performance-critical reasoning and system integration.

## Recommended stack

[Nixos Linux Logo Png | Nixos Linux Logo Vector  - freepng](https://images.openai.com/static-rsc-4/Fr1YB0pFUVADFZb5VW42A-UBD2V83a9vKfd8ZcPvS6JnAFhMLOQUtaibAFR7fWHCc8XpMmk3qv-mzYuSspWoywQTpHCNEEIhzyAKxCCLVSMi30kkUuHEXQrj77ew95gzpE_klm4-la0HdFcRVbayvYjUFXepUNW_BKiG2WPy_JE?purpose=inline)

NixOS + Nix flakes

Operating system, configuration, reproducible builds

Core

[IXP from scratch: Part 2 — Network and security design | APNIC Blog](https://images.openai.com/static-rsc-4/3bFikHBeUnYIzNg57Y_0oZt74-xIAtcsSV4Nf4BRX1H54tBzaKfMgAM2Yl7a7Bi8SMJVzStRMTO4iTAHm9LpDAJTURvzdWfNbP56bkXioj2esvOvpHwEs2CZoKR-i9pBkUZtERKiEZRE169dkYjtsdVp5MmRFSNRcQzNj906Iak?purpose=inline)

microvm.nix + QEMU/KVM

Fast disposable NixOS development machines

Core

[Building a cross platform Rust CI/CD pipeline with GitHub Actions](https://images.openai.com/static-rsc-4/AIBv059WEUbUQJJxX5ILTs3wLPBOexEPkq12X3rnJVCz1eIfqPv5RGBKMJpBeqo2114TUE1XKqSk0_7AdyS6Blj7aWXxQiWHjYypGEmZTSBw8wvpEwji9k8kUvworAhMgY_SCXFUxg3_xJb8gIqgJ7ED9Yhyu_AA2vinS71MhOE?purpose=inline)

Rust

Reasoner, fact store, execution interface

Core

[Python logo Icons, Logos, Symbols – Free Download PNG, SVG](https://images.openai.com/static-rsc-4/DmsB8FS-GP7uphH6D36okAKArZlBuv18j7laB7MGQztxtnElBP3iuvRtFFsgJN3_CMjTR795lNP5nkz0C0O5HRM_6vUhOfMDScUzQErc9yfIrgdVyj38VLAdNtbsn3vWhJAUhRcvYx9LUssqXM5zJvcGr4rSiP0dNojMqKdTlnc?purpose=inline)

Python

Test driver, orchestration, prototypes

[Logo SQLite – Logos PNG](https://images.openai.com/static-rsc-4/DB8WVS6NrLCtUSYIc2zTPGzrMvrfjPYZpaPLLiELKaGa-8ig6i55NjodHWZqWiL__4SWevhxL3ba1kAF3Oq8brovMP1dXTdtm6k7QmtOMoYPoCrfB7byzg0w9qPHn11PT6I-8w3z6cczqMbyPlGjM0DKm0LT-4oa8zA_FnqDFow?purpose=inline)

SQLite

Persistent facts, metadata, provenance

[systemd logo](https://images.openai.com/static-rsc-4/iXy_eLTjojXNzvqS2XaDdcvi9e7FW7Da5eM3nJjv3cuUBBdQyRw3Y-ZODiqCajlygUggBSs5tFY6eqEPXaI30Hy7qi-PwK_pRtsFpco6VCRoS2s5m-V0m8cENgE_LzxKc8h4ni2o6w9-VAz82BSSesALzdZoSBmAogLxlKUwZZU?purpose=inline)

systemd + D-Bus

Observe and control actual machine state

### 3.1 Nix ecosystem

| Tool              | Purpose                                | Recommendation                              |
| ----------------- | -------------------------------------- | ------------------------------------------- |
| Nix               | Build and package system               | Essential                                   |
| Nix flakes        | Reproducible project inputs            | Essential                                   |
| NixOS modules     | Declarative system model               | Essential                                   |
| microvm.nix       | Lightweight VM management              | Essential                                   |
| NixOS test driver | Integration testing                    | Essential                                   |
| devenv            | Development environments and services  | Recommended                                 |
| flake-parts       | Organizing larger flakes               | Recommended                                 |
| nix-direnv        | Automatic development-shell activation | Recommended                                 |
| Cachix            | Binary caching                         | Recommended                                 |
| Attic             | Self-hosted binary cache               | Later                                       |
| Crane             | Efficient Rust builds through Nix      | Recommended                                 |
| nixpkgs-fmt       | Nix formatting                         | Use a maintained formatter such as `nixfmt` |

Relevant documentation:

- [microvm.nix](https://github.com/microvm-nix/microvm.nix)
- [NixOS VM integration testing](https://nix.dev/tutorials/nixos/integration-testing-using-virtual-machines.html)
- [NixOS module system](https://wiki.nixos.org/wiki/Modules)
- [devenv](https://github.com/cachix/devenv)
- [Nix flake checks](https://github.com/NixOS/nix/blob/master/src/nix/flake-check.md)

Important: Use the NixOS module system as the canonical configuration interface. Avoid building a parallel configuration language that eventually has to be translated back into NixOS.

### 3.2 Virtualization strategy

Use three levels of isolation, rather than choosing one virtualization technology for everything.

[Libvirt 12.0: ARM64 támogatás és fejlesztések a Bhyve BSD hypervisorhoz | Linux Mint Magyar Közösség](https://images.openai.com/static-rsc-4/aLQcauXlJlB-fRgTM2oJjdTTH6amdDx0Y5X0EB2SNe5Lsdv9ZSUrZjmoqteYXOy1Ucz7WTZCCTy8ZQOSAPt7oHwCzv5yacSjr0-vXbQWlyHnhAe8Ft-U2nz2uMfflHCyvSmdaY-lc1r5r1qYMrlz1Us0y159hM2QG6rGBLWDNEs?purpose=inline)

QEMU + KVM

Full virtualization, kernel testing, realistic hardware emulation, and debugging.

Best for realistic OS integration tests.

[MicroVMs - jmanteau](https://images.openai.com/static-rsc-4/T3ElZUasoM3qIMBvd8X1IGiujVC0gQYVsDT7CV05kPuHUabS33xFF6BQW0q_SM93p9gZQHpEEw0emmDQlj9ccy5jYcXY1tQNgw-2gDQeQ2FIV-oAleYA17W7qHAqzqij-NJO9qwma-FNjMjVKOJUaqBt4zVjiWxvoX5AQpQQIfY?purpose=inline)

microvm.nix

Primary interactive development environment. It supports multiple hypervisor backends, including QEMU, cloud-hypervisor, Firecracker, and others.

Best for rapid deployment of disposable NixOS machines.

[Podman Icon & Logo | Dashboard Icons & Logos](https://images.openai.com/static-rsc-4/YBT1m6X7SOs2YB2nmwpn4ynUs3WwUkeXKH41r07WJf1-VF_rkbMIHapg3T_WwasOuZIREEm1bE6h04YdpUZgmQ1gCtdHKIb3YdepR2k1avpECR8odtDfZnbJFi3TSlfxzdSrcv5iLj097yGbwYQpgmQzLcT6Ual1ni1-g6S5icg?purpose=inline)

Podman / systemd-nspawn

Lightweight tests of services, APIs, and individual components.

Best for tests that do not require a separate kernel.

A critical distinction: microvm.nix is an orchestration and packaging framework, not a hypervisor itself.

For this project, start with its QEMU/KVM backend. Later benchmark Firecracker or cloud-hypervisor if boot latency and memory overhead justify the additional constraints.

QEMU's `microvm` machine type is also worth investigating for minimal guests, but it has hardware-device and hotplug limitations.&#x20;

[image](https://www.google.com/s2/favicons?domain=https://www.qemu.org\&sz=32)

QEMU documentation+2



My VM recommendation: microvm.nix for daily work, NixOS test driver for automated integration tests, and ordinary QEMU/KVM for debugging and full-machine scenarios.

## 4. The Reasoner: the most important engineering decision

This is where I would invest the most architectural thought.

The reasoner will determine whether Semantic NixOS becomes a genuinely useful operating system or just an ontology viewer with some automation.

There are two separate problems:

1. Representing and reasoning about general knowledge.
2. Reasoning efficiently about the current state and desired state of a computer.

They overlap, but they are not identical.

### 4.1 What kind of reasoner do we need?

I would not attempt to implement a complete first-order logic theorem prover from scratch.

SUMO uses SUO-KIF, which supports expressive logical statements. A Datalog engine cannot simply execute every SUMO axiom without translating or restricting its semantics.

Instead, build a layered reasoning architecture.

## Reasoning architecture

SUMO / SUO-KIF

General-purpose ontology and logical axioms

Semantic normalization

KIF parsing, symbol interning, type information, rule extraction

Datalog engine

Fast relational inference and recursive rules

Primary

Theorem prover

Selected first-order logic problems

Secondary

Unified knowledge and proof interface

Facts, rules, conclusions, explanations, confidence and validity

### 4.2 Existing reasoning engines worth considering

These are the candidates I would actually evaluate.

A. Ascent

My Rust shortlist leader

Rust-native Datalog

Ascent provides declarative Datalog rules directly in Rust, including parallel evaluation.

Advantages:

- Native Rust integration.
- Parallel rule evaluation.
- Relatively easy to prototype.
- Can be embedded directly in the Reasoner process.

Disadvantages:

- Less control over the complete evaluation architecture.
- Its macro-based rule representation may constrain some dynamic rule-loading designs.

Recommendation: First serious prototype candidate.&#x20;

[image](https://www.google.com/s2/favicons?domain=https://docs.rs\&sz=32)

Rust



[Ascent source](https://github.com/s-arash/ascent)

B. Datafrog

Lightweight embedded Datalog

Datafrog is particularly interesting because it gives you a lightweight relational engine without forcing a large framework on your architecture.

Advantages:

- Rust-native.
- Small conceptual surface.
- Efficient sorted relations and joins.
- Suitable for embedding into a custom application.

Disadvantages:

- You implement more of the surrounding engine yourself.
- It is not a complete general-purpose rule-management system.

Recommendation: Strong candidate if you want to own the Reasoner architecture.&#x20;

[image](https://www.google.com/s2/favicons?domain=https://docs.rs\&sz=32)

Rust+1



[Datafrog source](https://github.com/rust-lang/datafrog)

C. Soufflé

Performance benchmark

Compiled parallel Datalog

Soufflé compiles Datalog programs into native parallel C++ executables.

Advantages:

- Mature Datalog implementation.
- Strong optimization.
- Parallel execution.
- Profiling and provenance facilities.

Disadvantages:

- C++ integration boundary.
- Compilation overhead for frequently changing rule programs.
- Less convenient for a deeply integrated Rust application.

Recommendation: Use it as a performance reference and potentially as a production backend for large, stable reasoning workloads.&#x20;

[image](https://www.google.com/s2/favicons?domain=https://souffle-lang.org\&sz=32)

souffle-lang.org+2



[Soufflé documentation](https://souffle-lang.org/)

D. egglog

Equality reasoning and optimization

Particularly interesting for representing equivalent configurations, exploring alternative plans, and optimizing expressions.

This could become valuable for configuration optimization and plan synthesis, but I would not use it as the primary fact engine.

[image](https://www.google.com/s2/favicons?domain=https://docs.rs\&sz=32)

Docs.rs+1

[egglog source](https://github.com/egraphs-good/egglog)

### 4.3 My recommendation: develop our own Reasoner, but not immediately

I would use Ascent to establish the semantics and benchmark Datafrog and Soufflé against it.

Then develop a dedicated Rust Reasoner if the benchmarks establish that the existing engines cannot meet our requirements.

The custom Reasoner should be an independent component with a stable interface, not an engine whose internals leak throughout the project.

Its internal architecture should include:

| Component           | Implementation                                |
| ------------------- | --------------------------------------------- |
| Symbol table        | Integer IDs and string interning              |
| Fact storage        | Compact relations                             |
| Rule representation | Compiled rule structures                      |
| Join engine         | Indexed relational joins                      |
| Evaluation          | Semi-naïve fixed-point evaluation             |
| Incremental updates | Delta-based reevaluation                      |
| Type checking       | Indexed ontology predicates                   |
| Provenance          | Compact proof DAG                             |
| Query engine        | Indexed fact and rule queries                 |
| Memory management   | Arena allocation and compact identifiers      |
| Parallelism         | Rayon initially; selective parallel execution |

The most important performance feature is incremental reasoning.

If a service changes state, the engine should not recompute the entire knowledge base.

It should update affected relations and propagate the consequences.

For example:

```
nginx.enabled = true
       |
       v
nginx is configured
       |
       v
nginx provides HTTP capability
       |
       v
web server capability exists
       |
       v
firewall policy may require TCP/80
       |
       v
check whether TCP/80 is permitted
```

If the firewall changes, the system should recompute only the affected conclusions.

### 4.4 First-order logic and SUMO compatibility

This is a critical requirement.

Do not silently treat all SUMO axioms as Datalog.

Define explicit support levels:

| Logic feature                | Treatment                                 |
| ---------------------------- | ----------------------------------------- |
| Ground facts                 | Native                                    |
| Horn clauses                 | Native Datalog subset                     |
| Recursive rules              | Native                                    |
| Multiple inheritance         | Native                                    |
| Existential variables        | Explicit compilation or separate handling |
| Negation                     | Stratified, safety-checked subset         |
| Equality                     | Dedicated equivalence handling            |
| Universal first-order axioms | Translation when valid                    |
| General first-order formulas | External theorem prover                   |

Investigate integrating an existing automated theorem prover, such as Vampire or E Prover.

The theorem prover should answer bounded, selected logical questions. It should not be invoked for every ordinary operating-system fact lookup.

Use SigmaKEE as a reference for SUMO semantics, ontology validation, and inference behavior.&#x20;

[image](https://www.google.com/s2/favicons?domain=https://ontologyportal.org\&sz=32)

Ontology Portal+2



## 5. Semantic data model

The data model should be independent of the particular reasoner implementation.

This is important because we may replace Ascent with our own engine later.

### 5.1 Five categories of knowledge

I recommend distinguishing these explicitly:

1. Ontological knowledge: What kinds of things exist?
2. Declarative knowledge: What has been configured?
3. Observational knowledge: What is actually happening?
4. Derived knowledge: What follows from the other knowledge?
5. Intentional knowledge: What should be true?

For example:

| Category      | Example                           |
| ------------- | --------------------------------- |
| Ontological   | Nginx is a web server             |
| Declarative   | Nginx is enabled in configuration |
| Observational | Nginx process is running          |
| Derived       | HTTP service is available         |
| Intentional   | HTTP service should be available  |

These are not interchangeable.

An enabled service is not necessarily running. A running service is not necessarily healthy. A healthy service is not necessarily accessible externally.

The reasoner must understand these distinctions.

### 5.2 Canonical fact representation

Use an internal typed representation:

```
struct Fact {
    subject: EntityId,
    predicate: PredicateId,
    object: Value,

    source: FactSource,
    timestamp: Timestamp,
    validity: Validity,
    provenance: Option<ProofId>,
}

enum Value {
    Entity(EntityId),
    String(StringId),
    Integer(i64),
    Boolean(bool),
    Decimal(f64),
}
```

Avoid storing everything as strings.

Use integer IDs internally, with human-readable names at the interface boundary.

For large relations, use compact typed columns rather than individually allocated objects.

### 5.3 Three-valued truth

Implement three-valued truth semantics:

- True.
- False.
- Unknown.

An absent fact must not automatically mean false.

For example:

```
SSH service is running       = True
SSH service is disabled     = False
SSH service is externally reachable = Unknown
```

The third result matters enormously in infrastructure management.

An unknown firewall condition must not be interpreted as permission to open a port.

### 5.4 Time and changing state

Facts need temporal validity.

An observation that a service was running ten minutes ago should not remain permanently true.

Each observed fact should have:

- Observation timestamp.
- Source.
- Expiration or refresh policy.
- Optional confidence or quality indicator.
- Current/historical status.

This allows the system to distinguish current reality from historical knowledge.

## 6. NixOS semantic integration

This is the central development effort.

NixOS already knows a great deal about the system. We need to expose that knowledge in a form that the ontology and Reasoner can use.

### 6.1 Build a NixOS semantic adapter

Develop a dedicated project component:

`semantic-nixos-nix`

Its job is to translate NixOS configuration and option information into normalized semantic facts.

It should inspect:

- NixOS option declarations.
- Option types.
- Current evaluated option values.
- Package derivations.
- Enabled services.
- systemd unit definitions.
- Users and groups.
- Networking configuration.
- Storage configuration.
- Boot configuration.
- Hardware configuration.
- Security policies.

Use the Nix module system as the source of truth.

Do not create a manually maintained mapping for every NixOS option.

Instead, create a metadata registry that maps NixOS option paths and module-specific metadata to semantic predicates.

Example:

```
{
  services.nginx.enable = {
    semanticClass = "SoftwareApplication";
    semanticPredicate = "configuredEnabled";
  };

  networking.firewall.allowedTCPPorts = {
    semanticClass = "NetworkPolicy";
    semanticPredicate = "permitsTCPPort";
  };
}
```

This is illustrative. The real implementation should define an appropriate typed metadata schema.

### 6.2 Export configuration through a controlled interface

Use Nix evaluation to generate a normalized semantic manifest.

For example:

```
nix eval --json \
  .#nixosConfigurations.semantic-vm.config.semantic.export
```

The actual export option should be implemented as a NixOS module.

The manifest should contain:

```
{
  "host": "semantic-vm",
  "configurationRevision": "abc123",
  "services": [],
  "packages": [],
  "network": {},
  "storage": {},
  "users": [],
  "security": {}
}
```

Do not dump the entire NixOS configuration into the Reasoner.

That would create unnecessary evaluation costs, enormous data structures, and a fragile dependency on internal NixOS implementation details.

Export only relevant, explicitly supported semantic information.

### 6.3 Semantic metadata should be extensible

NixOS has thousands of options. We should not attempt to model all of them initially.

Create a system where NixOS modules can declare their own semantic metadata.

For example, a third-party NixOS module should be able to describe:

```
This service provides a database capability.
This service requires persistent storage.
This service exposes a network endpoint.
This service depends on another service.
This service handles sensitive information.
```

The ontology then supplies the meaning of those declarations.

This is one of the most important extensibility mechanisms in the entire project.

## 7. Runtime observation and control

Declarative configuration is not the same as actual operating-system state.

We need an observation subsystem.

### Recommended tools

| Tool          | Purpose                      |
| ------------- | ---------------------------- |
| systemd D-Bus | Service and unit state       |
| `/proc`       | Processes and resource usage |
| `/sys`        | Hardware and kernel state    |
| `iproute2`    | Network state                |
| `lsblk`       | Block devices                |
| `udev`        | Device discovery             |
| `nftables`    | Firewall state               |
| `systemd`     | Service lifecycle            |
| `journalctl`  | Logs and diagnostics         |
| `smartctl`    | Storage health               |

The initial implementation should use systemd D-Bus and selected Linux interfaces.

Do not deploy Prometheus, Grafana, Elasticsearch, or a large monitoring stack merely to inspect one development machine.

### 7.1 Observation architecture

```
NixOS configuration
       |
       v
Configuration adapter
       |
       v
Semantic facts <--------- Runtime observers
       |                       ^
       v                       |
    Reasoner              Linux / systemd
       |
       v
Desired-state comparison
```

The observer should publish changes rather than repeatedly dumping the entire machine state.

For example:

```
Fact added:
    service.nginx.processRunning = true

Fact removed:
    service.nginx.healthy = true

Fact added:
    service.nginx.healthy = false
```

Use event-driven updates where possible, with periodic reconciliation as a fallback.

## 8. Planning and action execution

This is what makes Semantic NixOS fundamentally different from a system that merely answers questions.

The system needs to translate intentions into executable changes.

### 8.1 Introduce a semantic action model

An action is not just a shell command.

It should be a typed object with:

- Preconditions.
- Intended effects.
- Required permissions.
- Dependencies.
- Resource requirements.
- Risk classification.
- Validation procedure.
- Rollback procedure.

Example:

```
action: EnableWebServer

preconditions:
  - package.nginx.available
  - storage.systemWritable
  - network.configurationValid

effects:
  - service.nginx.configuredEnabled
  - capability.httpServer.available

operations:
  - modifyNixOSOption:
      path: services.nginx.enable
      value: true

validation:
  - nixosConfigurationEvaluates
  - nginxServiceStarts
  - httpEndpointResponds

rollback:
  - restorePreviousNixOSGeneration
```

This is a conceptual schema, not a commitment to YAML as the implementation format. I would use typed Rust structures internally.

### 8.2 Action lifecycle

Every action should follow the same lifecycle:

1. Interpret intent

   Determine what the user wants to achieve.
2. Establish current state

   Gather relevant declarative and observational facts.
3. Reason about requirements

   Determine which conditions must hold.
4. Construct a plan

   Generate candidate actions and their dependencies.
5. Validate the plan

   Check types, constraints, permissions, resource availability, and conflicts.
6. Simulate

   Evaluate and build the proposed NixOS configuration.
7. Authorize

   Obtain approval when required by the risk policy.
8. Execute

   Apply the approved configuration using NixOS.
9. Verify

   Observe the machine and establish whether the intended effects occurred.
10. Record

    Store the resulting facts, proof, action history, and configuration generation.

### 8.3 Use NixOS itself to execute configuration changes

This is important: don't reinvent deployment or configuration activation.

Use existing NixOS mechanisms:

- `nix eval` for evaluation.
- `nix build` for building.
- `nixos-rebuild` for applying configurations.
- NixOS generations for rollback.
- systemd for service operations.
- `nix flake check` for project validation.

For a proposed change:

```
Intent:
    Make the machine provide HTTPS.

        |
        v

Semantic plan:
    Configure a web server.
    Configure a certificate.
    Configure the required firewall policy.

        |
        v

Nix configuration:
    Generate or modify typed NixOS options.

        |
        v

Validation:
    Evaluate configuration.
    Build system closure.
    Run integration tests.

        |
        v

Approval:
    Present the proposed changes.

        |
        v

Execution:
    Activate new NixOS generation.

        |
        v

Verification:
    Confirm HTTPS is available.
```

The system must not assume that a successful NixOS rebuild means the requested objective has been achieved.

Runtime verification is mandatory.

### 8.4 Safety architecture

I would implement four action levels.

| Level | Example                                   | Authorization                 |
| ----- | ----------------------------------------- | ----------------------------- |
| 0     | Read system information                   | Automatic                     |
| 1     | Evaluate and simulate configuration       | Automatic                     |
| 2     | Reversible configuration changes          | Approval initially            |
| 3     | Destructive or security-sensitive changes | Explicit approval, safeguards |

For destructive operations, require additional confirmation and, where appropriate, a backup.

Never let arbitrary generated shell commands become the default execution interface.

Use a registry of typed, allowlisted actions.

The action system should also prevent privilege escalation, unauthorized secret access, and unintended changes outside the target machine.

### 8.5 Planning algorithms

Start with a simple dependency-aware planner.

A plan can be represented as a directed graph:

```
Install package
      |
      v
Configure service
      |
      v
Configure TLS
      |
      v
Configure firewall
      |
      v
Activate system
      |
      v
Verify endpoint
```

Use topological sorting for execution order.

Later, consider:

- Constraint satisfaction.
- Cost-based action selection.
- Resource-aware planning.
- Alternative plan generation.
- Conflict detection.
- Automated recovery.

Do not start with a sophisticated AI planning framework. First make the typed action system correct and explainable.

## 9. Storage and performance architecture

This is another area where I would be deliberately conservative.

A common mistake is introducing a large graph database before understanding the actual workload.

You do not need one initially.

### 9.1 Recommended storage

## Two-tier knowledge storage

In-memory Reasoner

Hot path

- Interned symbols.
- Indexed relations.
- Derived facts.
- Incremental inference state.
- Active proof structures.

SQLite

Persistent storage

- Source facts.
- Historical observations.
- Action history.
- Configuration revisions.
- Proof metadata.
- Cached semantic manifests.

Use SQLite initially because it is simple, embedded, reliable, and requires no database server.

For the in-memory engine, use compact typed relations.

Potential Rust components:

- `hashbrown` for hash maps.
- `rustc-hash` or another benchmarked fast hasher for trusted internal keys.
- `smallvec` for small collections.
- `rayon` for selective parallel work.
- `bumpalo` for arena allocation.
- `rkyv` or a simpler versioned binary format for carefully chosen snapshots.

These are candidates, not mandatory dependencies. Benchmark actual allocations and workloads before selecting them.

### 9.2 Avoid expensive architectural choices

I would initially avoid:

- Neo4j.
- Elasticsearch.
- Kafka.
- Kubernetes.
- A distributed graph database.
- A microservices architecture.
- A permanently running AI model.
- A large message broker.

None of these is required to establish the central idea.

A single Rust process, SQLite, NixOS, and systemd are sufficient.

### 9.3 Reasoner performance requirements

We should establish performance targets from the beginning.

The following are proposed engineering objectives, not measured results or guaranteed performance.

## Initial performance budget

Target for a modest single-machine installation; revise after benchmarking.

| Operation                     | Target       |
| ----------------------------- | ------------ |
| Interned fact insertion       | Under 100 μs |
| Indexed fact lookup           | Under 1 ms   |
| Small local rule update       | Under 50 ms  |
| Typical incremental inference | Under 250 ms |
| Semantic query response       | Under 100 ms |
| Reasoner idle memory          | Under 50 MB  |
| Small-system working memory   | Under 256 MB |
| Reasoner CPU while idle       | Near zero    |

Scaling targets

- 100,000 facts: comfortable interactive operation.
- 1 million facts: benchmark and optimize.
- 10 million facts: stretch goal, with workload-specific memory budgets.

The full SUMO ontology may require substantially more memory than the incremental operating-system knowledge itself. Measure the ontology separately from live system facts.

### 9.4 Memory optimization

Prioritize these techniques:

1. Integer IDs instead of repeated strings.
2. Interned predicates and entities.
3. Compact tuple representations.
4. Indexed joins.
5. Semi-naïve evaluation.
6. Avoiding duplicate derived facts.
7. Compact proof DAGs.
8. Lazy explanation construction.
9. Incremental invalidation.
10. Selective persistence of derived facts.

Do not store a complete explanation tree on every derived fact.

Store references to shared proof nodes. Materialize full explanations only when requested.

### 9.5 CPU optimization

Do not assume parallelism always improves performance.

Small reasoning workloads can be slower with thread coordination.

Use:

- Single-threaded execution for small workloads.
- Parallel joins for sufficiently large relations.
- Workload-aware scheduling.
- Incremental evaluation for local changes.
- Query planning to avoid large Cartesian products.
- Profiling to identify expensive rules.

The Reasoner should have a configurable CPU budget and should yield resources to the operating system.

### 9.6 Benchmarking tools

Use:

| Tool               | Purpose                            |
| ------------------ | ---------------------------------- |
| Criterion.rs       | Rust microbenchmarks               |
| `perf`             | CPU profiling                      |
| flamegraph         | Hot-path visualization             |
| heaptrack          | Heap allocation analysis           |
| Massif             | Memory profiling                   |
| `/usr/bin/time -v` | Peak RSS and execution statistics  |
| `hyperfine`        | Command-line benchmark comparisons |
| Nix build logs     | Build and derivation performance   |

Establish reproducible benchmarks for:

- Parsing SUMO.
- Loading ontology facts.
- Building indexes.
- Initial inference.
- Incremental inference.
- Proof construction.
- Query execution.
- Memory consumption.

## 10. Developer experience and iteration speed

This project needs a development environment that makes experimentation cheap.

The objective is to avoid rebuilding the world whenever a reasoning rule changes.

### 10.1 Host development environment

My preferred environment:

- NixOS host.
- Nix flakes.
- `nix develop`.
- `devenv` or a straightforward custom development shell.
- Rust toolchain.
- Python test tooling.
- SQLite CLI.
- QEMU/KVM.
- microvm.nix.
- VS Code or Neovim with Rust Analyzer.

Use `Crane` for Rust packaging and caching. It allows dependency compilation to be separated from application-source changes, reducing unnecessary rebuilds.

### 10.2 Three iteration loops

Fastest

Loop A — Reasoner development

Edit a Rust rule or parser.

```
cargo test
cargo bench
```

No VM boot. No NixOS rebuild.

Use this for the majority of development.

Intermediate

Loop B — Semantic integration

Change NixOS metadata or semantic adapters.

```
nix eval --json \
  .#nixosConfigurations.semantic-vm.config.semantic.export
```

Run the Reasoner against the resulting manifest.

No need to boot the VM for most tests.

Full integration

Loop C — Real OS testing

Build and boot a microVM.

```
nix build .#checks.x86_64-linux.semantic-vm

microvm -c ./result/bin/microvm-run
```

The exact launch command depends on the generated microVM configuration.

Test actual service behavior, D-Bus integration, configuration activation, and rollback.

The vast majority of development should happen in loops A and B.

VM testing should be reserved for functionality that genuinely requires a running operating system.

### 10.3 Development environment configuration

Suggested development shell:

```
{
  devShells.x86_64-linux.default =
    pkgs.mkShell {
      packages = with pkgs; [
        rustc
        cargo
        rust-analyzer
        clippy
        rustfmt

        python3
        sqlite
        jq

        qemu_kvm
        libvirt
        just

        hyperfine
        linuxPackages.perf
      ];
    };
}
```

This is a starting sketch. Some package attributes and VM utilities may need adjustment for the pinned Nixpkgs revision and host platform.

### 10.4 Continuous integration

Use:

- GitHub Actions initially.
- `nix flake check`.
- Rust tests and Clippy.
- Python oracle tests.
- NixOS integration tests.
- Cached Nix build artifacts.

The NixOS test framework already supports multi-machine tests and QEMU-backed execution. It can also test systemd-nspawn containers when full virtualization is unnecessary.&#x20;

[image](https://www.google.com/s2/favicons?domain=https://nix.dev\&sz=32)

nix.dev documentation+2



## 11. Project organization

I recommend a monorepo initially.

The ontology, Reasoner, NixOS adapter, and executor need to evolve together. Separating them into many repositories would create unnecessary friction.

Suggested structure:

```
semantic-nixos/
│
├── flake.nix
├── flake.lock
├── devenv.nix
├── justfile
│
├── ontology/
│   ├── sumo/
│   ├── nixos/
│   ├── linux/
│   ├── services/
│   └── mappings/
│
├── reasoner/
│   ├── Cargo.toml
│   └── src/
│       ├── parser/
│       ├── symbols/
│       ├── facts/
│       ├── relations/
│       ├── rules/
│       ├── evaluator/
│       ├── query/
│       ├── provenance/
│       └── incremental/
│
├── semantic-nixos/
│   ├── nix/
│   │   ├── modules/
│   │   ├── adapters/
│   │   └── manifests/
│   │
│   ├── observers/
│   │   ├── systemd/
│   │   ├── process/
│   │   ├── network/
│   │   └── storage/
│   │
│   └── executor/
│       ├── actions/
│       ├── planner/
│       ├── validation/
│       └── rollback/
│
├── api/
│   ├── schema/
│   └── service/
│
├── tests/
│   ├── unit/
│   ├── semantic/
│   ├── integration/
│   ├── performance/
│   └── fixtures/
│
├── vms/
│   ├── development/
│   ├── scenarios/
│   └── configurations/
│
└── docs/
    ├── architecture/
    ├── ontology/
    ├── reasoner/
    └── security/
```

### 11.1 Component boundaries

Define stable interfaces early:

| Component       | Interface                                  |
| --------------- | ------------------------------------------ |
| Ontology loader | KIF to normalized knowledge                |
| Reasoner        | Facts, rules, queries, proofs              |
| NixOS adapter   | Nix evaluation to semantic manifest        |
| Observer        | Runtime events to semantic facts           |
| Planner         | Goal to action graph                       |
| Validator       | Action graph to validation result          |
| Executor        | Approved action graph to system operations |
| Verifier        | Runtime state to goal satisfaction         |
| Persistence     | Knowledge and history storage              |

This permits the Reasoner to change without rewriting the NixOS adapter.

## 12. User interface and API

The first version should not require a sophisticated graphical interface.

Build a command-line interface and a local API.

### 12.1 CLI

Call the executable `snx` (Semantic NixOS).

Proposed interface:

```
# Inspect the machine
snx system describe

# Ask semantic questions
snx ask "Which web services are running?"

# Explain a conclusion
snx explain service.nginx

# Inspect current versus desired state
snx status

# Set an objective
snx goal "Provide an HTTPS web server"

# Generate a plan
snx plan

# Validate the proposed changes
snx validate

# Simulate execution
snx simulate

# Execute an approved plan
snx apply

# Verify the result
snx verify

# Inspect action history
snx history
```

The CLI should return structured JSON as well as readable output.

### 12.2 API

Use Rust with `axum` for the local API.

Suggested endpoints:

| Endpoint         | Operation              |
| ---------------- | ---------------------- |
| `GET /system`    | Describe system        |
| `GET /facts`     | Query facts            |
| `POST /query`    | Execute semantic query |
| `POST /explain`  | Explain conclusion     |
| `POST /goals`    | Submit objective       |
| `POST /plans`    | Generate plan          |
| `POST /validate` | Validate plan          |
| `POST /apply`    | Execute approved plan  |
| `GET /history`   | Action history         |

Use JSON Schema or an equivalent typed schema for interchange.

The API should bind to localhost by default. Remote administration should require explicit authentication and authorization.

### 12.3 Natural-language interface

Natural-language interpretation should be an optional frontend, not part of the core Reasoner.

For example:

```
User:
    Make this machine a web server.

Language interface:
    Interprets objective.

Semantic system:
    Determines requirements.

Reasoner:
    Derives applicable facts and constraints.

Planner:
    Produces actions.

Validator:
    Checks actions.

Executor:
    Applies approved changes.
```

An LLM can help translate natural language into structured goals, but it must not be trusted to establish facts or authorize operations.

The structured semantic system remains authoritative.

## 13. Development roadmap

I would develop this in eight phases.

The order matters: prove the complete semantic control loop early rather than spending months building an enormous ontology or a theoretically perfect reasoner.

## Phase 1 — Semantic foundation

First milestone

Goal: Understand a NixOS machine semantically.

Deliverables:

- SUMO integration.
- NixOS domain ontology.
- KIF parser and normalized representation.
- Fact storage.
- Basic class and relation reasoning.
- NixOS semantic manifest exporter.

Acceptance test:

```
Given a NixOS configuration,
identify enabled services,
their capabilities,
dependencies,
and relevant system resources.
```

No VM execution required yet.

## Phase 2 — Runtime awareness

Goal: Understand what the machine is actually doing.

Deliverables:

- systemd D-Bus observer.
- Process observer.
- Network observer.
- Storage observer.
- Declarative versus observed state comparison.
- Temporal fact management.

Acceptance test:

```
Detect when nginx stops running.
Infer that its HTTP service is unavailable.
Explain the conclusion and its evidence.
```

## Phase 3 — Production-quality Reasoner

Goal: Establish correct and efficient inference.

Deliverables:

- Datalog evaluation.
- Indexed joins.
- Incremental inference.
- Three-valued truth.
- Proof provenance.
- Rule validation.
- Performance benchmarks.

Acceptance test:

```
Change one system fact.
Recompute affected conclusions.
Preserve unaffected results.
Produce an explanation.
```

## Phase 4 — Semantic planning

Goal: Turn goals into proposed system changes.

Deliverables:

- Typed goal representation.
- Action registry.
- Preconditions and effects.
- Dependency graph.
- Constraint validation.
- Risk classification.

Acceptance test:

```
Goal:
    Provide HTTPS.

Result:
    A valid, ordered, explainable action plan.
```

## Phase 5 — Execution

Goal: Make actual changes to NixOS.

Deliverables:

- Nix configuration generation.
- Nix evaluation.
- System closure building.
- Approval interface.
- NixOS activation.
- Rollback.
- Runtime verification.

Acceptance test:

```
Request HTTPS.
Generate configuration.
Build and activate it.
Verify the endpoint.
Demonstrate rollback.
```

## Phase 6 — Full semantic operating system

Goal: Expand beyond basic service management.

Deliverables:

- User and permission semantics.
- Storage and filesystem semantics.
- Network topology.
- Firewall reasoning.
- Resource allocation.
- Security constraints.
- Backup and recovery.
- Multi-service planning.

Acceptance test:

```
Identify a resource conflict.
Explain why it exists.
Propose and validate a resolution.
```

## Phase 7 — Natural-language interaction

Goal: Make the system accessible without requiring knowledge of Nix or SUMO.

Deliverables:

- Natural-language goal interpretation.
- Interactive planning.
- Explanation interface.
- Clarification of ambiguous goals.
- Approval workflow.

Acceptance test:

```
"Make this machine a secure web server."

The system understands, plans, validates,
executes with approval, and verifies.
```

## Phase 8 — Generalization

Goal: Make the semantic architecture reusable.

Potential domains:

- Containers.
- Kubernetes.
- Cloud infrastructure.
- Databases.
- Networking.
- Development environments.
- Distributed systems.

The Reasoner and upper ontology remain shared. New domain adapters provide the concrete representations and actions.

## 14. The first demonstrator: a complete working scenario

This should be the first real objective.

Not a demo that merely answers questions. A demo that actually changes a running operating system.

## Scenario: Turn a minimal NixOS machine into a web server

[File:Network Architecture Diagram - Simple Web Stack.pdf - Wikimedia Commons](https://images.openai.com/static-rsc-4/iYyQ8La-pDmwsf_zSP2ENhiegtCdwgkmmU_oXMiHGD-M6GWkKIq3ee-PBKlJzL9fpk3xfVuOPHorJDeA2XlpzGhq_dY3Lnq7yk7nFEKUT6IGhjg5zr2aLsNpIB-Fbd2FPG_iJF6zq3tds9X1IorJXSkdZNKls279OaoJ810NGXE?purpose=inline)

[commons.wikimedia.org](https://commons.wikimedia.org/wiki/File%3ANetwork_Architecture_Diagram_-_Simple_Web_Stack.pdf)

Initial state

- Minimal NixOS VM.
- No web server configured.
- No HTTP endpoint.
- No application service.

User instruction

> Make this machine provide a secure HTTPS web service.

Semantic reasoning

1. A web service requires a server application.
2. HTTPS requires TLS configuration.
3. The service requires network accessibility.
4. The firewall must permit the appropriate traffic.
5. The certificate must be valid for the intended deployment.
6. The system must have sufficient resources.

Planning

The system derives the necessary configuration and identifies missing information, such as the domain name and certificate strategy.

Execution

It generates a NixOS configuration, validates and builds it, obtains authorization, and activates the new generation.

Verification

It checks that the service is running, TLS is configured, and the endpoint is reachable.

Explanation

It can explain what it changed, why it changed it, which facts justified the changes, and how to reverse them.

This single scenario exercises practically every important architectural layer.

I would make it the project's continuous integration showcase.

## 15. Testing strategy

Testing must happen at four different levels.

| Test type   | What it establishes                                | Tool              |
| ----------- | -------------------------------------------------- | ----------------- |
| Unit        | Individual algorithms work                         | Rust tests        |
| Semantic    | Rules and ontology produce correct conclusions     | Reasoner fixtures |
| Integration | Components cooperate correctly                     | NixOS test driver |
| Acceptance  | The intended operating-system behavior is achieved | microvm.nix       |

### 15.1 Semantic correctness

Create small, carefully controlled ontology fixtures.

For every inference rule, test:

- Positive cases.
- Negative cases.
- Unknown cases.
- Multiple inheritance.
- Recursive relationships.
- Invalid types.
- Contradictory information.
- Missing information.
- Provenance.
- Incremental updates.

### 15.2 Integration testing

Use a multi-VM environment:

```
              Test controller
                    |
             Semantic Reasoner
                    |
           +--------+--------+
           |                 |
       NixOS VM 1        NixOS VM 2
       Web server        Database
           |                 |
           +-------Network---+
```

Test whether the semantic layer correctly understands relationships across machines.

For example:

- The web server depends on the database.
- The database is unavailable.
- The web application is consequently unhealthy.
- The system proposes an appropriate recovery action.

The NixOS test driver is particularly useful because it can orchestrate multiple machines and test real service behavior.&#x20;

[image](https://www.google.com/s2/favicons?domain=https://nixdocs.j10s.io\&sz=32)

nix.dev documentation+1



### 15.3 Safety testing

Deliberately test:

- Invalid configuration proposals.
- Unauthorized actions.
- Conflicting goals.
- Missing preconditions.
- Failed Nix builds.
- Failed activation.
- Runtime verification failures.
- Rollback.
- Interrupted execution.
- Stale observations.

A failed action must not leave the system silently marked as compliant.

## 16. Major architectural risks

These are the risks I would explicitly track.

| Risk                                            | Mitigation                                  |
| ----------------------------------------------- | ------------------------------------------- |
| SUMO is too expressive for the primary reasoner | Layered logical support                     |
| Nix evaluation is expensive                     | Export selective semantic manifests         |
| Runtime state becomes stale                     | Event-driven observation and reconciliation |
| Full inference becomes expensive                | Incremental evaluation and indexing         |
| Proof storage consumes excessive memory         | Shared proof DAGs                           |
| Generated configuration is incorrect            | Typed NixOS options and validation          |
| Actions are unsafe                              | Typed action registry and authorization     |
| Ontology becomes unmanageable                   | Modular domain ontologies                   |
| Reasoner becomes tightly coupled to Nix         | Stable domain-neutral interfaces            |

One particularly important issue is ontology maintenance.

SUMO should not become a dumping ground for every NixOS implementation detail.

Keep three levels separate:

1. General concepts in SUMO.
2. Operating-system concepts in the Linux/NixOS domain ontology.
3. Concrete machine-specific facts in the knowledge store.

This separation is essential if the project is ever to extend beyond NixOS.

## 17. What not to build initially

To keep the project focused and fast, I would explicitly defer:

- A graphical desktop environment.
- A custom package manager.
- A custom operating-system configuration language.
- A distributed reasoning cluster.
- A general-purpose autonomous AI agent.
- A large graph database.
- A custom hypervisor.
- Complete SUMO first-order theorem proving.
- Full support for every NixOS option.
- Automatic execution of arbitrary shell commands.

These features could be considered later, but none is necessary to prove the fundamental idea.

## 18. Final technology decisions

Proposed initial architecture, subject to benchmarking and prototype validation.

| Area                          | Selected technology                    |
| ----------------------------- | -------------------------------------- |
| Host OS                       | NixOS                                  |
| Configuration                 | NixOS modules                          |
| Reproducibility               | Nix flakes                             |
| Development environments      | devenv / nix develop                   |
| Rust builds                   | Crane                                  |
| VM development                | microvm.nix                            |
| VM backend                    | QEMU/KVM                               |
| Integration testing           | NixOS test driver                      |
| Containers                    | Podman / systemd-nspawn                |
| Ontology                      | SUMO / SUO-KIF                         |
| Ontology tooling              | SigmaKEE                               |
| Initial Datalog engine        | Ascent                                 |
| Alternative embedded engine   | Datafrog                               |
| Performance reference         | Soufflé                                |
| Future optimization reasoning | egglog                                 |
| Custom Reasoner               | Rust                                   |
| Persistent storage            | SQLite                                 |
| Runtime observation           | systemd D-Bus and Linux interfaces     |
| Execution                     | NixOS rebuild and systemd              |
| API                           | Rust / axum                            |
| CLI                           | Rust / clap                            |
| Testing                       | Cargo, Python, NixOS tests             |
| Benchmarking                  | Criterion, perf, flamegraph, hyperfine |
| CI                            | GitHub Actions                         |
| Binary caching                | Cachix initially                       |

## 19. The most important strategic recommendation

I would make one architectural commitment before writing substantial code:

The Reasoner must be a first-class, independent component. NixOS must be its first deeply integrated semantic domain, not the thing that defines the Reasoner's capabilities.

That distinction matters.

The same engine should eventually be able to reason about:

- A NixOS host.
- A collection of Linux servers.
- A network.
- A database deployment.
- A Kubernetes cluster.
- A cloud infrastructure environment.

Those systems should be represented as entities, relationships, states, capabilities, constraints, and actions.

SUMO provides the common conceptual foundation. Domain ontologies provide specialized knowledge. Adapters connect those representations to real systems.

NixOS is an unusually good first target because its configuration is already declarative, typed, reproducible, and buildable.

### My recommended immediate implementation sequence

I would actually start with these six tasks:

1. Preserve and extend `sumo-nix`. Do not discard the existing KIF parser, ontology representation, crosswalks, or proof-of-concept Datalog work.
2. Create a Rust Reasoner prototype and benchmark Ascent against Datafrog and Soufflé using the actual SUMO and NixOS workloads.
3. Create the first NixOS semantic adapter, exporting a small, typed manifest.
4. Create a microvm.nix development machine with a minimal NixOS configuration.
5. Connect the Reasoner to that VM using systemd D-Bus and runtime observation.
6. Implement the first complete goal-to-plan-to-validation-to-execution-to-verification workflow.

Do not spend the first development cycle implementing a complete ontology or a complete theorem prover. Get the complete semantic control loop working first.

The real proof of the concept is not that the system can infer that Nginx is a web server.

It is that the system can understand that someone wants a web server, determine what that entails, reason about the machine's current state, construct the appropriate NixOS configuration, safely apply it, and prove that the machine now satisfies the objective.

That is the foundation of Semantic NixOS.

## 20. Reference material

These are the principal upstream resources to keep alongside the specification.

| Project                   | Reference                                                                                                                  |
| ------------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| SUMO                      | [Ontology Portal](https://ontologyportal.org/)                                                      |
| SUMO source               | [GitHub repository](https://github.com/ontologyportal/sumo)                                         |
| microvm.nix               | [GitHub repository](https://github.com/microvm-nix/microvm.nix)                                     |
| NixOS integration testing | [Nix.dev tutorial](https://nix.dev/tutorials/nixos/integration-testing-using-virtual-machines.html) |
| NixOS modules             | [Module documentation](https://wiki.nixos.org/wiki/Modules)                                         |
| Ascent                    | [Rust documentation](https://docs.rs/ascent/latest/ascent/)                                         |
| Datafrog                  | [GitHub repository](https://github.com/rust-lang/datafrog)                                          |
| Soufflé                   | [Official site](https://souffle-lang.org/)                                                          |
| egglog                    | [Documentation](https://egraphs-good.github.io/egglog/docs/egglog/)                                 |
| devenv                    | [GitHub repository](https://github.com/cachix/devenv)                                               |
| Nix flakes                | [NixOS documentation](https://wiki.nixos.org/wiki/Flakes)                                           |

Final decision: Start with NixOS + SUMO + a Rust Reasoner + microvm.nix. Keep the system monolithic at first, keep reasoning in memory, use SQLite for persistence, and use NixOS itself as the configuration and execution authority.

This provides the shortest path to a working semantic operating system without prematurely committing to infrastructure that will slow development or consume resources.
