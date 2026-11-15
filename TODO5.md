# sumonix — TODO5: The Metavisor Plan (rev 2)

> **Supersedes TODO4.md** (2026-11-16). Goal: *a semantic OS "metavisor" that adds
> intelligence to the system's configuration and runtime operation.*
>
> **Rev 2 changes** (applying the effectiveness evaluation): the thin loop now runs on the
> **existing kernel with zero new proof step kinds** — WFS, congruence, and temporal logic
> move off the critical path behind explicit triggers. Repair is verified by **re-lifting the
> patched config**, not by editing facts. M1 carries a **measured eval-overhead budget**.
> "Demonstrable" is defined as a named artifact (**D1**). "Usable" requires an operator
> surface, a rule pack (**system.kif v0**), and a real-host soak. Estimates corrected ×2–3
> where proof/checker work is involved; **~2–3 weeks to D1**.

## The goal, in one sentence

**The system holds a semantic model of itself — declared and observed — reasons over it
with proofs, catches contradictions before anything builds, explains drift while running,
and proposes declarative repairs it verifies before a human applies them.**

NixOS is the only OS where this closes: configuration is data (pure eval-time lifting),
and repair is a patch to `configuration.nix` that the existing gate re-verifies on rebuild.

## Definition of done (the target everything builds toward)

- **D1 — the 60-second live tour** (container, `source: live`, byte-stable, CI-recorded):
  1. Real config: postgres enabled + strict firewall → **eval fails with a proof** naming both option paths.
  2. Fix firewall, rebuild, boot. Stop postgres → within one refresh interval, `sumo status` and the journal show **drift with a proof**.
  3. `sumo repair` → ranked option-path diff, each with a proof verified on the re-lifted patched config → apply → rebuild → **gate passes**.
- **Operator surface**: `sumo status` drift/violation section (source-labeled), structured journal alerts, `sumo repair`. That's what a human sees and does.
- **system.kif v0**: five rules an operator would keep on (below), each demonstrated.
- **Soak**: module enabled on one real (non-container) host for 24 h with zero false drift claims.

Until D1 + soak exist, nothing is called "usable."

## What carries over from TODO4

| TODO4 item | Disposition |
| --- | --- |
| Kernel (parser → ontology → synthesis → ingest → engine → proof → checker → gate → relax) | ✅ The metavisor's brain. The thin loop uses it **as-is**. |
| 0.1 flake surface, 0.2 CI | ✅ Done. CI gains the container harness. |
| 1.1–1.3 `guard`/`ask`/`why`/`proof`/`check`/`relax`/`init`/`lint` | ✅ Done. The L0 (explain) surface. |
| 1.4 cache | → **M0.1** (runtime state store). |
| 1.5 error UX | → **M0.2**. |
| Known issues (tui build, aarch64, sumo-facts) | → **M0.3**. |
| 0.3 release | After D1 + soak: tag `v0.2.0-metavisor-alpha` with proof + checker assets. |
| Phase 2 product inputs, Phase 4 adoption surface | ⏸ Parked (revival conditions below). |
| V4 Soufflé | → **M5**, runtime-backend decision, with honest cost. |
| Workstream N container | → **Test harness**, unparked with a job. |

## Architecture: one model, two loops, two scopes

```
nixosConfigurations.host.config ─► lift (M1, pure) ─► declared facts (+option-path provenance)
systemd / proc / ss / stat ─► observer (M3, impure, dumb) ─► observed facts
                                   └─► completeness attestations (+TTL, time, hash)
                          ┌──────────────┴──────────────┐
                          ▼   alias facts + union-find (M2, existing kernel)
                          ▼
            engine.run (Horn + NAF + equal; pure; the oracle)
                          ▼
     ┌──────────────┬─────────────────┬────────────────┬─────────────────┐
     ▼              ▼                 ▼                ▼                 ▼
 config gate    drift/violation   proof export     relax → repair    status/journal
 (eval fails    (guarded by fresh (checker         (M4: option diffs (operator surface)
  with proof)    attestation)      re-checks)        + re-lift proof)
```

- **Config loop** (pure, eval-time): lift → reason → gate. Contradictions fail before build.
- **Runtime loop** (resident): observe → re-derive → diff → explain → propose.
- **Two scopes, to control fact volume instead of fighting it:**
  - **Runtime scope** — curated: declared slice + units, listeners, unit users, secret-path modes. ~10²–10³ facts. Keeps the pure engine viable.
  - **Audit scope** — full closure, licenses, deps. ~10⁴–10⁵ facts. Runs in CI/offline, never in the runtime loop or default eval.
- **The observer is dumb.** Facts + attestations out, no logic. All intelligence in the kernel; the impure surface stays minimal and auditable.

### Drift without WFS (the key simplification)

The exporter enumerates *all* units (`list-units --all`) and *all* listeners (`ss`) per
snapshot and emits `(completeFor unitActive S)`, `(completeFor listener S)` with timestamp
and hash. NAF over an **attested-complete, fresh** snapshot is sound as of T:

```
completeFor(unitActive, S) & fresh(S) & declaredRunning(U) & not observedActive(U, S)
    ⇒ drift(U)
completeFor(listener, S) & fresh(S) & observedListener(P, S) & not declaredListener(P)
    ⇒ rogueListener(P)
```

TTL expiry drops stale facts *before* the engine sees them. If the observer dies, the
attestation expires, drift rules stop firing, and status reports **observation stale** —
never a false claim. This is Horn + NAF on the existing engine; no three-valued logic,
no new proof step kinds. WFS returns only when observation becomes genuinely partial (M2.5).

## Constitution (preserved + extended)

Preserved: pure Nix kernel · Rule Zero · rejection-with-reason · live/fixture honesty ·
byte-stable output · checker parity.

- **R1 — No claim without fresh, attested-complete observation.** Stale or partial observation → status `unknown`, never drift/violation. (Rev 2: enforced by freshness-guarded NAF, not WFS.)
- **R2 — No silent observation.** Every observed fact and attestation carries exporter ID, timestamp, snapshot hash, TTL. Every answer labels sources.
- **R3 — Checker parity per step kind.** New kinds ship with independent checker support + tamper tests in the same PR; CI enforces emitted ⊆ handled. **The thin loop adds zero kinds**, so R3 holds trivially until M2.5/M3.5.
- **R4 — Actuation is gated and logged** (M6): KIF whitelist, proven preconditions, event-logged, self-gated.
- **R5 — Proposers propose, the kernel decides.** Any LLM drafts; nothing touches the system without gate + checker.

**Honest limit:** the checker verifies *inference*, not *observation*. A completeness
attestation is an exporter claim — hashed, labeled, and part of the trust boundary. No
artifact may blur that line.

## Milestones — the thin loop (M0 → D1)

### M0 — Support work

| # | Item | Acceptance | Effort | Status |
| --- | --- | --- | --- | --- |
| M0.1 | **Cache** (was 1.4): key = hash(facts+rules+ontology+synthesized+**engine version**); `.runtime/<digest>/`, partitioned by predicate; `--no-cache` | Warm subcommand <100 ms; CI byte-diff cached vs uncached; poisoning test → recompute or loud rejection | 4–8 h | ⬜ |
| M0.2 | **Error UX** (was 1.5): located diagnostics, unknown-predicate warnings vs domains, completions, exit codes | Typo'd KIF → `file:line:col`, never a Nix stack trace | 3–5 h | ⬜ |
| M0.3 | **Housekeeping**: tui `buildGoModule`+`vendorHash`; aarch64 CI matrix; sumo-facts tested or demoted | `nix flake check` green both arches; no unbuildable advertised package | 2–4 h | ⬜ |

### M1 — Config lifter + system.kif skeleton · *keystone*

| Item | Acceptance | Effort | Status |
| --- | --- | --- | --- |
| `reasoner/lift-config.nix`: pure `nixosConfig → KIF`. **Every declared fact carries its controlling option path(s)**; facts from the port-defaults table marked `inferred`, never `declared`. Lifter reads only slice paths (services, firewall, users, systemPackages) — not the whole option tree. `system.kif` mid-level ontology with domain declarations; well-typedness gate on lifted facts. Lifter emits alias facts (`(equal services.postgresql postgresql.service)`); templated/custom unit names handled explicitly, ambiguous joins rejected with reason | Real config: postgres + strict firewall → **eval fails with proof naming both option paths**; checker re-verifies; byte-stable; no fixtures. **Eval budget: gate adds <2 s to eval, measured and recorded**; slice shrinks to fit | 1–2 d | ⬜ |

### M2-lite — Identity + drift on the existing kernel

| Item | Acceptance | Effort | Status |
| --- | --- | --- | --- |
| Alias facts + existing union-find join config ↔ unit ↔ store path ↔ pname. `declared`/`observed` pairs. Freshness-guarded drift + rogue-listener rules (above). **No new engine extensions, no new step kinds.** system.kif rules 1–2 (below) | CI container: stop declared unit → drift with proof; open rogue listener → violation with proof; **observer silent → attestation expires → no drift claim, status `unknown`** | 1–2 d | ⬜ |

### M3A — Resident loop, stage A (timer) + operator surface

| Item | Acceptance | Effort | Status |
| --- | --- | --- | --- |
| `nixosModules.default` gains `sumonix-metavisor`: timer-driven refresh (exporter + M0.1 cache). Observer emits snapshots + completeness attestations; TTL expiry pre-engine; timestamps as fact arguments (no temporal logic). **Persistent** append-only event log via `StateDirectory=sumonix-metavisor` (`/var/lib/…`, survives reboot); cache ephemeral. **Operator surface**: `sumo status` drift/violation section (source-labeled) + one structured journal line per event with proof ID. Degraded modes: observer dead → `unknown`; engine behind → snapshot mode, logged | Change → explained drift within one interval, visible in status **and** journal; `sumo why` works on drift; event log replayable; every fact labeled. **Module installs on a non-container host** | 1–2 d | ⬜ |

### M4-lite — Repair, verified honestly · *the differentiator*

| Item | Acceptance | Effort | Status |
| --- | --- | --- | --- |
| Extend `relax.nix`: single flips on **declared facts with exactly one controlling option path** → option edit. **Verification = re-lift the patched config**: `extendModules` with the option change → lift → gate → export proof of pass. Never hand-edited facts. Flips on `inferred`/multi-path facts → rejected with reason; flips on observed facts → actuation candidates (M6). `sumo repair` emits ranked unified diffs + proofs; `--check` re-verifies | Firewall/postgres case → ≥2 ranked patches, every proof re-checks **and comes from the re-lifted patched config**; applying top patch → rebuild → gate passes (container, live) | 2–4 d | ⬜ |

### D1 — The demo artifact

| Item | Acceptance | Effort | Status |
| --- | --- | --- | --- |
| `tools/metavisor-tour.sh` driving the three scenes above on the CI container; asciinema cast + byte-stable transcript in CI; README section regenerated | D1 recorded, `source: live`, reproducible from a clean checkout; doubles as the end-to-end regression test | 1 d | ⬜ |

**Thin loop total: ~2–3 weeks.** M1 → M2-lite → M3A → M4-lite → D1. Close it end-to-end
before deepening anything.

## system.kif v0 — five rules an operator would keep on

| # | Rule | Scope | Facts needed | Lands in |
| --- | --- | --- | --- | --- |
| 1 | Listener on 0.0.0.0 with no firewall allowance ⇒ violation | runtime | observed listeners + declared firewall | M2-lite |
| 2 | Declared-running unit not observed active (fresh attestation) ⇒ drift | runtime | units + declared services | M2-lite |
| 3 | Unit running as root, not in `rootAllowed` whitelist ⇒ violation | runtime | unit User (systemd show) + whitelist | M3A |
| 4 | Declared secret path world-readable ⇒ violation | runtime | stat modes of declared secret paths | M3A |
| 5 | Closure package with `badLicense` ⇒ violation | **audit (CI)** | full closure + licenses | M5 audit job |

Each rule ships with a demo scene or CI check. This is the "intelligence" — the mechanism
is worthless without it. New rules follow the same contract: typed, rejected-with-reason
if ungroundable, demonstrated.

## Deepening — behind triggers, not on the critical path

| Milestone | Trigger | Content | Honest cost |
| --- | --- | --- | --- |
| **M2.5** | Observation becomes partial/multi-source (completeness attestation impossible), or identity joins exceed alias+union-find | WFS (T2.2) and/or congruence (T2.4) to core, with `by unknown#neg` / `by congruence#…` + checker parity + tamper tests | 1–2 wk each |
| **M3.5** | D1 stable; sub-interval latency wanted, or first interval rule ("restarted after patch", "backup ran <24 h") | Stage B: D-Bus observer (Subscribe, UnitNew/Removed, PropertiesChanged). Time-compare **builtin** (T2.6) first; full temporal (T3.3) only if interval rules need it | 2–4 d; temporal + parity 1 wk |
| **M5** | After D1: benchmark **both scopes** (runtime 10²–10³, audit 10⁴–10⁵), incl. **lift time** | Publish table. Runtime fits cadence → stay pure. Audit too slow → semi-naive (T3.2) or Soufflé (T2.7) **for audit scope only**, Nix kernel as differential oracle, nightly diff CI. **Prefer scope reduction over engine swaps** | bench 2–4 h; Soufflé + proof-format translation + parity **1–2 wk** |
| **M6** | M4 proven in soak; safety policy written | L2 actuation per R4: whitelist, proven preconditions, event-logged, self-gated. LLM proposer seat (R5) may land here, never in the decision path | deferred |

## Test harness: the container, unparked with a job

CI runners have user namespaces. The parked `container/` is the disposable **live** host:
stop units, open rogue listeners, apply repairs, rebuild. End state: **the container passes
its own gate and detects its own drift.** Out of the README until D1 passes; every scene
labeled `source: live`.

## Parked from TODO4 (revival conditions)

| Item | Revive when |
| --- | --- |
| json2kif, lockfile+OSV | A policy needs vulnerability facts; version-range builtins + checker parity are a hard prerequisite |
| Policy packs as flakes | `system.kif` stabilizes |
| SARIF, Action, receipts, badges | External users appear; receipts must distinguish observation trust from inference trust |
| TUI | After M3A: browse drift/events over the cache |
| Full closure at runtime | Never by default — audit scope only (M5) |

## Explicitly not doing

- No WFS/congruence/temporal on the critical path before their triggers fire.
- No new proof step kinds in the thin loop.
- No adoption surface before D1 + soak.
- No L2 actuation before L1 is proven; no unwhitelisted action ever.
- No LLM in the decision path.
- No repair claim based on hand-edited facts — re-lift or it didn't happen.
- No drift claim without a fresh completeness attestation.
- No incremental/parallel engine before M5 data; no Soufflé before scope reduction is tried.
- Rule Zero unchanged: runtime loop is a daemon; kernel stays the pure oracle.
- No fixture demo where live is possible.

## Success metrics

| Metric | Now | At D1 + soak |
| --- | --- | --- |
| Declared state as facts | 0 | slice with option-path provenance; **gate eval overhead <2 s, measured** |
| Observed state | ~24 live, manual | units/listeners/users/secret-modes, attested-complete, TTL'd, labeled |
| Config contradiction | fixture | real config fails eval with proof |
| Change → explained drift | manual | <1 interval, visible in status + journal, with proof |
| Violation → repair | fact-flip menu | ranked option diffs, proofs from re-lifted patched config |
| Checker coverage of emitted kinds | core | 100% (thin loop adds zero kinds) |
| Operator rules | 1 toy | 5 demonstrated (system.kif v0) |
| Demonstrable | asserted | **D1 recorded live, byte-stable, in CI** |
| Usable | — | 24 h real-host soak, zero false drift |

## Risks and honest limits

- **Attestation is a trust input.** The checker can't verify the exporter told the truth; R2 makes the boundary visible. A false completeness claim is the worst failure mode — the observer stays dumb and its attestations are explicit, hashed facts.
- **Inferred ≠ declared.** Port defaults are marked; repair never proposes edits on them.
- **Identity exceptions** (templated units, custom `systemd.services` names): lifter emits aliases explicitly; ambiguous joins rejected with reason, not guessed.
- **Eval budget may force a smaller slice.** Shrink the slice, don't blow the budget — a gate users disable is worth zero.
- **Event log persists; cache doesn't.** Reboot replays from the log; first post-boot refresh re-attests before any drift claim.
- **Soufflé is expensive** (proof translation + parity). Scope reduction first; audit-only fallback second.

## If you only do three things

**M1** (lifter + provenance + budget), **M2-lite** (attested drift on the existing kernel),
**M4-lite** (one flip → one re-lift-verified patch). M3A can be a bare timer while those
land. That trio closes the loop; D1 makes it visible; everything else deepens it.

---

## Status log

- **2026-11-16 (rev 2)** — Effectiveness evaluation applied: islands moved behind triggers; thin loop on existing kernel (zero new step kinds); repair verified by re-lift via `extendModules`; M1 eval budget; D1 + operator surface + system.kif v0 + soak as definition of done; two-scope fact-volume control; estimates corrected (~2–3 weeks to D1). Supersedes TODO4. Next: **M1**.
- **2026-11-16 (rev 1)** — Initial metavisor plan; superseded by rev 2 same day.

