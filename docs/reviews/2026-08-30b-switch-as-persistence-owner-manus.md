# Architecture Decision Memo: SWITCH as the Sole Path to SQLite and Oxigraph Persistence

**Status:** Exploration only. No authorization or implementation is implied.

## Scope note

The brief says “five numbered questions,” but it contains **six** numbered questions. This memo answers all six, in the order presented.

## Executive recommendation

**Do not make SWITCH the sole persistence service. Do not authorize implementation of the proposal as written.** Preserve the separation between the LLM plane and a persistence plane, while retaining one governed admission path for durable writes. The appropriate target is a dedicated persistence service or persistence plane that owns storage adapters and admission enforcement, with BACK remaining the sole application writer at the domain boundary. SWITCH should remain responsible for provider credentials and LLM-provider calls; it should not also own application and session data.

The single-admission-point argument is valid, but it does not require credential and data concentration in SWITCH. Put the admission point in the persistence plane, and make CPCP the protocol/contract at the existing pod seam rather than creating an additional independently authoritative write seam.

The general-purpose interface must be deliberately narrow: common lifecycle, authorization, identity, idempotency, audit, and transaction-envelope concerns may be shared; SQL and RDF query/update semantics must remain provider-specific. Session State and Application State should be separate applications or bounded contexts with different retention, consistency, deletion, and replay policies, even if they use the same persistence plane.

The work should **queue behind the current sequencing**. First finish the narrow Stage 2 CPCP contract, soak Step 10, and write tests/specifications. Only then decide whether a persistence plane is justified and define its contract.

## 1. Does concentrating provider credentials and all persistence in one service violate the separation that makes this pod defensible?

**Yes.** On the facts supplied, making SWITCH both the holder of every provider credential and the owner of all application and session persistence would materially weaken the separation that the current architecture relies on. It would combine the LLM plane, credential custody, persistence authority, admission control, and potentially application policy in one component. That is the exact class of “super-container” concentration the earlier review warned against.

The risk is not merely theoretical coupling. A compromise, outage, deployment error, authorization defect, or unbounded data-access capability in SWITCH would affect both provider credentials and durable application data. The brief establishes that SWITCH currently holds credentials and that it currently holds no application data; it does **not** establish the precise threat model, trust boundaries, database permissions, network policy, or failure isolation of the containers. Those details are therefore **not established**. They should not be used to argue that concentration is safe.

The recommended split is a **dedicated persistence plane**, separate from the LLM plane. That plane should contain the SQLite and Oxigraph adapters, storage-specific transaction/query logic, admission policy enforcement, audit/idempotency machinery, and the persistence API. SWITCH should continue to hold provider credentials and perform LLM-provider work. BACK should call the persistence plane through the governed pod seam.

This preserves the useful part of the proposal: one place can enforce closed-shape validation, trust-envelope checks, package identity, dependency closure, authorization, and write auditing. The admission point is centralized, but the blast radius is not needlessly combined with LLM credentials.

| Concern | Recommended owner | Reason |
|---|---|---|
| LLM provider credentials and calls | SWITCH | Preserve current LLM-plane boundary |
| Domain/application write authority | BACK | Preserve domain ownership and sole-writer meaning |
| SQLite/Oxigraph adapters and persistence admission | Dedicated persistence plane | Centralize durable-write enforcement without credential concentration |
| RDF projection | Persistence workflow under BACK authority | GRAPH remains a projection, not a source of truth |

A dedicated persistence service is itself a new component and therefore not free. Its necessity, resource boundary, and operational isolation are **not established** from the brief alone. But if the goal is both sole admission and separation, it is the coherent direction. Making SWITCH the persistence service is the wrong default.

## 2. What happens to “BACK is the sole writer”?

If SWITCH owns persistence and BACK becomes merely a client, the invariant is **lost unless “writer” is redefined at a level that still constrains behavior**. Calling BACK the “sole writer” while another service performs the actual durable writes would be semantic relabeling, not an invariant.

The invariant should be retained in a stronger, explicit form:

> **BACK is the sole domain-authorized writer; the persistence plane is the sole physical storage executor.**

This is a useful two-level invariant, not a contradiction. BACK owns domain decisions: which state transition is valid, which aggregate or application object may change, and what projection/update consequences follow. The persistence plane owns physical execution: opening the store, applying SQL or RDF operations, enforcing storage-level admission, committing, recording idempotency, and auditing.

The persistence plane must not accept arbitrary “write this SQL” or “execute this SPARQL update” requests from every container. It should accept typed, authenticated, authorized commands from BACK, with explicit package identity, dependency closure, trust envelope, shape/version, idempotency key, and actor/request context. Direct store access from other containers must be prohibited by configuration and tested as a negative invariant.

If the proposed design instead allows SWITCH to accept arbitrary persistence commands from multiple containers, then BACK is no longer the sole writer in any meaningful architectural sense. The proposal should be rejected in that form.

## 3. What is CPCP in this picture?

CPCP should be treated as a **protocol and contract implemented at the existing pod seam**, not as a second application-level persistence authority. The brief does not establish whether CPCP is currently packaged as a reusable library, a standalone service, or both. That implementation fact is **not established**.

The clean boundary is:

`container -> BACK /_cpcp/rpc -> persistence-plane command handler -> SQLite/Oxigraph adapter`

The exact deployment can vary, but the contract should not. BACK remains the pod’s contract seam and the only externally visible application write path. The persistence plane may be reached by BACK internally through a typed CPCP client or an internal adapter, but it must not create a second competing pod seam with independently accepted writes.

If SWITCH terminates CPCP-wrapped RPC directly, then one of two things happens. Either SWITCH becomes another authoritative seam, which conflicts with ADR 0045’s premise that CPCP is the Stage 2 SHAPE container at the only seam; or BACK becomes a forwarding proxy with no meaningful authority, which makes the existing seam ceremonial. Both outcomes are poor. They either create the second seam ADR 0045 was intended to avoid or hollow out the first one.

Therefore, **do not have SWITCH terminate persistence CPCP calls**. Keep CPCP termination at the established seam, and have the persistence plane expose an internal command boundary that is subordinate to it. Whether that internal boundary is a CPCP library invocation, a private RPC endpoint, or another mechanism is an implementation decision for the later specification; it is **not established** by the brief and should not be decided prematurely.

## 4. What must general-purpose persistence refuse, and what belongs outside the abstraction?

The persistence abstraction must refuse to pretend that SQLite and Oxigraph have the same data model. A lowest-common-denominator API would either leak provider semantics through supposedly generic methods or flatten both stores into an impoverished key-value model. Neither is acceptable.

The shared interface should cover only cross-provider control concerns: resource identity, tenant/application binding, authorization context, package and shape identity, dependency closure, idempotency, audit metadata, lifecycle, health, and explicit consistency/transaction boundaries. It may also expose capability discovery, so a caller can know whether a bound provider supports a requested operation.

The abstraction must refuse, by default:

1. Arbitrary SQL or SPARQL execution through a generic write endpoint.
2. A universal query language that claims relational joins and graph pattern matching are interchangeable.
3. Silent coercion between tables/rows and RDF triples/quads.
4. Implicit cross-provider transactions or atomicity claims.
5. Provider-specific features hidden behind lossy generic names.
6. Unbounded schema evolution, arbitrary migrations, or undeclared namespace/predicate creation.
7. “Read-your-writes,” snapshot, ordering, replay, or deletion guarantees unless explicitly supported and declared.
8. Binding multiple providers as though they were one coherent database when they have separate commit, failure, and recovery domains.

The acceptable failure is **explicit leakage**, not silent flattening. Provider-specific SQL and SPARQL operations should live behind separate typed capabilities or separate provider-specific APIs. The common layer should return “unsupported” rather than emulate semantics incorrectly.

For multiple bound providers, each provider must have a stable binding identity, model/schema identity, capability set, lifecycle, authorization scope, and failure/consistency contract. A transaction spanning SQLite and Oxigraph should not be promised unless a concrete atomic commit protocol is designed, implemented, and tested. Such a protocol is **not established** and is premature to assume.

A practical rule is: use SQLite for relational application state when relational constraints and transactions are required; use Oxigraph for graph-native projections or graph workloads. Keep the mapping and projection workflow explicit. GRAPH’s status as a projection and BACK’s authority must not be erased by a generic persistence facade.

## 5. Do Session State and Application State have the same persistence needs?

**No.** They should not be treated as one uniform application merely because both are “state.” The brief does not provide the current schemas, retention policies, concurrency requirements, or replay semantics, so the exact differences are **not established**. The architectural distinction is nevertheless necessary because the dimensions named in the brief commonly produce incompatible contracts.

Session State is usually scoped to an interaction or session. It tends to require bounded lifetime, expiry, rapid replacement, isolation by session/user/context, and carefully defined replay behavior. Application State usually has a longer lifetime, stronger domain invariants, durable identity, migrations, auditability, and deletion rules driven by business or tenancy requirements. Those are not interchangeable defaults.

Do not solve this by giving both applications a generic CRUD API. Define separate bounded contexts or application profiles over the persistence plane. They may share transport, identity, admission, and storage infrastructure, but they must declare their own retention, consistency, isolation, deletion, replay, and recovery policies.

| Dimension | Session State | Application State |
|---|---|---|
| Lifetime | Expiring and bounded | Durable and policy-governed |
| Consistency | Often session-scoped; exact guarantee must be declared | Domain invariants and durable transactions matter |
| Isolation | Session/user/context boundaries | Tenant, aggregate, and authorization boundaries |
| Deletion | TTL, logout, privacy, or session invalidation | Domain deletion, retention, legal/privacy policy |
| Replay | Conversation/event reconstruction may matter | Audit/event history and deterministic recovery may matter |
| Recommended API | Session-specific commands and reads | Domain-specific commands and queries |

The common abstraction should therefore be infrastructural, not semantic. The state applications must remain distinguishable at the contract level.

## 6. Is this the right time?

**No. Queue it behind the current sequencing.** The brief establishes that Step 10 has not soaked, the narrow Stage 2 contract is not built, and the last review authorized specification and tests rather than construction. This proposal changes ownership, seam semantics, persistence authority, and state contracts. It is therefore not a small follow-on implementation; it is a new architectural direction that depends on invariants the current shape arc has not yet demonstrated under soak.

The immediate work should remain specification and tests for the current Stage 2 shape. Add a short architecture spike only if it is needed to prevent the later decision from being blind: define the proposed persistence-plane boundary, write the two-level writer invariant, enumerate CPCP seam rules, and document provider capability boundaries. Do not build the general-purpose persistence service, bind multiple providers, or move SWITCH’s data ownership yet.

The decision gate should require evidence that:

- Step 10’s current invariants survive soak testing.
- The Stage 2 CPCP contract is narrow, testable, and remains the only pod write seam.
- BACK’s domain-authorized-writer role is expressible and enforceable.
- Direct writes from non-authorized containers are rejected.
- SQLite and Oxigraph failure, retry, idempotency, and projection behavior are specified.
- Session and Application State contracts are separately defined.
- Any cross-provider consistency claim is either implemented and tested or explicitly disclaimed.

Until those conditions exist, the proposal is premature. The correct current decision is **reject SWITCH as the persistence owner, preserve the existing sequencing, and investigate a separate persistence plane as a later architectural option**.

## Decision summary

| Decision | Recommendation |
|---|---|
| SWITCH owns all persistence | Reject |
| Dedicated persistence plane | Investigate as the preferred direction |
| BACK remains domain-authorized sole writer | Preserve and formalize |
| Persistence plane is sole physical storage executor | Allow, under BACK-issued typed commands |
| SWITCH terminates persistence CPCP | Reject |
| One generic SQL/RDF semantic API | Reject |
| Shared infrastructure for Session/Application State | Allow |
| Uniform state semantics and CRUD contract | Reject |
| Build now | Reject; queue behind Stage 2 specification, tests, and Step 10 soak |

## References

[1]: /home/ubuntu/upload/pasted_content_dFWpqowebaFn1QcIiQi865.txt "User-supplied architecture brief"

> All architectural facts in this memo are taken from the user-supplied brief. No repository access or external verification was available; claims dependent on unseen code or deployment configuration are marked **not established**.

## Original brief

The original brief is reproduced in the attached source file referenced above. The central established constraints were: BACK is the sole writer; `/_cpcp/rpc` is the only pod seam; SWITCH holds provider credentials; GRAPH is a projection; ADR 0045 identifies CPCP as the Stage 2 SHAPE container; and the proposed change is exploratory only.
