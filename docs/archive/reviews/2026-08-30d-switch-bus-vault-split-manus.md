# SWITCH / VAULT Architecture Recommendation

**Status:** Exploration only. Nothing authorized or built.

## Executive decision

Adopt the **bus/repository split**. SWITCH should be a bus: dispatch, subscriptions, delivery, retries, and reconstructible operational state. **PERSIST must remain the sole physical storage executor and the owner of the durable event repository.** VAULT should remain a separate, narrowly constrained container. Keep seven containers for this iteration. Put application-originated publication behind the existing CPCP seam; do not create a parallel direct ingress beside `/_cpcp/rpc`.

The durable Rust RES-like reimplementation is **premature**. Build a bus-only slice first. The supplied brief is the source for all RES, substrate, ADR 0045, and Switchyard assertions; independent verification is **not established** because the repository and direct source URLs were not provided.

## 1. Does a separate VAULT resolve the warning?

**Yes, it resolves the specific vault-plus-router bundling warning, but the container split is not sufficient by itself.** It separates credentials from the pre-alpha Switchyard/router failure, release, and trust boundary.

VAULT should be a narrow credential service only. It must not host Switchyard, own the event repository, publish domain events, or become a general configuration service. It should expose only explicitly needed operations, use workload identity and least privilege, avoid shared writable volumes with SWITCH or PERSIST, and never emit secret values into events, logs, telemetry, or durable state. It needs independent release, health, restart, and resource controls, auditable access metadata, rotation/revocation behavior, and defined fail-closed or degraded behavior.

The concrete identity mechanism, secret backend, rotation protocol, audit retention, and outage behavior are **not established** and must be specified before implementation.

| Constraint | Required decision |
|---|---|
| Responsibility | Credentials and secret operations only |
| Durable domain state | None; PERSIST remains authoritative |
| Event participation | No domain-event publication or subscription |
| Filesystem | No shared writable secret or data volume |
| Access | Explicit caller allowlist and least privilege |
| Failure | Defined per-operation outage behavior |
| Audit | Access metadata only; never secret values |

## 2. Bus versus repository

**Yes: SWITCH should own dispatch/subscriptions while PERSIST owns the event repository.** That mirrors the relevant RES packaging distinction without claiming that a new Rust implementation is semantically equivalent to RES.

SWITCH may hold in-memory subscription indexes, connection state, retry timers, and other operational state that can be discarded and reconstructed. It must not own the authoritative event log, durable outbox records, snapshots, archives, or offsets whose loss would change business truth.

**If SWITCH holds the event log, it breaks the invariant that PERSIST is the sole physical storage executor.** The brief explicitly says that the event log is the durable record. Calling the component a bus does not change ownership: the component that physically stores that log is a persistence owner.

## 3. Is a pub/sub bus a second write path?

**Yes, if it is reachable as a parallel application ingress.** When publishing represents a state transition, publishing is a logical write. A direct publisher-to-SWITCH path could bypass authorization, validation, transaction coordination, and audit behavior at CPCP.

SWITCH should therefore sit **behind CPCP**, not beside it. The intended flow should be: a command enters through `/_cpcp/rpc`; the responsible service validates and applies it; PERSIST commits the durable event; and a defined commit-to-delivery handoff causes SWITCH to dispatch the committed event. Direct bus ingress must be prohibited unless a new ADR explicitly supersedes ADR 0045.

The handoff contract must define commit-before-publish behavior, retry after a PERSIST commit, duplicate delivery, acknowledgement, and recovery after either component fails. Whether the existing substrate already provides an outbox or equivalent is **not established**.

## 4. Is “both are Rust” a sound reason to share an execution environment?

**No.** Language affinity is packaging convenience, not a trust, lifecycle, release, resource, or fault boundary.

Putting an in-house bus in the same container as a pinned, pre-alpha, “not production-ready” upstream router is **the same category of bundling mistake at lower stakes**. A Switchyard upgrade can force a bus rebuild; bus resource exhaustion can affect routing; and a router failure can remove event delivery. The exact severity is **not established** without code and workload data.

Keep VAULT, SWITCH, and PERSIST separate. If SWITCH and Switchyard remain together temporarily, require independent process health signals, resource ceilings, explicit version pinning, and an adapter at the CPCP seam. Do not fork Switchyard. Whether Switchyard needs a separate container later should be decided from measured release, resource, and failure characteristics, not from the fact that both components use Rust.

## 5. What is lost by reimplementing RES semantics in Rust?

Reimplementation loses the assurance of a mature library: established edge-case behavior, tested semantics, operational familiarity, and an existing mutation-coverage discipline. It also creates a new protocol that consumers cannot safely rely on until its meaning is specified. Rust does not supply semantic equivalence.

Before a Rust implementation can be trusted with the durable record, specify and test at least:

| Area | Required contract |
|---|---|
| Ordering | Global/stream/aggregate/partition scope; concurrency and restart behavior |
| Identity | Event ID, stream identity, version, causation, correlation, timestamps |
| Append | Atomicity, optimistic concurrency, duplicate append behavior, visibility |
| Delivery | Ack point, at-least-once behavior if selected, redelivery, retry, poison events |
| Idempotency | Deduplication key, retention, crash windows, replay behavior |
| Subscriptions | Filtering, start position, catch-up, live handoff, cancellation, recovery |
| Failure | Crash, partition, PERSIST outage, SWITCH outage, partial acknowledgement |
| Outbox | Atomic relationship between durable commit and delivery eligibility |
| Replay | Schema evolution, snapshots, catch-up, isolation |
| Security | Authentication, authorization, tenancy boundaries, secret-leak prevention |

Testing must include model/property tests for ordering and duplicates, concurrent append tests, crash/restart and fault-injection tests at acknowledgement boundaries, integration tests against the actual PERSIST repository, and replay/migration tests. Mutation coverage comparable to the stated RES discipline is a useful bar, but coverage alone cannot prove equivalence.

**Do not implement the durable record first.** Build a thin bus-only SWITCH layer over PERSIST. A durable Rust replacement is premature until the contract, crash behavior, replay/migration story, and operational evidence exist. The current RES wiring is **not established**.

## 6. Are seven containers the right purchase?

**Keep seven for this iteration.** The seventh container buys the requested VAULT separation and avoids reintroducing a more consequential credential/router coupling.

A possible six-container arrangement is to merge **BACK and BACKJOB**, but only if they are proven compatible in trust level, ownership, release cadence, scaling, resource profile, and failure tolerance. The brief does not establish those facts, so this is a later consolidation candidate rather than the current recommendation.

Do not reduce the count by combining VAULT with SWITCH, Switchyard, PERSIST, or MIND. That would erase the boundary being purchased or create a new high-privilege coupling. An external managed secret service could change the count, but its availability, identity, audit, and deployment assumptions are **not established** and it is outside this proposal.

## Required ADRs before implementation

Record explicitly that PERSIST is the sole physical storage executor; SWITCH owns no authoritative durable record; commands enter through CPCP; the commit-to-delivery handoff and retry model; SWITCH’s exact delivery guarantees; VAULT’s API, identity, rotation, and outage behavior; Switchyard’s versioning and dependency boundary; and the evidence required before merging BACK and BACKJOB.

**Bottom line:** split VAULT now; keep PERSIST authoritative; keep SWITCH bus-only and CPCP-mediated; keep seven containers until evidence supports consolidation; and reject the Rust durable-record reimplementation for now.

## References and verification

[1]: User-provided brief, “SWITCH as a Rust pub/sub bus, and a separate VAULT container,” including quotations attributed to the Rails Event Store README, `CLAUDE.md`, `mmg-durable`, `mmg-archive`, ADR 0045, and NVIDIA NeMo Switchyard upstream notes. Direct URLs and repository contents were not supplied; independent verification is **not established**.

This document answers the six requested questions directly and in order. It is an architecture recommendation, not authorization to build.

## Prompt traceability

The complete prompt was supplied in the attachment `pasted_content_dvSw038Oajezcp8cH65uDZ.txt`. The prompt required direct ordered answers, explicit “not established” markings where verification was unavailable, and blunt treatment of premature scope.
