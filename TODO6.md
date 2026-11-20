# **SUMOnix: expanded strategic roadmap**

## **From semantic NixOS to a verified, self-managing infrastructure control plane**

The larger vision should be substantially more ambitious than the current metavisor roadmap. I would not position SUMOnix merely as a NixOS configuration validator, runtime monitor, or Datalog engine.

**SUMOnix should become a semantic control plane that understands infrastructure, knows what evidence supports its understanding, reasons about desired versus actual state, diagnoses problems, plans changes, verifies those plans, and eventually executes approved changes across multiple infrastructure substrates.**

NixOS is the first substrate, not the final boundary.

The architectural direction is already present in the repository's README, TODO5, and `TODO2.ultimate.md`. The problem is that the ambitions are distributed among several roadmaps, some capabilities are isolated experiments, and some of the longer-term ideas need a more explicit dependency order.&#x20;

[image](https://www.google.com/s2/favicons?domain=https://github.com\&sz=32)

autonull/sumonix: NixOS + SUMO · GitHub+2



My proposed roadmap consolidates these ideas into one program with five governing principles:

1. **One semantic model:** configuration, observations, policies, goals, plans, proofs, and history use a common representation.
2. **One trusted reasoning kernel:** all decisions have explainable derivations and independently verifiable proofs.
3. **One epistemic model:** the system distinguishes true, false, unknown, stale, incomplete, inferred, declared, and observed.
4. **One transition model:** changes are proposed as verifiable, bounded, reversible plans rather than arbitrary commands.
5. **One constitutional boundary:** intelligence and autonomy can grow without giving the system authority to bypass its own safety constraints.

# **Part I — Strategic architecture**

## **1. The actual end product**

The target architecture should have ten cooperating subsystems.

**1. Intent and goals**

Human objectives, declarative goals, constraints, preferences

**2. Constitutional kernel**

Immutable safety constraints, authorization boundaries, proof requirements

**3. Semantic world model**

SUMO ontology, infrastructure entities, configuration, desired state, relationships

**4. Observation**

Runtime, hardware, cryptographic, external evidence

**5. Reasoning**

Logic, temporal, causal, constraints, proofs

**6. Diagnosis and transition planning**

Counterfactuals, repair candidates, transition bundles, compensation

**7. Proof, simulation and governance gate**

Independent checking, feasibility, risk classification, human authorization

**8. Typed execution adapters**

NixOS, systemd, storage, network, databases, cloud, hardware

**9. Verification and audit**

Post-state evidence, proof artifacts, immutable transition history

**10. Case memory and controlled learning**

Past outcomes, diagnosis quality, planning improvements, governed evolution

This architecture is deliberately broader than the current NixOS metavisor, but it extends the same fundamental idea rather than introducing an unrelated second product.&#x20;

[image](https://www.google.com/s2/favicons?domain=https://github.com\&sz=32)

GitHub+2



## **2. Three execution scopes**

One of the strongest decisions in TODO5 is to separate fact volume and execution frequency. Preserve and expand this distinction.

| Scope         | Approximate scale | Responsibilities                                                                     |
| ------------- | ----------------- | ------------------------------------------------------------------------------------ |
| Configuration | 10²–10³ facts     | NixOS evaluation, option lifting, configuration contradictions, build gates          |
| Runtime       | 10²–10³ facts     | Units, listeners, identities, permissions, live drift, operational policies          |
| Audit         | 10⁴–10⁶+ facts    | Package closures, vulnerabilities, licenses, dependencies, compliance, change impact |

The audit scope should eventually accommodate very large repositories and infrastructure descriptions without making the resident runtime engine carry that cost.

All three scopes should use the same semantic schema and proof conventions, although they may use different evaluation strategies.

**Architectural rule:** optimize data selection and scope boundaries before replacing the reasoning engine.&#x20;

[image](https://www.google.com/s2/favicons?domain=https://github.com\&sz=32)

GitHub+1



# **Part II — The prioritized development roadmap**

I would use five priority levels.

-

  P0

  &#x20;Necessary foundations and completion of the current NixOS product.


-

  P1

  &#x20;Major capabilities that establish a genuinely useful semantic infrastructure platform.


-

  P2

  &#x20;Advanced reasoning, automation, and integrations.


-

  P3

  &#x20;Broader operational intelligence and cross-substrate capabilities.


-

  &#x20;P4&#x20;

  &#x20;Long-term research and self-evolution.



These are dependencies and development priorities, not calendar commitments.

# **P0 — Complete and strengthen the NixOS semantic platform**

## **3. Complete&#x20;**`system.kif`**&#x20;and the operational policy model**



P0

**Immediate engineering priority**



The current five-rule system policy is a sensible initial foundation. Two rules are already demonstrated: unexpected network exposure and runtime service drift. The next work should complete the remaining rules rather than immediately expanding to dozens of unrelated policies.&#x20;

[image](https://www.google.com/s2/favicons?domain=https://github.com\&sz=32)

GitHub+1



| Rule | Policy                                                   | Required evidence                                      |
| ---- | -------------------------------------------------------- | ------------------------------------------------------ |
| R1   | Wildcard listener without appropriate firewall allowance | Listener, address, port, firewall                      |
| R2   | Expected active service is not observed active           | Declared state, systemd state, complete fresh snapshot |
| R3   | Service runs as an unauthorized user                     | Declared user, observed unit/process identity          |
| R4   | Declared secret path is world-readable                   | Path, owner, permissions, ACL                          |
| R5   | Software closure contains a prohibited license           | Closure, derivation, license metadata                  |

### **Extend beyond those five rules**

After the initial rules work reliably, build a proper security and operational policy library.

**Service security**

- Unauthorized root execution.
- Unexpected Linux capabilities.
- Missing `NoNewPrivileges`.
- Weak systemd sandboxing.
- Unexpected supplementary groups.
- Services using writable paths outside their declarations.
- Unexpected service dependencies.
- Insecure environment-variable handling.

**Network security**

- Undeclared exposed services.
- Public administrative interfaces.
- Firewall rules that are redundant or shadowed.
- Inconsistent IPv4 and IPv6 exposure.
- Unexpected outbound network dependencies.
- Services exposed through socket activation.
- Network policy inconsistent with service requirements.

**Filesystem and identity**

- Unsafe file ownership.
- Excessive permissions.
- Secret paths exposed through symlinks or mounts.
- Unexpected privileged users.
- Unrestricted writable directories.
- Unexpected changes to protected paths.

**Operational health**

- Failed or repeatedly restarted units.
- Services with unresolved dependencies.
- Required services that are masked or disabled.
- Missing backups.
- Expired certificates.
- Insufficient storage.
- Resource limits inconsistent with workload needs.

Each policy must have a typed declaration, explicit evidence requirements, a meaningful unknown state, an explanation, and a testable proof.

Do not make `system.kif` a collection of ad hoc shell checks. It should be a genuine, reusable ontology and policy pack.

## **4. Complete the evidence and identity model**

P0

This deserves its own milestone. The semantic model will only be trustworthy if it knows where its facts originated and what they actually establish.

Every fact should be capable of carrying:

| Attribute             | Meaning                                             |
| --------------------- | --------------------------------------------------- |
| Subject and predicate | The proposition                                     |
| Source class          | Declared, inferred, observed, fixture, derived      |
| Source identity       | Exporter, configuration, policy or artifact         |
| Observation time      | When evidence was collected                         |
| Expiration            | When evidence becomes stale                         |
| Snapshot ID           | Which consistent observation produced it            |
| Content hash          | Evidence integrity and identity                     |
| Completeness          | Which predicates or collections were fully observed |
| Confidence/trust      | What the system is justified in believing           |
| Provenance            | The inference chain or original evidence            |

### **Important refinements**

1. Represent completeness per observation domain rather than relying only on one global completeness flag.
2. Distinguish absent facts from facts that were not successfully collected.
3. Prevent facts from different snapshots from being accidentally combined into false conclusions.
4. Account for timestamps, clock skew, and event ordering.
5. Preserve the distinction between an inferred default and an explicit NixOS declaration.
6. Record conflicts between independent evidence sources.

One particularly important limitation already acknowledged in TODO5 must remain explicit: an independent checker can verify the reasoning, but cannot independently prove that an exporter reported reality correctly.

Therefore, **inference trust and observation trust must be separate concepts throughout SUMOnix.**&#x20;

[image](https://www.google.com/s2/favicons?domain=https://github.com\&sz=32)

GitHub+2



## **5. Strengthen NixOS configuration semantics**

P0

The existing pure `nixosConfig → KIF` lifter is an excellent foundation. Extend it into a broad, systematically maintained NixOS semantic model.

Cover:

- Services and systemd units.
- Network interfaces and firewall configuration.
- Users, groups, and privileges.
- Filesystems, mounts, and storage.
- Packages and system profiles.
- Systemd hardening.
- Secrets-management declarations.
- Containers and virtual machines.
- Boot and kernel configuration.
- Hardware configuration.
- Scheduled jobs and timers.
- Resource limits.
- Logging and backup configuration.

### **Identity deserves particular attention**

Support:

- Standard service aliases.
- Custom systemd unit names.
- Templated units.
- User services.
- Transient services.
- Socket-activated services.
- Package-to-derivation relationships.
- Store-path identity where it can be safely obtained outside restricted evaluation.

The current implementation deliberately rejects ambiguous joins instead of guessing. Preserve that behavior.

Also refine the meaning of declared state. An enabled service, an expected active service, a transient service, and a socket-activated service are not equivalent concepts.

The model should express these differences instead of allowing a simplistic `enabled ⇒ should currently be active` assumption.

## **6. Strengthen the kernel and proof contract**

P0

The parser, ontology, declaration-driven synthesis, ingestion, naive Datalog evaluator, proof exporter, independent checker, policy gates, and relaxation menu should remain the trusted core.&#x20;

[image](https://www.google.com/s2/favicons?domain=https://github.com\&sz=32)

autonull/sumonix: NixOS + SUMO · GitHub+1



I would make the following architectural work explicit:

- Versioned intermediate representation.
- Typed predicate signatures.
- Domain and range validation.
- Stable fact and rule identities.
- Explicit rule metadata and dependencies.
- Versioned proof certificate format.
- Proof DAG support for shared subproofs.
- Deterministic serialization.
- Defined behavior for duplicate facts and contradictory evidence.
- Resource and derivation limits.
- Consistent diagnostics for unsupported logic.
- An explicit registry of supported syntax and semantics.

Every new reasoning capability must satisfy the same contract:

1. The engine can derive it.
2. The exporter can represent it.
3. The independent checker can verify it.
4. Tampering causes rejection.
5. Unsupported cases have an explicit rejection reason.

This is a permanent architectural obligation, not a one-time milestone.

# **P1 — Build a real semantic infrastructure knowledge base**

## **7. Full package and dependency intelligence**

P1

The current 60-package capability atlas is useful for demonstrations. The next meaningful capability is reasoning over actual NixOS system closures and eventually larger nixpkgs populations.

Implement the full B1 Nixpkgs Ontology bootstrap.

Ingest:

- Package identity.
- Version.
- Derivation and output relationships.
- Direct dependencies.
- Transitive closure.
- Provided capabilities.
- Build inputs.
- Runtime dependencies.
- Maintainers and metadata.
- Licenses.
- Platforms.
- Vulnerability references.

This unlocks questions such as:

- What capabilities become available because this service is installed?
- Which packages introduce network functionality?
- Which installed packages depend on vulnerable libraries?
- Which packages can be replaced with equivalent alternatives?
- What capabilities disappear if a package is removed?
- Which dependencies are unnecessary for the current system goals?

Keep package-closure reasoning in audit scope, not the resident metavisor loop.

## **8. Vulnerability and software-supply-chain intelligence**

P1

This is one of the highest-value extensions.

Implement the B6 Lockfile + OSV/NVD pathway.

Support:

- `flake.lock`.
- `Cargo.lock`.
- `package-lock.json`.
- Other common package lock formats.
- Transitive dependency resolution.
- OSV vulnerability data.
- NVD advisory information.
- A pinned, reproducible advisory snapshot.
- A normalized vulnerability ontology.

### **Critical prerequisite: version semantics**

Before presenting vulnerability findings as authoritative, add correct, domain-aware version comparison.

This includes:

- Version ranges.
- Inclusive and exclusive bounds.
- Version ordering.
- Prerelease versions.
- Epochs and distribution-specific version semantics.
- Affected and unaffected ranges.
- Fixed versions.
- Version constraints inherited through package metadata.

A simplistic string comparison will produce incorrect security conclusions.

The target experience:

`sumo audit` → vulnerable dependency → affected package → path through the dependency graph → policy violation → proof → possible remediation.

Also include SBOM generation and ingestion, ideally using SPDX-compatible metadata.

## **9. License and compliance intelligence**

P1

Implement B7 License Oracle.

Support:

- SPDX identifiers.
- SPDX license expressions.
- AND/OR license combinations.
- Package-level license provenance.
- Organization-defined allow/deny rules.
- Explicit exceptions.
- License inheritance and dependency closure.
- Compliance summaries.

Eventually, the user should be able to ask:

- Can this system ship under this licensing policy?
- Which dependency introduces the unacceptable license?
- Which alternatives preserve the required functionality?
- Does the proposed package substitution satisfy the policy?

This provides a much stronger foundation for compliance receipts later.

## **10. Policy packs and semantic package selection**

P1

Implement B2, B21, and B25 as a connected system.

Policy packs should be independently versioned, composable, and pinned as Nix inputs.

Examples:

- Enterprise security.
- Privacy.
- Licensing.
- Hardware hardening.
- Server baseline.
- Development workstation.
- Data protection.
- Network exposure.

Add a semantic package selector.

Instead of requiring a package name, allow a user to specify capabilities and constraints:

- Must provide an HTTPS server.
- Must support the target architecture.
- Must not introduce a forbidden license.
- Must not introduce a known vulnerable dependency.
- Prefer minimal dependency closure.

The engine should produce candidate packages with proofs explaining why each qualifies or fails.

# **P1–P2 — Mature the reasoning engine**

## **11. Integrate existing reasoning extensions in dependency order**



P1

P2



The README already lists several extension modules and tests, including builtins, aggregates, disjunction, well-founded semantics, existentials, congruence, soft rules, and temporal reasoning.

The goal should not be to recreate these islands. It should be to integrate the required capabilities coherently across ingestion, evaluation, proof generation, independent checking, and CLI use.&#x20;

[image](https://www.google.com/s2/favicons?domain=https://github.com\&sz=32)

autonull/sumonix: NixOS + SUMO · GitHub+2



My recommended ordering:

| Order | Capability                    | Why it matters                                            |
| ----- | ----------------------------- | --------------------------------------------------------- |
| 1     | Builtins and arithmetic       | Version ranges, numeric and set comparisons               |
| 2     | Aggregates                    | Counts, thresholds, cardinality policies                  |
| 3     | Disjunctive consequents       | More expressive policies and ontology rules               |
| 4     | Bounded existential reasoning | Witness-producing derivations                             |
| 5     | Well-founded negation         | Sound handling of genuinely partial evidence              |
| 6     | Congruence closure            | Reasoning across equivalent identities                    |
| 7     | Truth maintenance             | Retractions and updates without rebuilding everything     |
| 8     | Temporal reasoning            | Events, intervals, duration, sequences                    |
| 9     | Soft rules and MaxSAT         | Policy preferences and optimal alternatives               |
| 10    | Abduction and minimal repair  | Finding missing conditions that explain a desired outcome |

### **11.1 Builtins and aggregates**

Create a typed builtin registry.

Initial functions:

- Numeric comparisons.
- Version comparisons.
- String and identifier normalization.
- Set membership and subset relations.
- Set cardinality.
- Count and threshold aggregates.
- Time comparisons.
- Bounded arithmetic.
- Package-version interval checks.

Every builtin needs a precisely defined semantic contract and a checker implementation.

### **11.2 Disjunction and existential reasoning**

Support disjunctive consequences through explicit branch evaluation and proof branches.

Add bounded existential consequents using finite domains and recorded witnesses.

Do not silently approximate unrestricted existential reasoning.

### **11.3 Well-founded semantics**

Use WFS when incomplete observations or genuinely partial logical knowledge make the existing complete-observation approach insufficient.

Preserve the critical distinction:

- Known true.
- Known false.
- Unknown because evidence is incomplete.
- Unknown because the reasoning rules do not establish either polarity.

WFS should not be enabled indiscriminately merely because it is more expressive.

### **11.4 Equality and congruence**

Expand identity handling beyond explicit aliases.

Support:

- Equivalence closure.
- Substitution across relations.
- Function-term congruence.
- Derived identity paths.
- Explanation of why two independently named resources are considered equivalent.

Knuth–Bendix completion belongs in bounded offline tooling, not ordinary Nix evaluation.

### **11.5 Truth maintenance and incremental evaluation**

The system will eventually need to retract derived conclusions as evidence changes.

Implement:

- Dependency tracking.
- Derived-fact retraction.
- Incremental invalidation.
- Snapshot-specific derivations.
- Incremental proof updates.
- Efficient refresh behavior.

This becomes important when the event-driven observer arrives.

### **11.6 Temporal, soft and abductive reasoning**

Add temporal relations for:

- Before and after.
- Duration.
- Event sequences.
- Time windows.
- Fact expiration.
- Recovery intervals.
- Repeated failures.

Then add:

- Weighted rules.
- Preference optimization.
- Bounded MaxSAT.
- Minimal failing sets.
- Minimal hitting-set repair.
- Abductive explanation.

This unlocks a significant change: SUMOnix can progress from explaining *why something is wrong* to finding *what smallest set of changes would make it right*.

### **11.7 Performance backends**

Treat semi-naive evaluation, parallel evaluation, and Soufflé as backends to consider for large audit workloads.

Before adopting one:

1. Measure the full pipeline.
2. Optimize fact selection.
3. Optimize joins and indexing.
4. Compare incremental recomputation with full recomputation.
5. Only then introduce another backend.

The Nix kernel remains the semantic oracle. Any alternative backend must agree on results and preserve the proof contract.

Do not rewrite the kernel in Rust simply because the long-term vision mentions Rust. A native daemon or accelerated backend can be introduced later if measurements establish a real need.

[image](https://www.google.com/s2/favicons?domain=https://github.com\&sz=32)

GitHub+2

# **P2 — Make verified repair a general planning system**

## **12. Move from individual repairs to complete transition plans**

P2

The current repair implementation proposes one-option edits and verifies them by re-lifting the patched configuration and re-running the policy gate.

Preserve that verification mechanism. It is one of the most important differentiators in the project.&#x20;

[image](https://www.google.com/s2/favicons?domain=https://github.com\&sz=32)

GitHub+1



Then generalize the repair model.

### **Repair capabilities**

- Multiple coordinated option changes.
- Dependency-aware edits.
- Conflict detection.
- Minimal repair sets.
- Ranked alternatives.
- Cost and risk estimates.
- Downtime estimates.
- Reversibility classification.
- Confidence and evidence sufficiency.
- Explicit rejection of ungrounded proposals.

A repair should never be considered successful merely because it changes the facts in memory. It must produce a new real configuration, be lifted again, and pass the relevant gates.

## **13. Introduce the Transition Bundle**

P2

This is the conceptual bridge from a configuration repair tool to an infrastructure control plane.

A transition bundle represents an entire change operation.

Its schema should include:

| Component             | Purpose                                  |
| --------------------- | ---------------------------------------- |
| Goal                  | What should become true                  |
| Preconditions         | What must already be established         |
| Initial state         | The evidence used to produce the plan    |
| Configuration changes | NixOS or other declarative changes       |
| Data changes          | Migrations, replication, snapshots       |
| Workload changes      | Restart, stop, start, drain              |
| Network changes       | Firewall and connectivity                |
| Hardware changes      | Firmware or physical actions             |
| Proofs                | Policy, feasibility, and safety evidence |
| Simulation            | Expected result and failure scenarios    |
| Approvals             | Required human authorization             |
| Compensation          | Rollback or recovery actions             |
| Verification          | How actual success will be established   |
| Audit                 | Complete transition history              |

The bundle should be immutable once authorized. A changed precondition or changed input snapshot should invalidate its authorization and require reconsideration.

### **Why this matters**

Consider the goal:

*Provide a secure HTTPS service.*

That may require:

1. Selecting a package.
2. Enabling a service.
3. Configuring TLS.
4. Configuring firewall rules.
5. Creating a secret reference.
6. Adjusting service permissions.
7. Starting or reloading services.
8. Testing reachability.
9. Checking certificate validity.
10. Verifying the final policy state.

That is not one Nix option edit. It is a multi-resource transition.

This is the proper abstraction for SUMOnix's eventual planning and execution capabilities.&#x20;

[image](https://www.google.com/s2/favicons?domain=https://github.com\&sz=32)

GitHub+1



## **14. Build the execution and authorization model**



P2

P3



Execution should be a separate subsystem. The reasoner never receives direct operating-system privileges.

Build in the following stages:

| Level | Capability                                           | Authorization                  |
| ----- | ---------------------------------------------------- | ------------------------------ |
| L0    | Read, reason, explain                                | Automatic                      |
| L1    | Construct and verify proposals                       | Automatic                      |
| L2    | Execute allow-listed, low-risk reversible operations | Strictly bounded authorization |
| L3    | Security-sensitive and stateful changes              | Explicit human approval        |
| L4    | Destructive or irreversible operations               | Explicit human confirmation    |

The first execution adapter should be NixOS.

Next, add systemd operations, such as restart, reload, and drain, under carefully defined preconditions.

The executor must accept typed flows, not arbitrary shell commands.

Eventually introduce adapters for:

- NixOS.
- systemd.
- Filesystems and storage.
- Network configuration.
- Databases.
- Containers.
- Kubernetes.
- Cloud APIs.
- Hardware management.

Each adapter should implement the same essential lifecycle:

`inspect → validate → simulate → execute → compensate → verify`

The execution subsystem also needs idempotency, action expiration, capability scoping, replay protection, event logging, and failure recovery.

# **P2 — Build out the integration ecosystem**

## **15. Consolidated bootstrap portfolio**

The README's B1–B28 list is valuable and should not be discarded. However, it should become a structured portfolio, not a flat list of equally important features. There are overlaps, particularly B8 and B23, and several bootstraps depend on the same underlying importer or ontology work.&#x20;

[image](https://www.google.com/s2/favicons?domain=https://github.com\&sz=32)

autonull/sumonix: NixOS + SUMO · GitHub+1



Here is how I would preserve the full list while imposing a more useful order.

### **Tier A — Native Nix and structured data**

P1

| ID  | Bootstrap                 | Purpose                                                        |
| --- | ------------------------- | -------------------------------------------------------------- |
| B1  | Nixpkgs Ontology          | Full package, dependency, capability, and license intelligence |
| B2  | Epistemic Flakes          | Policy packs as reproducible flake inputs                      |
| B3  | JSON/YAML to KIF          | General structured-data ingestion                              |
| B14 | Environment Validator     | Validate environment configuration                             |
| B15 | Git Hygiene               | Find secret-like and prohibited tracked files                  |
| B16 | Semantic Grep             | Search repository content by semantic concepts                 |
| B17 | Ontology Task Runner      | Derive and execute task dependency plans                       |
| B18 | Change Impact             | Identify consequences of changes                               |
| B21 | Semantic Package Selector | Choose packages by capabilities and constraints                |
| B24 | Config Contradiction      | Detect contradictions in NixOS module configuration            |
| B25 | Policy-as-Flakes          | Import and compose independently maintained policies           |
| B26 | SUMO Flake Checks         | Make semantic assertions available through the flake interface |
| B27 | SUMO Assert               | Add declarative semantic assertions inside Nix                 |

B24 has substantial implementation already in the metavisor. This phase should generalize and deepen that work.

B3 is especially important: a robust declarative JSON/YAML mapping system becomes a shared foundation for many later integrations.

### **Tier B — Software and supply-chain intelligence**

P1

| ID  | Bootstrap            | Purpose                            |
| --- | -------------------- | ---------------------------------- |
| B6  | Lockfile + OSV/NVD   | Vulnerability analysis             |
| B7  | License Oracle       | License and compliance reasoning   |
| B1  | Full Nixpkgs closure | Dependency and capability analysis |
| B19 | Compliance Receipt   | Formal audit evidence              |
| B20 | Proof Badges         | Human-readable proof-linked status |

B19 and B20 become substantially more useful once there is a stable evidence and receipt format.

### **Tier C — Infrastructure security**

P2

| ID  | Bootstrap                          | Purpose                                                    |
| --- | ---------------------------------- | ---------------------------------------------------------- |
| B4  | Terraform Plan                     | Infrastructure-as-code analysis                            |
| B5  | Kubernetes / Docker Compose        | Workload and container semantics                           |
| B11 | Firewall / Security Group Analyzer | Network access and rule analysis                           |
| B12 | RBAC / ABAC Explainer              | Identity, privilege, and resource authorization            |
| B22 | Crypto Epistemology                | Reasoning about hardware, network, and cryptographic state |

B11 and B12 have especially high value because they extend the NixOS security model naturally.

B4 and B5 should come after the common resource and identity schemas are established.

### **Tier D — Contracts, data and development workflows**



P2

P3



| ID  | Bootstrap             | Purpose                                            |
| --- | --------------------- | -------------------------------------------------- |
| B8  | OpenAPI / JSON Schema | API structure and compatibility                    |
| B23 | API Evolution         | Versioned client/server contract analysis          |
| B9  | SQL / dbt Lineage     | Data ownership and sensitive-data flow             |
| B10 | Git + CODEOWNERS      | Repository ownership and review requirements       |
| B13 | Pipeline Analyzer     | Static analysis of workflow definitions            |
| B28 | Why-does-this-exist   | Documentation derived from semantic resource facts |

B8 and B23 should be consolidated into one API contract and evolution subsystem.

B13 refers to analysis of pipeline definitions as an input format. That is distinct from building or modifying SUMOnix's own CI infrastructure.

### **Tier E — Enterprise and ecosystem surface**

P3

- B19: Signed compliance receipts.
- B20: Proof-linked badges.
- B25: Third-party policy-pack ecosystem.
- B28: Generated semantic documentation.
- Stable JSON interfaces and external integrations.
- Importable and exportable semantic datasets.

The key principle is that each bootstrap is a small package composed of a converter, typed ontology, policy pack, and usable semantic query.

Do not implement 28 different bespoke reasoning systems.

# **P2–P3 — Advanced observation and epistemic intelligence**

## **16. Evolve the observer beyond periodic shell commands**

P2

The existing observer is deliberately simple and uses systemd, `/proc`, `ss`, and filesystem inspection. That is appropriate for the current architecture.

The next generation should add richer, event-driven observation.

### **Stage A: complete OS visibility**

- systemd D-Bus subscriptions.
- Unit lifecycle notifications.
- Property changes.
- Process ownership and identity.
- Socket ownership.
- Filesystem ownership and permissions.
- Mount changes.
- Journal events.
- Network state changes.

### **Stage B: kernel-level observation**

Investigate eBPF for:

- Process starts and exits.
- Socket creation and binding.
- Network drops.
- OOM kills.
- Filesystem anomalies.
- Unexpected privileged operations.
- Runtime behavior that contradicts declarations.

### **Stage C: event and telemetry storage**

Retain the append-only event history while introducing a more useful indexed telemetry store.

Evaluate SQLite for:

- Snapshot indexing.
- Time-series evidence.
- Event correlation.
- Query history.
- Incremental fact invalidation.
- Replay checkpoints.

Do not turn the telemetry database into a second source of semantic truth. It is a storage and retrieval subsystem supporting the semantic model.

## **17. Build a real epistemic reasoning layer**



P2

P3



This goes further than simple fact freshness.

The system eventually needs to reason about:

- Whether an observer is trustworthy.
- Whether two sensors disagree.
- Whether data is incomplete.
- Whether an observation is stale.
- Whether an observation is possible but improbable.
- Whether evidence is independent or correlated.
- Whether an exporter could be compromised.
- Whether the system can establish the truth of a proposition at all.

For example:

- systemd reports a process running.
- eBPF reports no corresponding process activity.
- A hardware controller reports the underlying network interface is down.

The correct response is not automatically to change the firewall. It is to identify an evidence conflict and downgrade the affected conclusions until the underlying issue is resolved.

### **Cryptographic evidence**

Eventually integrate:

- TPM.
- Measured boot.
- Kernel and configuration measurements.
- Signed observer attestations.
- Signed transition bundles.
- Tamper-evident event history.
- Hardware attestation.

This is a natural extension of the trust boundary already described in TODO5.&#x20;

[image](https://www.google.com/s2/favicons?domain=https://github.com\&sz=32)

GitHub+2



# **P3 — Temporal, causal and operational intelligence**

## **18. Build the causal diagnosis engine**

P3

Temporal reasoning tells SUMOnix what happened and when. Causal reasoning helps identify why.

Example:

- HTTP service became unavailable.
- The process exited.
- An OOM kill occurred shortly beforehand.
- Memory pressure increased.
- The firewall did not change.

The system should identify memory exhaustion as a plausible cause, distinguish it from alternative explanations, and support the diagnosis with provenance.

Implement progressively:

1. Event correlation.
2. Dependency-aware fault propagation.
3. Temporal ordering.
4. Root-cause hypothesis generation.
5. Counterfactual analysis.
6. Causal confidence and competing explanations.
7. Diagnosis-directed repair proposals.

Use bounded SAT/SMT solving for problems that are naturally constraint-oriented:

- Port conflicts.
- Resource allocation.
- Dependency ordering.
- Storage capacity.
- Placement.
- Network reachability.

Do not attempt to replace ordinary Datalog evaluation with unrestricted theorem proving.

## **19. Introduce digital-twin simulation**

P3

This deserves a dedicated subsystem, not merely a few integration tests.

Use `microvm.nix` or the NixOS test driver to define reproducible infrastructure scenarios.

A scenario should describe:

- Initial configuration.
- Runtime state.
- Events.
- Fault injection.
- Desired goals.
- Expected behavior.
- Allowed actions.
- Verification requirements.

Build scenarios such as:

- Service failure.
- Rogue network listener.
- Firewall misconfiguration.
- Disk pressure.
- Storage failure.
- Credential expiration.
- Package vulnerability.
- Broken dependency.
- Network partition.
- Observer failure.
- Conflicting evidence.

The simulator should support deterministic telemetry replay and policy/repair evaluation.

It becomes especially important before enabling automated execution: the system should be able to explain what it expects a transition to do and how it behaves when that expectation is wrong.

## **20. Add control theory and safe self-healing**

P3

Automated repair introduces a new class of risk: oscillation.

For example:

1. SUMOnix sees memory pressure.
2. It increases a memory limit.
3. The system reallocates memory.
4. SUMOnix sees a new pressure pattern.
5. It changes the limit again.
6. The system oscillates.

A proper operational controller needs:

- Cooldowns.
- Hysteresis.
- Rate limits.
- Stability analysis.
- Resource budgets.
- Action deduplication.
- Repeated-failure detection.
- Recovery windows.
- Confidence thresholds.
- Rollback conditions.

Only introduce self-tuning once these safeguards are established.

# **P3 — Human intent, interfaces and organizational semantics**

## **21. Add a formal intent layer**

P3

This is where LLMs become useful without making SUMOnix dependent on them.

A user should be able to express:

> Configure a secure public web service with automatic certificate renewal and no exposed administrative access.

The intent subsystem converts that into a typed goal with constraints and preferences.

For example:

- Require HTTPS capability.
- Require valid certificate.
- Require firewall policy.
- Forbid public SSH.
- Require appropriate service isolation.
- Require rollback capability.
- Prefer minimal package closure.

The formalizer should:

1. Identify ambiguity.
2. Request missing parameters.
3. Translate intent into a versioned formal schema.
4. Display its interpretation.
5. Allow human correction.
6. Pass only the approved formal goal to the reasoning kernel.

**Hard boundary:** an LLM may suggest goals, explain findings, rank candidate plans, and propose ontology changes. It must not create machine observations, authorize execution, decide policy outcomes, or generate arbitrary commands that reach the executor.

This is consistent with the governance model in `TODO2.ultimate.md`.&#x20;

[image](https://www.google.com/s2/favicons?domain=https://github.com\&sz=32)

GitHub+1



## **22. Evolve the operator interface**

P2

The project already has CLI commands, JSON output, a dashboard/TUI, and the metavisor status surface.

Build from these rather than creating an unrelated interface.

### **CLI**

The eventual command model should cover:

- Status and health.
- Query and explanation.
- Evidence inspection.
- Drift history.
- Policy evaluation.
- Goal management.
- Repair proposals.
- Transition planning.
- Simulation.
- Authorization.
- Execution.
- Verification.
- Audit.

### **TUI**

The TUI should become an interactive semantic operations console.

Useful views:

- Infrastructure topology.
- Service dependencies.
- Runtime drift.
- Policy violations.
- Evidence timeline.
- Proof tree.
- Package and vulnerability graph.
- Capabilities.
- Repair alternatives.
- Transition status.
- Audit history.

An especially useful feature would be navigating from a high-level policy violation down to its observation, originating configuration option, derivation rule, and suggested remediation.

### **API**

An eventual API should expose the same underlying semantic operations with stable, typed schemas.

Keep authentication and authorization boundaries explicit if it becomes remotely accessible.

# **P3 — Stateful transitions and resource management**

## **23. Add dataflow**

P3

This is a major expansion beyond conventional configuration management.

The system should eventually understand stateful operations:

- Database migrations.
- Storage snapshots.
- Volume replication.
- Restore.
- Schema changes.
- Data movement.
- Backup verification.
- Checksum validation.
- Data retention.
- Encryption transitions.

A dataflow must be:

- Resumable.
- Checkpointed.
- Idempotent where possible.
- Auditable.
- Verified by actual post-operation evidence.
- Accompanied by a defined compensation strategy.

For example, a database migration should not be considered successful merely because the database process restarted. SUMOnix must establish that the expected schema exists and that the data has not been corrupted or lost.

This should come after transition bundles, proofs, snapshots, and compensation semantics are well established.

# **P3–P4 — Hardware, fleet and distributed infrastructure**

## **24. Hardware intelligence**



P3

P4



Expand observation and eventually execution to cover:

- SMART disk status.
- Temperature.
- Fan state.
- Power state.
- NIC link state.
- Firmware versions.
- BMC state.
- IPMI.
- Redfish.
- TPM measurements.

Reason about hardware faults as distinct from software configuration problems.

Hardware control should require much stronger authorization than ordinary NixOS changes.

Never make irreversible physical actions autonomous by default.

## **25. Distributed infrastructure and fleet management**

P4

Once the single-host model is mature, generalize it to multiple hosts.

The semantic world model should eventually understand:

- Nodes.
- Networks.
- Clusters.
- Service placement.
- Storage relationships.
- Replication.
- Shared dependencies.
- Cross-node capabilities.
- Administrative boundaries.
- Failure domains.

New distributed reasoning capabilities:

- Fleet-wide policy evaluation.
- Distributed goal decomposition.
- Placement constraints.
- Resource allocation.
- Failover.
- Quorum.
- Leases.
- Cluster consistency.
- Multi-node audit history.

The execution model should handle a goal spanning several machines without assuming that all changes can be committed atomically.

Start with read-only inventory and cross-node reasoning. Distributed actuation is a later capability.

This is the point at which Kubernetes, Terraform, cloud, and other adapters become especially valuable.

# **P4 — Self-reference, learning and controlled evolution**

## **26. Make SUMOnix understand itself**

P4

This is one of the most interesting long-term directions and deserves its own development program.

Represent SUMOnix's own repository and architecture semantically.

Model:

- Source files.
- Modules.
- Functions.
- Rules.
- Ontology definitions.
- Dependencies.
- Test coverage.
- Proof-checker responsibilities.
- Documentation.
- Architecture constraints.
- Performance characteristics.
- Maintenance ownership.

Then enable:

- Semantic code search.
- Change-impact analysis.
- Dependency explanations.
- Architecture documentation generation.
- Detection of unused logic.
- Detection of missing tests.
- Identification of unsupported proof paths.
- Semantic consistency checks between design and implementation.

This connects B10, B16, B18, and B28.

## **27. Controlled learning**

P4

Build case memory for operational outcomes.

A case may contain:

- Initial condition.
- Goal.
- Evidence.
- Diagnosis.
- Candidate plans.
- Selected transition.
- Execution outcome.
- Verification result.
- Root cause.
- Human feedback.

Learning may improve:

- Repair ranking.
- Diagnosis ranking.
- Plan selection.
- Cost estimates.
- Risk classification proposals.
- Clarification questions.

It must not silently change formal facts, policies, or proofs.

## **28. Governed self-development**

P4

The eventual system should be capable of proposing improvements to its own reasoning engine, ontology, and operational policies.

Example:

1. Detect poor reasoning performance on a workload.
2. Analyze evaluation traces.
3. Generate a performance hypothesis.
4. Propose a source change.
5. Produce accompanying tests.
6. Measure expected improvement.
7. Evaluate semantic equivalence.
8. Generate a change proposal.
9. Require appropriate human approval.
10. Apply the approved change through the ordinary governed transition model.

The constitutional rules must remain outside the system's autonomous modification authority.

This also applies to the ontology, policy engine, proof checker, and execution boundaries.

# **Part III — Permanent engineering requirements**

These are not optional features. They are conditions for everything else.

## **29. The SUMOnix constitution**

Write down a permanent set of invariants and make them machine-readable.

I would start with:

| Invariant                   | Requirement                                                           |
| --------------------------- | --------------------------------------------------------------------- |
| Evidence honesty            | Never claim facts were observed when they were inferred or fabricated |
| Epistemic honesty           | Missing or stale evidence cannot establish a negative claim           |
| Proof integrity             | Every supported conclusion has reproducible provenance                |
| Checker independence        | The checker does not trust the engine's reasoning implementation      |
| Completeness                | Unsupported logic is rejected with an explanation                     |
| Reproducibility             | Same inputs and versions produce deterministic artifacts              |
| Least privilege             | Reasoning does not have direct execution authority                    |
| Authorization               | Actions require appropriate scoped authority                          |
| Rollback                    | Reversibility is explicit; capability cannot be silently removed      |
| Audit                       | Transitions and approvals are recorded                                |
| LLM containment             | Generated text cannot become machine evidence or authorization        |
| Constitutional immutability | The system cannot autonomously weaken its safety rules                |

The constitutional model in the Ω document is the right long-term direction. Establish its schema early, then strengthen signatures and external governance as the execution architecture evolves.&#x20;

[image](https://www.google.com/s2/favicons?domain=https://github.com\&sz=32)

GitHub+1



## **30. Permanent testing and verification model**

Testing remains essential even though CI and soak work are outside this roadmap.

Every subsystem should have the appropriate local validation strategy.

- Unit tests for individual transformations and rules.
- Property tests for reasoning invariants.
- Semantic oracle tests for ontology correctness.
- Proof mutation tests for independent verification.
- Snapshot and replay tests for observation semantics.
- NixOS test-driver scenarios for real system behavior.
- Fault-injection scenarios for failure handling.
- Transition tests for preconditions and compensation.
- Constitutional tests attempting to bypass authorization.

Important properties include:

- Removing a source fact retracts dependent conclusions.
- Incomplete observations cannot produce a false clean result.
- No unsupported proof step is accepted.
- A changed configuration invalidates stale repair verification.
- A transition cannot execute with altered or expired preconditions.
- An unapproved high-risk action cannot reach an execution adapter.
- Contradictory observations cannot silently resolve to a convenient answer.

# **Part IV — Consolidated execution order**

The entire roadmap should be organized as the following development sequence.

## **SUMOnix master milestones**

1. **M0 — Semantic and evidence foundations**

   P0

   Stabilize fact schemas, source provenance, completeness, identity, temporal validity, and proof contracts.

2. **M1 — Complete NixOS operational model**

   P0

   Complete rules 3–4, resolve observer identity limitations, refine service lifecycle semantics, and establish the complete initial policy pack.

3. **M2 — Software and system audit**

   P1

   Full NixOS closure, package ontology, version builtins, vulnerabilities, licenses, and compliance analysis.

4. **M3 — Reasoning kernel evolution**

   P1

   Integrate builtins, aggregates, disjunction, bounded existentials, WFS, congruence, and truth maintenance under checker parity.

5. **M4 — Generalized repair and transition planning**

   P2

   Multi-option repairs, abduction, transition bundles, risk, preconditions, compensation, and verification.

6. **M5 — Advanced runtime observation**

   P2

   D-Bus, richer Linux observation, event processing, evidence conflict, indexed telemetry, and improved operator views.

7. **M6 — Semantic integration ecosystem**

   P2

   JSON/YAML mappings, structured-source bootstraps, policy packs, Terraform, Kubernetes, identity, network and API analysis.

8. **M7 — Temporal and causal intelligence**

   P3

   Temporal rules, fault diagnosis, bounded constraint solving, and counterfactual reasoning.

9. **M8 — Simulation and controlled execution**

   P3

   Digital twin, scenario replay, typed execution adapters, verification, and governed operational automation.

10. **M9 — Intent and dataflow**

    P3

    Formal goal generation, database and storage transitions, resumable data operations, and compensation.

11. **M10 — Hardware and distributed infrastructure**

    P3

    P4

    Hardware evidence, cryptographic attestation, multi-node semantic modeling, fleet reasoning, and distributed coordination.

12. **M11 — Self-reference and governed evolution**

    P4

    Repository ontology, case memory, controlled learning, and governance-approved self-development.

## **31. What I would actually work on next**

Despite the much bigger vision, I would keep the immediate work tightly focused.

| Order | Work item                                             | Reason                                                       |
| ----- | ----------------------------------------------------- | ------------------------------------------------------------ |
| 1     | Complete R3 and R4                                    | Finish the current runtime security baseline                 |
| 2     | Fix listener attribution and identity limitations     | Improve the honesty and completeness of operational evidence |
| 3     | Formalize the fact/evidence schema                    | Every later subsystem depends on it                          |
| 4     | Implement version builtins and aggregates             | Prerequisite for meaningful software vulnerability reasoning |
| 5     | Implement R5 in offline audit scope                   | Complete the initial five-rule security model                |
| 6     | Build full NixOS closure and vulnerability analysis   | First major expansion in real-world usefulness               |
| 7     | Integrate reasoning extensions with proof checking    | Expand expressiveness without compromising trust             |
| 8     | Generalize repair into transition bundles             | Establish the foundation for controlled automation           |
| 9     | Add event-driven observation and richer TUI           | Improve operational usefulness                               |
| 10    | Build JSON/YAML ingestion and policy-pack composition | Unlock the integration ecosystem                             |

I would work on these in roughly this order, with the evidence schema and kernel contract informing the implementation of the other work.

# **Part V — Strategic decisions to settle now**

There are several decisions that will prevent the expanded roadmap from turning into a collection of disconnected experiments.

## **32. Keep NixOS as the reference substrate**

Do not chase every infrastructure platform simultaneously.

NixOS is particularly valuable because configuration is declarative and can be evaluated before it is applied. That gives SUMOnix an unusually strong basis for proving configuration changes.

Prove the full semantic control loop here before broadening execution to other platforms.

## **33. Do not prematurely replace the Nix kernel**

The Ω document identifies Rust, Tokio, eBPF, SQLite, and other technologies as a possible final stack. Those are plausible choices for some future subsystems, but they do not justify an immediate rewrite.

My recommendation:

- Keep the pure Nix reasoning kernel as the reference implementation.
- Continue using the current Nix architecture for bounded semantic evaluation.
- Introduce native code where runtime observation, event processing, or measured performance justifies it.
- Keep new engines behind explicit interfaces.
- Require semantic agreement and independent proof verification before adopting an alternative backend.

A Rust observer or runtime coordinator is a more natural early experiment than replacing the entire reasoner.

## **34. Distinguish four types of truth**

Make this a universal design rule:

- **Declared:** what the configuration says.
- **Observed:** what an evidence source reports.
- **Derived:** what follows from the evidence and rules.
- **Intended:** what the system is supposed to achieve.

These are different dimensions of the model. They should not be collapsed into one generic set of facts.

## **35. Make transitions—not actions—the unit of autonomy**

The ultimate system should not evolve toward an AI that issues commands.

It should evolve toward a system that builds complete transition bundles, proves their safety conditions, obtains authorization, executes through narrow adapters, and verifies actual outcomes.

That one architectural decision ties together repair, execution, simulation, audit, learning, and governance.

# **Final assessment**

The larger ambition I recommend is:

# **SUMOnix**

## A constitutionally governed semantic operating and infrastructure control plane.

It understands declared infrastructure, observes actual infrastructure, reasons about capabilities and constraints, diagnoses discrepancies, plans verified transitions, and eventually manages approved changes across systems.

**Its fundamental loop**

**Intent**

**Semantic world model**

**Evidence and reasoning**

**Diagnosis and planning**

**Proof and governance**

**Execution and verification**

**Learning and evolution**

The central opportunity is not to build the biggest possible Datalog engine or the most elaborate NixOS dashboard.

It is to combine formal semantics, real-world evidence, independent proofs, safe planning, and controlled execution into a coherent system.

That creates a progression with real strategic value:

**A configuration reasoner → an operating-system metavisor → a semantic infrastructure control plane → a governed, self-evolving infrastructure system.**

I would make this consolidated roadmap the successor to the scattered TODO documents, preserving their original ideas but giving each one a clear place, dependency, and architectural purpose.

