<!--
Source: Manus cloud agent, task W8JFR6mQVyBNjWce3dnvc5
Commissioned 2026-08-31 on operator instruction, as the architecture follow-up
to Manus's own KV-cache survey (magentic-market-ai/docs/research/
kv_cache_implementations_report.md) plus docs/research/Icl.md.

Manus had NO repository access. The three-way state division, PERSIST's
placement authority, and the SwitchYard routing arrangement were supplied from
our ADRs. Its "not established" markings on our effective model, tokenizer and
template identity are correct -- we do not know those, which is the finding.

STATUS: recommendation. Nothing authorized. No KV persistence is built.
-->

# Architecture Follow-up: Continuous and Persistent Inference State

**Date:** 2026-08-31  
**Basis:** Supplied architecture brief and the prior KV-cache survey as summarized there. No repository access was used. Any claim not derivable from the brief is marked **not established**.

## Executive decision

A persistent KV cache should **not remain classified simply as “ephemeral nondeterministic inference state.”** Persistence changes its lifecycle, but not its authority. Split the third plane into:

| Subcategory | Meaning | Authority | Treatment |
|---|---|---|---|
| **Transient inference state** | Disposable state that can be dropped and recomputed | Nondeterministic; non-authoritative | May remain ephemeral |
| **Durable inference artifact** | Persisted, restorable state intended to resume an inference continuation | Nondeterministic; non-authoritative | Must be versioned, attestable, and admitted fail-closed |

A durable artifact does **not** become application state or metadata merely because it is stored on disk. BACK/BACKJOB remains the owner of the deterministic domain record. BUS remains the deterministic source of truth for what happened, including failures. MIND’s persisted inference artifact remains non-authoritative and must never write domain state.

The immediate recommendation is **not to make provider-routed, cross-model KV restoration a correctness dependency yet**. First establish a pinned execution identity and a fail-closed cache-admission contract. Until then, persistence may be used only as an optimization that is safe to discard; uncertainty must produce a cache miss or recomputation.

## Existing decisions that remain intact

| State | Owner | Character | Effect of persistence |
|---|---|---|---|
| Application state | BACK and BACKJOB | Deterministic domain record | Remains authoritative and is not reconstructed from inference state |
| Metadata | BUS through Rails Event Store | Deterministic record of what happened | Remains the source of truth for admitted events and outcomes |
| Inference state | MIND’s SQLite, bound through `DB_PATH` | Nondeterministic inference plane | Gains a durable-artifact subcategory but no authority |

PERSIST remains a placement authority. The operator’s extension means MIND’s store is persisted at a path determined by PERSIST. That creates a new separation: **placement is not admission**. A valid path can contain stale, incompatible, incomplete, or unsafe state.

## 1. Does persistence move KV cache out of the ephemeral category?

### Verdict

**Yes. Split the category.** A restorable KV cache is no longer ephemeral in its lifecycle. Call it a **durable inference artifact**. It remains inside the nondeterministic inference plane and must not become truth, metadata, or application state.

> **Durability changes how long an artifact exists and how it must be admitted; it does not change who owns the truth.**

### ADR impact

This breaks the **name and implied lifecycle** of “ephemeral nondeterministic inference state,” but not the three-owner division. Amend the category to “nondeterministic inference state,” with transient and durable subcategories. State explicitly that a durable cache may be deleted without deleting the domain record or rewriting BUS history.

### Not established

It is **not established** whether MIND’s SQLite contains only KV material or also indexes, continuation descriptors, prompt material, checkpoints, or other state. It is also **not established** whether every current NOOA continuation can safely degrade to recomputation.

## 2. Is a KV cache a participant that can be forced to recompile?

### Verdict

**No, not literally.** A cache cannot recompile itself. It is derived output, not executable participant code. It is nevertheless a **contract-bound artifact** requiring participant-like admission gates.

| Thing | Role | Recompile? | Response to incompatibility |
|---|---|---:|---|
| MIND/NOOA participant | Executes inference and consumes or creates cache state | Yes, subject to redeployment | Recompile/redeploy or fail closed |
| KV cache artifact | Derived state under an execution identity | No | Reject, invalidate, discard, or regenerate |
| Cache-admission contract | Rules for whether an artifact may be consumed | Versioned with the consumer | Reject superseded or unknown contracts |

### ADR impact

The existing BUS-imposes-change rule should apply to the **consumer and cache-admission contract**, not by treating the cache as a participant. Add an explicit concept of **artifact compatibility**. A superseded artifact may remain physically present for diagnostics or deletion, but it must not be consumed.

### Not established

It is **not established** whether BUS distributes contract revisions to MIND, whether `cid` identifies the full cache-consumption contract, or whether NOOA exposes a formal cache serialization/compatibility version.

## 3. What must be in the cache-identity key with an uncontrolled router?

### Verdict

Under the current arrangement, where MIND names no model and SwitchYard routes across providers and translates protocol formats, **persistent KV restoration is unsafe unless execution identity is pinned or equivalently attested**. A key based only on logical request data, token IDs, or a MIND-visible route label is insufficient.

Conceptually:

> `cache identity = content identity + execution identity + cache-format identity + contract identity`

The brief establishes these minimum execution dimensions from the prior survey:

| Dimension | Present status |
|---|---|
| Model weights | Required; exact effective model identity is **not established** |
| Tokenizer behavior | Required; effective tokenizer identity is **not established** |
| Chat-template serialization | Required; effective template identity is **not established** |
| Relevant sampling/attention configuration | Required; exact relevant configuration is **not established** |
| Adapter identity | Required; adapter use and identity are **not established** |
| Multimodal inputs | Required where applicable; current support is **not established** |
| Model-specific cache semantics | Required; NOOA/provider semantics are **not established** |
| Prefix/content identity | Required; canonical prefix representation is **not established** |
| Cache format and producer version | Required; format/version contract is **not established** |

The safe choices are: **(a)** SwitchYard exposes an immutable, verifiable execution identity; **(b)** the provider-aware router owns cache reuse; or **(c)** durable reuse remains disabled. Do not use MIND’s model opacity as a reason to guess.

### ADR impact

The rule that MIND names no model need not change. What must change is the assumption that MIND can independently restore durable KV without a trusted identity from the routing boundary. Model opacity is compatible with persistence only if the opaque boundary exports a verifiable identity or owns reuse itself.

## 4. How do we detect a stale-block hit?

### Verdict

There is **no established general detector** that reliably distinguishes a semantically stale but structurally valid KV block after the fact. SHACL validation, checksums, successful deserialization, refusal recording, and fluent output do not prove semantic correctness.

> **The primary control must be prevention, not post hoc detection.**

| Control | Value | Limitation |
|---|---|---|
| Complete cache identity | Prevents known identity mismatches | Cannot protect against missing or false identity fields |
| Integrity checksum | Detects corruption or mutation | An intact stale artifact still passes |
| Contract/cid gate | Rejects superseded/unknown contracts | Requires a complete trusted compatibility model |
| Prefix/token verification | Detects represented-input mismatch | Does not prove correct effective model values |
| Provider/model attestation | Prevents unverified reuse | Availability and semantics are **not established** |
| Shadow recomputation | Can expose some divergence | Probabilistic and costly; policy is **not established** |
| Structural/refusal checks | Rejects malformed or policy-invalid output | Does not catch plausible semantic corruption |

If an artifact passes admission checks but one identity field is wrong or incomplete, the system may not detect the resulting semantic corruption automatically. A cache hit must therefore be treated as a risk-bearing admission, not as proof of correctness. BUS should record lookup, hit, miss, rejection, invalidation, fallback, and restoration outcomes, including failures; recording does not make the output correct, only the decision auditable.

### ADR impact

This breaks any implicit expectation that SHACL-valid output and refusal records catch all plausible-but-incorrect inference. It strengthens the existing fail-closed principle.

## 5. Does PERSIST’s placement authority extend to tiering?

### Verdict

**Yes for physical placement and retention; no for semantic reuse.** Path and tier are both placement decisions when they answer where bytes live. They should have one authority. But tiering must not make PERSIST the owner of model semantics or correctness.

| Decision | Owner |
|---|---|
| Path, volume, RAM/SSD class, durability class, locality, retention, capacity eviction | PERSIST |
| Whether an artifact is valid for the current execution | MIND/NOOA admission under BUS-governed contract |
| Which valid artifact to prefer | MIND/NOOA cache policy |
| Whether cache deletion affects domain history | Never; BACK/BACKJOB and BUS boundaries remain authoritative |

### ADR impact

No break occurs if tier is defined as a placement attribute. The ADR should explicitly separate **placement/retention policy** from **semantic admission/reuse policy**. PERSIST becomes overloaded only if it is asked to decide model-specific cache semantics or answer quality.

### Not established

It is **not established** whether PERSIST can observe capacity, pressure, locality, or tier health; whether RAM and SSD are separate stores; or whether deterministic tier placement is required for replay.

## 6. What breaks first at one pod, one agent, and a few sessions?

### Verdict

The first failures are likely to be **local correctness and lifecycle failures**, not fleet-scale throughput failures. The architecture should not borrow distributed complexity prematurely.

| Likely early failure | Why it reaches this scale |
|---|---|
| Reuse after model/router/configuration change | One restart, deployment, or route change can invalidate durable state |
| Incomplete cache identity | Router opacity is already a local design gap |
| Partial or stale SQLite restoration | One interrupted write or old volume is enough |
| Confusing fluent output with correct continuation | A single wrong hit can look successful |
| Unrecorded admission/rejection/fallback | The brief already reports silent and misleading outcomes |
| Ambiguous contract supersession | BUS can impose change, but the refusal gate is missing |
| RAM/SSD lifecycle surprises | A small tiered setup can already lose or retain state unexpectedly |

Cross-pod coherence, distributed locking, shared-cache races, fleet-wide eviction, multi-region placement, NUMA, and fleet bandwidth are **later concerns at the stated scale**, not first-build requirements.

## Recommended ADR amendments

| ADR area | Amendment |
|---|---|
| State taxonomy | Replace “ephemeral nondeterministic inference state” with “nondeterministic inference state,” split into transient state and durable inference artifacts |
| Authority | Durability never confers authority; durable artifacts are not application state, metadata, or source of truth |
| MIND boundary | Preserve: no provider credential, no model naming, proposes, never writes domain state |
| Router boundary | Require SwitchYard to expose verifiable execution identity or own cache reuse; otherwise disable durable reuse |
| BUS contract | Add versioned cache-admission/compatibility contracts and a fail-closed supersession gate |
| `cid` | Define whether it covers the full artifact contract; if not established, do not assume it does |
| PERSIST | Extend placement authority to tier, durability class, retention, and capacity eviction; exclude semantic validity |
| Observability | Record all cache decisions and failures in BUS metadata |
| Recovery | Cache deletion/invalidation leaves BACK/BACKJOB state and BUS history unchanged |

## Recommendation and sequence

### Stage 0 — Hold the line

Do not make persistent KV restoration part of correctness. Persisted artifacts may exist for controlled experimentation or diagnostics, but reuse must be disabled or allowed to degrade to recomputation until identity and admission are established.

### Stage 1 — Amend the state model

Rename the third plane and define durable inference artifact explicitly as nondeterministic and non-authoritative. Document the separation between artifact durability, BUS history, and application truth.

### Stage 2 — Establish execution identity

Require SwitchYard to expose or bind the effective identity needed for safe reuse: model, tokenizer, serialization/template, relevant configuration, adapter set, multimodal inputs, cache semantics, and format. The exact mechanism is **not established**. If SwitchYard cannot provide it, use provider-owned reuse or keep durable reuse disabled.

### Stage 3 — Define breaking changes and fail-closed admission

Define which changes invalidate artifacts and how BUS communicates supersession. Reject unknown, incompatible, or superseded artifacts. Uncertainty must result in a miss.

The exact breaking-change matrix is **not established** by the brief.

### Stage 4 — Add integrity and lifecycle controls

Add complete-write/recovery semantics, integrity protection, explicit invalidation, retention rules, tier rules, and BUS records for all cache outcomes. These controls improve safety and auditability but are not semantic proof.

### Stage 5 — Test deliberate stale-state cases

Test changed model identity, tokenizer/template, superseded contract, interrupted persistence, partial restoration, route changes, and provider translation changes. The acceptance criterion is fail-closed behavior, not successful deserialization or fluent output. Shadow recomputation may measure risk, but its policy is **not established** and it must remain supplementary.

### Stage 6 — Introduce tiering conservatively

After local correctness is established, add RAM/SSD tiering. PERSIST chooses tier and retention class; MIND/NOOA chooses only among semantically admitted artifacts. Start with one durable cold tier, bounded retention, explicit invalidation, and safe misses.

### Stage 7 — Reassess scale-driven concerns

Only after multiple pods, concurrent writers, shared stores, or material session pressure should the system address distributed locking, cross-pod coherence, fleet eviction, shared-cache bandwidth, and locality.

## Final rule

> **Persistent inference state is a durable nondeterministic artifact, not truth. It may be restored only when a trusted, complete execution identity and an admitted compatibility contract prove that it is eligible for the current inference. Otherwise it is a cache miss.**

This preserves the architecture’s product: explicit divisions. BACK/BACKJOB owns deterministic application state. BUS owns deterministic history, including failures. MIND owns the nondeterministic inference plane. PERSIST decides where the artifact lives, including tier and durability class, but not whether the artifact is semantically valid.

The immediate decision is therefore not whether to persist KV. It is whether the routing boundary can expose enough identity to make persistence safe. Until that is established, do not depend on durable KV restoration for correctness.

## Open items marked not established

1. The exact NOOA cache serialization, compatibility, and restoration semantics.
2. The effective model, tokenizer, template, adapter, attention, sampling, multimodal, and provider identity available from SwitchYard.
3. Whether SwitchYard can pin or attest execution identity for a continuation.
4. Whether MIND’s SQLite contains only KV artifacts or additional continuation state.
5. The precise meaning and coverage of `cid` for cache compatibility.
6. The BUS breaking-change matrix and supersession mechanism.
7. PERSIST’s atomicity, recovery behavior, capacity signals, and tier-health model.
8. The event schema required for cache admission and restoration outcomes.
9. Available semantic validation or shadow-recompute capability and acceptable cost.
10. Whether provider-owned cache reuse is compatible with the intended MIND/PERSIST boundary.

## Decision summary

| Question | Verdict | Decision affected |
|---|---|---|
| 1 | Split ephemeral from durable; keep both nondeterministic and non-authoritative | Terminology/lifecycle only |
| 2 | KV is an artifact, not a participant; it needs participant-like gates | Add artifact compatibility/supersession |
| 3 | Full execution identity is required; uncontrolled routing makes reuse unsafe without pinning/attestation | Add SwitchYard identity boundary or disable reuse |
| 4 | No reliable general post hoc stale-hit detector is established | Prevent, admit fail-closed, record outcomes |
| 5 | PERSIST owns physical tiering and retention, not semantic reuse | Extend placement narrowly |
| 6 | Local correctness/lifecycle breaks first | Build the small fail-closed system first |

**Author:** Manus AI

**References:** No external sources were used. The factual premises are limited to the supplied architecture brief and prior survey as summarized there.

[1]: /home/ubuntu/upload/pasted_content_l4gwO40qDpH7kiw1mpgGQH.txt "User-supplied architecture brief"

<!-- End of document -->

