<!--
Source: Manus cloud agent, task nVcew9UMZ9suKHxkas5iKq
Commissioned 2026-08-31 after ADR 0058, as the design follow-up to its own
2026-08-31c. No repository access.

It was given explicit permission to answer that CPCP is the wrong transport.
It took that option. Note its own flag: OTEL LogRecords are NOT RDF graphs, so
the OTEL-to-SHACL vocabulary is PROPOSED BY THE MEMO, not derived from OTEL.

STATUS: recommendation. Nothing authorized. LOG is not built.
-->

# Designing the Thirteenth Container: LOG on an OTEL-Based CPCP Contract

**Author:** Manus AI  
**Status:** Design recommendation; no repository access  
**Date:** 31 August 2026

> **Executive decision:** Keep the thirteenth `ROLE=LOG`, but do **not** put ordinary log volume through the per-record CPCP admitted-operation path. Use OTLP as the volume transport and make CPCP the governed contract: its method/schema identity, admission policy, refusal semantics, and receipt rules. Preserve the local append-only first-write floor in every producer, including LOG itself. Treat LOG as an aggregation and durable handoff path, never as the only record of a refusal.

## 1. Scope, established facts, and design premises

The brief establishes the following: there are thirteen containers; `ROLE=LOG` is a tenth Rails role sharing the Rails image with nine other roles; OTEL is the basis of a CPCP contract; a refusal must first be written locally without a remote-peer dependency; CPCP is JSON-RPC-shaped at `/_cpcp/rpc`; every call carries an `operationId`; writes carry `idempotencyKey` and `idempotencyScope`; admitted operations produce `receipt_cid` and `outcome_cid`; payloads are validated against SHACL shapes at admission; and the envelope is total—`{ok:true,...}` or `{ok:false,reason:,because:}`—rather than exception-raising.

The exact Rails version, container runtime, storage medium, filesystem durability guarantees, resource limits, deployment topology, restart policy, log rates, burst sizes, retention, clock discipline, existing OTEL libraries, current SHACL processor, CID algorithm, and the meaning of “container” in the operational topology are **not established**. The proposal below therefore specifies interfaces and invariants, not implementation details.

OpenTelemetry supplies a stable logical LogRecord model with top-level timestamp, observed timestamp, trace context, severity, body, resource, instrumentation scope, attributes, and event name fields. Its timestamp and trace-context fields are optional in the data model, while `ObservedTimestamp` is intended to be set when the event is observed by OpenTelemetry.[1] OTLP is a transport for batches of telemetry signals, and the official exporter specification defines logs endpoints, request size, timeout, compression, and retry behavior.[2] SHACL describes and validates RDF graphs through shapes and constraints; the current SHACL 1.2 page is a Working Draft, while the 2017 SHACL recommendation remains the latest published Recommendation.[3]

That last point creates an important adapter boundary: OTEL LogRecords are not themselves RDF graphs. The OTEL-to-SHACL representation and its RDF vocabulary are therefore **proposed by this memo**, not derived directly from the brief or mandated by OTEL.

## 2. Target architecture

The path should have five distinct stages:

```text
Producer role
  1. construct refusal/log event
  2. append locally, without network dependency
  3. enqueue/export asynchronously through OTLP batch path
  4. LOG receives, validates the CPCP/SHACL profile, and aggregates
  5. optional backend/exporter receives from LOG
```

The local append is the **record of first resort**. It is not a receipt from LOG, and it must remain readable after a LOG outage, producer restart, or shared Rails-image failure. The OTLP/LOG path is a **best-effort or bounded-durability aggregation path** whose loss and retry behavior must be explicit. The exact durability level of the local append is **not established** and must be tested rather than assumed from the word “append-only.”

The clean separation is:

| Concern | Recommended owner | Contract position |
|---|---|---|
| First recording of a refusal | Every producer, including LOG | Mandatory local floor; no remote peer dependency |
| High-volume movement | OTLP batch export | Transport outside per-record CPCP admission |
| Shape and semantic vocabulary | SHACL profile derived from OTEL fields | Versioned contract artifact |
| Method identity, admission policy, refusal taxonomy, and operational invariants | CPCP | Governs the contract, not necessarily every event as an admitted RPC |
| Aggregation, indexing, query, and downstream export | LOG | Secondary observation path; not the first-write authority |

## 3. Question 1 — OTEL data model to SHACL to CPCP methods

### 3.1 Field mapping

The SHACL profile should model one logical `otel:LogRecord` node per event and distinguish OTEL-defined fields from CPCP/system additions. The table uses “required at admission” to mean required by the **CPCP profile for this system**, not required by the OTEL data model.

| OTEL field | OTEL status/meaning | Proposed SHACL treatment | Required at CPCP admission? | CPCP/system addition? |
|---|---|---|---|---|
| `Timestamp` | Event time at source; optional in OTEL | `xsd:dateTime` or equivalent canonical timestamp; permit absence when unknown | No; require either `Timestamp` or `ObservedTimestamp` | No |
| `ObservedTimestamp` | Time observed by collection system; SHOULD be set once observed | Canonical timestamp | Yes for records entering LOG, because LOG is the observing collector | No |
| `TraceId` | Optional W3C trace ID | Fixed-length binary/hex representation | No | No |
| `SpanId` | Optional span ID; if present, `TraceId` SHOULD be present | Fixed-length representation plus conditional dependency on `TraceId` | No, but conditional | No |
| `TraceFlags` | Optional W3C trace flags | Byte/lexical constraint; only meaningful with trace context | No | No |
| `SeverityText` | Optional source severity text | String, bounded length | No | No |
| `SeverityNumber` | Optional normalized severity; defined ranges | Integer constrained to OTEL ranges or zero if unspecified | No | No |
| `Body` | Log body; OTEL field | AnyValue-shaped RDF representation, with bounded encoded size | Yes for the CPCP refusal profile; otherwise system policy must state whether empty body is allowed | No |
| `Resource` | Entity that generated the record | Required resource identity for LOG aggregation, with a minimum local identity | Yes for LOG admission; the exact minimum keys are proposed | No |
| `InstrumentationScope` | Scope that emitted the record | Structured optional object | No | No |
| `Attributes` | Additional event information | Map-like collection with controlled keys and value types | No generally; required keys are profile-specific | No |
| `EventName` | Name identifying event class/type | String/IRI-like controlled vocabulary | Yes for governed refusal records; recommended for all structured events | No |
| `operationId` | Not an OTEL LogRecord field | Add as CPCP envelope metadata and copy into a non-authoritative correlation attribute only if needed for search | Yes for CPCP calls; not required in ordinary OTLP event body | Yes |
| `idempotencyKey` | Not an OTEL field | CPCP envelope metadata for admitted writes; never infer it from body text | Yes only on admitted CPCP writes | Yes |
| `idempotencyScope` | Not an OTEL field | CPCP envelope metadata | Yes only on admitted CPCP writes | Yes |
| `receipt_cid` | Not an OTEL field | Response metadata for admitted operations; not a property of the original event | Yes in successful admitted response | Yes |
| `outcome_cid` | Not an OTEL field | Response metadata for admitted operations; not a duplicate event identity | Yes in successful admitted response | Yes |
| Local record identity | Not specified by OTEL | Add `localRecordId` in the local-floor envelope or local storage index | Yes for local-floor records; exact format **not established** | Yes |
| Contract/profile version | Not specified by OTEL | Add `contractId` and `contractVersion` to CPCP metadata or transport context | Yes at LOG boundary | Yes |

The key design rule is that CPCP metadata must not be copied into OTEL semantic fields merely because both describe identity. `operationId` identifies a CPCP call; `EventName` identifies the kind of event; `localRecordId` identifies the first local record; and `receipt_cid`/`outcome_cid` identify CPCP admission/outcome artifacts. They are related by links, not synonyms.

### 3.2 SHACL profile structure

The profile should contain at least three shapes, not one permissive mega-shape:

| Shape | Purpose | Core constraints |
|---|---|---|
| `OtelLogRecordShape` | Common OTEL-compatible event | `ObservedTimestamp` at LOG boundary; bounded body; valid trace-field dependencies; resource and attribute type constraints |
| `CpcpRefusalLogShape` | A refusal that must be observable | `EventName` from the refusal vocabulary; body contains stable refusal facts; producer role; operation/correlation link; local first-write marker |
| `CpcpAdmissionReceiptShape` | A response artifact for true admitted operations | `operationId`; idempotency pair; contract version; `receipt_cid`; `outcome_cid`; success/failure envelope consistency |

The exact RDF namespace, JSON-to-RDF conversion, SHACL processor, severity policy, and whether closed shapes are used are **not established**. A conservative proposal is to use closed shapes only for CPCP envelope metadata and refusal-event fields, while leaving the OTEL `Attributes` collection extensible but mechanically bounded. Otherwise every future OTEL semantic convention becomes a contract-breaking change.

### 3.3 CPCP method surface

The method surface should be small:

| Logical method | Transport | Purpose |
|---|---|---|
| `cpcp.contract.describe` | CPCP JSON-RPC | Returns contract/profile identifiers, supported bindings, limits, refusal taxonomy, and version. This is a governed operation and may produce receipts. |
| `cpcp.contract.validate` | CPCP JSON-RPC or offline validator | Validates a representative payload or batch against the versioned SHACL profile. It does not create an operational log record unless explicitly requested. |
| `log.ingest` | **OTLP batch binding recommended**; CPCP method description retained | Moves ordinary log batches under the declared profile and admission policy. Do not implement as one admitted CPCP call per record. |
| `log.refusal.report` | CPCP only for rare, consequential control-plane refusals; otherwise local floor plus OTLP batch | A deliberately narrow method for escalated refusal summaries, not a general logging API. |
| `cpcp.receipt.get` | CPCP JSON-RPC | Retrieves a receipt/outcome for operations for which receipts exist. |

The phrase “CPCP governs” should therefore mean: producers and LOG conform to the CPCP method/profile contract, validators enforce the SHACL profile, and the transport binding declares whether an item is an admitted operation or an asynchronous telemetry batch. It should not silently mean that every log record receives an operation-level receipt.

## 4. Question 2 — Volume

A per-refusal admitted CPCP operation is the wrong default shape for real log volume. It adds an RPC envelope, identity generation, idempotency storage, SHACL admission work, receipt creation, response handling, and likely retry state to every event. The brief supplies no rate, burst, payload-size, CPU, memory, disk, or latency budget; all quantitative capacity claims are therefore **not established**. Even at one pod and a few sessions, this is premature complexity because the design would optimize for a throughput and audit model that has not been measured.

The recommended shape is **OTLP batching under a CPCP-declared contract**:

1. The producer writes the event locally first.
2. A bounded asynchronous exporter groups events by contract version and destination.
3. The batch carries a batch identity, producer/resource metadata, schema/profile version, and sequence or range metadata. Exact field names are **proposed**.
4. LOG validates the batch envelope and each record against the applicable SHACL profile, or rejects the batch according to a stated partial-acceptance policy.
5. LOG returns transport-level acceptance and, where required, a batch receipt—not one durable CPCP receipt per ordinary event.
6. The local queue retains records until an explicit success condition; the success condition and retry horizon are **not established**.

The batch policy must choose one of two semantics. **Atomic batch admission** is simpler and safer for contract reasoning but allows one malformed event to poison a batch. **Per-record acceptance within a batch** protects good events but demands stable per-record statuses, a dead-letter/quarantine path, and careful duplicate handling. The recommendation is per-record results only at the OTLP/LOG ingestion layer, with a bounded maximum batch and a separate refusal summary, not full CPCP receipt semantics for every item.

Sampling is not an acceptable substitute for the local floor for refusals. If sampling is used, it may apply only to low-severity, non-consequential informational events under an explicit policy. A refusal, admission failure, quota refusal, contract violation, or local-floor failure must be unsampled locally. The exact sampling categories are **not established**.

## 5. Question 3 — LOG’s refusal contract

Yes: the local floor catches LOG’s refusal. LOG must not send its own refusal to LOG. The recursion terminates only if LOG has a role-local append operation that does not call the LOG network endpoint, does not depend on the Rails peers, and does not require the CPCP admission path to complete.

LOG should have a three-tier failure mode:

| Tier | Action | Remote dependency? | Must preserve what? |
|---|---|---:|---|
| `accepted` | Aggregate and return normal success/acceptance | Yes, to LOG process itself; no second LOG hop | Event and acceptance metadata |
| `refused` | Append refusal locally; return `{ok:false, reason, because}` to caller | No | Original attempted-write facts plus refusal reason |
| `floor_failed` | Make a bounded, locally defined emergency attempt and raise an operational alarm; do not recurse to LOG | No | At minimum, failure class and best-effort identity; exact emergency behavior **not established** |

“Over quota” must not be treated as an excuse to discard the refusal. The quota decision itself is a refusal event. The local floor must be quota-exempt or governed by a separate reserved capacity; otherwise quota exhaustion can erase the evidence of quota exhaustion. The reserved capacity, rotation, fsync policy, and behavior when the floor itself is full are **not established** and are design-critical.

LOG’s refusal record should contain the attempted operation class, producer role, local record identity, contract/profile version if known, refusal reason, stable machine-readable `because` code, size/count estimates if available, and whether the original payload was retained, truncated, hashed, or omitted. The exact field vocabulary is proposed here.

## 6. Question 4 — Correlated failure from shared Rails lineage

The shared Rails lineage objection still applies. A bad Rails deploy can remove both the application role and the LOG role, so LOG cannot be treated as an independent final observation point. Adding a container changes the role topology but does not change the failure domain. On the stated facts, the correct answer is: **shared lineage disqualifies LOG as the sole final observation point, but does not disqualify LOG as an aggregation path**.

The decision is acceptable only with a deliberately weaker claim:

> LOG improves aggregation, queryability, and cross-role correlation when the shared lineage is healthy; it does not provide independent evidence that the shared lineage failed.

The design should therefore retain at least one observation path outside the Rails image or outside the affected deployment unit for high-value failure evidence. Whether such a path exists, and whether the event bus was the previously rejected candidate, are **not established**. The replacement could be a host/runtime-level collector, a sidecar or agent in an independent failure domain, a platform log sink, or an operator-visible local artifact. This memo does not select among them without topology facts.

At one pod and a few sessions, it is premature to build multi-region or highly redundant LOG infrastructure. It is not premature to test the failure-domain claim: kill LOG, break the shared Rails image, fill the LOG quota, remove network reachability, and restart the producer. The expected invariant is that the producer’s local first record survives each test even when LOG is unavailable.

## 7. Question 5 — Does the CPCP envelope fight OTEL?

It fights OTEL if the envelope is treated as another log payload. It fits OTEL if it remains a transport/control-plane layer with explicit boundaries.

The following facts must not be duplicated into competing fields:

| Fact | Canonical location | Non-canonical copies |
|---|---|---|
| Event severity | OTEL `SeverityText`/`SeverityNumber` | Do not encode a second severity in `reason` |
| Event kind | OTEL `EventName` | Do not use CPCP method name as the event kind automatically |
| Event body | OTEL `Body` | Do not mirror the entire body inside `because` |
| CPCP call identity | CPCP `operationId` | A searchable attribute may link to it, but must not redefine it |
| Idempotency | CPCP `idempotencyKey` + `idempotencyScope` | Do not infer from trace ID or event timestamp |
| Admission decision | CPCP `ok`, `reason`, `because` | Do not encode a contradictory severity/body status |
| Receipt/outcome identity | CPCP response `receipt_cid`, `outcome_cid` | Do not put them in OTEL fields that imply event identity |
| First local write | Local-floor record identity | Do not claim a LOG receipt proves the local write occurred |

A refusal can consequently be represented as an OTEL LogRecord whose `EventName` is, for example, a governed refusal event, whose `Body` contains the attempted-write facts, and whose attributes link to the CPCP operation. The CPCP response separately states whether the call was admitted and why. One record may refer to the other; neither should impersonate the other.

There is one unavoidable tension: OTEL permits many fields to be optional, while a consequential CPCP refusal profile needs stronger requirements. That is not a contradiction if the SHACL profile is named as a **system profile over OTEL**, rather than presented as “the OTEL schema.”

## 8. Question 6 — What LOG should not accept

LOG should accept only records that are within its declared observation purpose and can be bounded operationally. The admission rule should be mechanical:

> Accept a record or batch only if its producer is an allowlisted role, its contract/profile version is supported, its event kind is in the allowlist or explicitly classified as low-risk telemetry, its encoded size and batch size are within limits, its OTEL field types and trace dependencies pass validation, its resource identity is present at the required level, and its category is not prohibited or sensitive without an approved policy.

LOG should reject, or route to a quarantine path, the following categories:

| Category | Default decision | Rationale |
|---|---|---|
| Consequential domain command/result | Reject from general log ingest | Use the domain CPCP seam; logs are not the business audit ledger |
| Arbitrary request/response dumps | Reject | High volume, secret leakage, and accidental payload capture |
| Credentials, tokens, session secrets, or unredacted personal data | Reject or redact before admission | Prevent LOG from becoming a secret sink; exact policy **not established** |
| Heartbeats and health checks at unbounded frequency | Rate-limit or sample | Avoid turning liveness into dominant volume |
| Fallback-site instrumentation already refused by doctrine | Reject unless policy changes | Preserve the “noise is not evidence” decision |
| Unknown event names or contract versions | Refuse and record locally | Fail closed at admission |
| Oversized bodies/attributes/batches | Refuse or quarantine | Protect the reporting path from resource exhaustion |
| Duplicate records | Accept only under explicit deduplication semantics | OTLP retries and local replay can produce duplicates |
| LOG’s own internal refusal | Never re-submit to LOG | Termination of the refusal recursion |

Mechanical gating should exist in three places: a producer-side typed event constructor, a CI/static policy check for event names and attributes, and LOG-side SHACL plus quota/rate validation. The exact language tooling and deployment controls are **not established**. A free-form “send anything to LOG” API should not be exposed.

## 9. Where the decision strains

| Strain | Assessment | Required guardrail |
|---|---|---|
| Tenth Rails role increases common-mode failure | Real and unresolved | Treat LOG as aggregation, retain independent first-write/observation path |
| CPCP’s receipts and idempotency do not scale per log event | Fundamental mismatch | OTLP batching for volume; CPCP governs profile and binding |
| SHACL validates RDF, not native OTEL JSON/protobuf | Adapter complexity | Version and test an explicit OTEL-to-RDF projection |
| “Fail closed” can create recursive or self-denying observability | Severe if local floor is not independent | Local append before remote admission; reserved floor capacity |
| Quotas can erase the evidence of quota refusal | Severe | Quota-exempt/reserved refusal floor and local refusal record |
| Per-record identity may become cardinality and storage cost | Likely, magnitude not established | Batch identity plus local record identity; receipts only where consequential |
| Open-ended OTEL attributes invite schema drift | Manageable | Extensible attributes with bounded values and allowlisted sensitive keys |
| Shared image can make contract versions move together | Likely, magnitude not established | Versioned contract artifact and compatibility tests independent of deploy |

The operator’s decision therefore strains at the exact boundary it attempts to formalize: **CPCP is optimized for consequential, auditable operations; OTEL/OTLP is optimized for telemetry representation and movement.** The design is sound only if CPCP remains the governing contract and does not become a per-log transactional transport.

## 10. Recommended sequence

1. **Freeze invariants.** Write down, as non-negotiable tests, that every refusal is first locally appended, LOG never records its own refusal by calling itself, and loss of LOG does not erase the producer’s first record.
2. **Define the projection.** Specify the OTEL LogRecord-to-RDF vocabulary, canonical timestamp and binary encodings, AnyValue representation, refusal event vocabulary, contract versioning, and sensitive-field policy. These are currently **not established**.
3. **Build the SHACL profiles.** Start with the common record, refusal record, batch envelope, and CPCP receipt shapes. Test valid, malformed, unknown-version, oversized, duplicate, and LOG-refusal cases.
4. **Define transport bindings.** Keep JSON-RPC CPCP for contract discovery, validation, consequential control-plane operations, and receipt-bearing calls. Bind ordinary log batches to OTLP, with explicit acceptance, retry, partial-acceptance, quarantine, and deduplication semantics.
5. **Implement the local floor first.** Before LOG aggregation, prove local append behavior under network outage, LOG outage, process restart, disk pressure, and quota refusal. Do not infer durability from a successful write call without a durability test.
6. **Add LOG as a bounded aggregator.** Enforce allowlists, quotas, size limits, rate limits, SHACL validation, and a non-recursive local refusal path. Keep the API typed and narrow.
7. **Run failure-domain tests.** Break the shared Rails image and make LOG unavailable. Verify that local refusal records remain available and that the system does not claim independent observation from LOG.
8. **Measure before scaling.** At one pod and a few sessions, measure event rate, burst size, serialized size, CPU, memory, local queue growth, validation latency, and recovery lag. Do not choose replicas, batch thresholds, retention, or storage class before these measurements.
9. **Only then decide whether a separate external sink is needed.** If the requirement is evidence of shared Rails failure, LOG cannot satisfy it by itself; select an independent path based on measured requirements and the actual topology.

## 11. Bottom line

Approve the thirteenth container as **LOG**, but narrow its claim. It is a governed aggregation path, not an independent final witness. Approve OTEL as the semantic basis and SHACL as the language-neutral contract representation, but treat the OTEL-to-RDF projection as a versioned system proposal. Reject the idea that each refusal should be a full CPCP admitted operation with its own receipt and synchronous response path. Use the local append-only floor for first evidence, OTLP batching for volume, and CPCP for the contract, admission policy, exceptional consequential operations, and receipt-bearing control-plane semantics.

The decision is strained—not defeated—by common-mode Rails failure, by the mismatch between per-call CPCP machinery and telemetry volume, and by the fact that SHACL requires an explicit RDF projection. Those strains are contained if the design preserves the local floor and refuses to make LOG or CPCP carry a stronger guarantee than they can provide.

## References

[1]: https://opentelemetry.io/docs/specs/otel/logs/data-model/ "OpenTelemetry Logs Data Model"

[2]: https://opentelemetry.io/docs/specs/otel/protocol/exporter/ "OpenTelemetry Protocol Exporter"

[3]: https://www.w3.org/TR/shacl12-core/ "W3C SHACL 1.2 Core"; see also the latest published Recommendation at https://www.w3.org/TR/shacl/

## Appendix A — Source brief carried into this design

The operator’s supplied brief is reproduced in the attached source text, `/home/ubuntu/upload/pasted_content_bYa3K4EczfLc3gIfxh385t.txt`. No repository or deployment artifacts were used. Any claim not derivable from that brief or the cited specifications is marked **not established** in the memorandum.

## Appendix B — Premature at one pod and a few sessions

It is premature to build per-event receipt storage, a bespoke high-availability LOG cluster, multi-region replication, a broad semantic-convention catalog, sophisticated adaptive sampling, or a generalized log query product. It is not premature to define the local-floor invariant, the OTEL-to-RDF projection, the four initial SHACL shapes, the refusal taxonomy, the batch binding, and the failure tests. Those are the smallest artifacts that prevent the decision from recreating the original regression.

**End of memorandum.**
