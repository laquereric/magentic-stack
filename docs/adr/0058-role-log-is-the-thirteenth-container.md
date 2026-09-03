---
id: "0058"
title: ROLE=LOG is a thirteenth container, and OTEL is the basis for its CPCP contract
status: accepted
date: 2026-08-31
subject_kind: topology
subject: LOG
components: [log, back, backjob, mind, switchyard, bus]
paths:
  - runtimes/mind-pod
enforced_by: []
stand_in:
  - gems/rails-cpcp/lib/rails_cpcp/refusal_log.rb
unenforced: true
unenforced_because: "ROLE=LOG is decided, unbuilt (row 86). The gap table is not a gate. stand-in is the local refusal floor LOG will govern"
supersedes: null
superseded_by: null
---

# ROLE=LOG

## Decision

1. **A thirteenth container, `ROLE=LOG`.** Under ADR 0047 that makes it a tenth
   role on the Rails image.
2. **OTEL is the basis for a CPCP contract governing writes from the other
   containers.**

Target becomes **13 containers, 4 images**.

## The condition this rests on, from `2026-08-31c`

Manus answered the floor question hours before this decision, and its answer
names LOG explicitly:

> The container should record the refusal first in a **local, append-only,
> structured record whose write path has no remote peer dependency. That local
> record is the floor.** The event store, OpenTelemetry export, metrics backend,
> **and any future `LOG` service** are higher layers and may be unavailable
> without making the refusal disappear.

So LOG is compatible with the rule **only if the local floor stays**. `LOG` is
the **governed aggregation path**; it is not where a refusal is first written.

**If a container's only record of a refusal is the one it sent to LOG, then a
refusal about LOG has nowhere to go and we have rebuilt the regress one level
up.** That is the failure this ADR must not cause.

## Why OTEL as the basis, and what "basis" means

OTEL is the only observability standard with first-class SDKs across all three
languages we write — Ruby, Python, Rust. That is the same cross-language
constraint that ruled out sentinels for the envelope.

"Basis for a CPCP contract" means the contract's **shape is derived from OTEL's
log data model** — timestamp, resource identity, optional trace context,
severity, body, event name, attributes — rather than invented. Per ADR 0048 the
language-neutral half of a CPCP contract is SHACL, so the work is: OTEL data
model → shapes → methods.

Adopting the vocabulary is not the same as adopting the transport. Manus is
explicit that OTEL is the vocabulary and aggregation layer, **not** the floor.

## Four things not settled here

1. **Volume.** CPCP is a governed request/response seam with `operationId`,
   idempotency and receipts. Logs are high-volume and fire-and-forget. Whether
   every refusal can afford an admitted operation is **not established**, and a
   seam that falls over under load is a poor place to report that things are
   falling over.
2. **Correlated failure.** LOG on the Rails image shares a lineage with nine
   other roles (ADR 0047 amendment 1). A bad Rails deploy takes out LOG and most
   of what it collects — the same objection that disqualified `bus` as the final
   observation point in ADR 0054.
3. **Seam count.** This makes **six**: BACK, MIND, SwitchYard, bus, vault, LOG.
   Five still have no stated authority (gap 20).
4. **The floor is still unbuilt as a durable thing.** `RefusalLog` writes JSONL
   plus a heartbeat, and Manus marks it **not established** that any particular
   configuration survives a full disk, a crash, a permission failure or host
   loss. LOG does not fix that; it sits above it.

## Answered: OTLP carries the volume, CPCP governs the contract

`docs/archive/reviews/2026-08-31d`. Manus was given explicit permission to say CPCP was
the wrong transport, and took it.

> Keep the thirteenth `ROLE=LOG`, but do **not** put ordinary log volume through
> the per-record CPCP admitted-operation path. Use **OTLP as the volume
> transport** and make **CPCP the governed contract**: its method/schema
> identity, admission policy, refusal semantics, and receipt rules.

So the volume concern above is real and the answer is to split transport from
contract. Five stages, and **the local append happens before any network**:

    1. construct the event
    2. append locally, no network dependency
    3. export asynchronously over OTLP
    4. LOG validates the CPCP/SHACL profile and aggregates
    5. optional backend beyond LOG

### Correlated failure: confirmed, and it bounds the claim

> **Shared lineage disqualifies LOG as the sole final observation point, but
> does not disqualify LOG as an aggregation path.**

The claim LOG is allowed to make is therefore deliberately weaker:

> LOG improves aggregation, queryability and cross-role correlation **when the
> shared lineage is healthy**; it does not provide independent evidence that the
> shared lineage failed.

ADR 0054's final observation point is still open, and LOG does not close it.
Something outside the Rails image is still required for high-value evidence.

### An adapter boundary we are inventing, flagged by Manus itself

**OTEL LogRecords are not RDF graphs.** The OTEL-to-SHACL representation is
*proposed by that memo*, not derived from OTEL and not mandated by it. "OTEL as
the basis" therefore means we author a vocabulary at that seam and own it.

### The test that is not premature at our size

> At one pod and a few sessions it is premature to build redundant LOG
> infrastructure. **It is not premature to test the failure-domain claim:** kill
> LOG, break the shared Rails image, fill the LOG quota, remove network
> reachability, restart the producer. The expected invariant is that the
> producer's local first record survives each.

## Ruling: do not reformat OTEL

`2026-08-31d` proposed an OTEL-to-SHACL representation and flagged, against its
own proposal, that OTEL LogRecords are not RDF graphs. Settled the other way:

> **Do not reformat OTEL. Use SHACL only for required NEW metadata. Prefer no
> new metadata.**

An OTEL LogRecord stays an OTEL LogRecord, native and untranslated. **We do not
build a translation layer**, so gap 88 -- a vocabulary we would have had to
author and own at that seam -- does not arise.

### What this leaves

The test for every proposed field is: **does OTEL already carry this?** Most of
the restoration-grade table does. `Timestamp` and `ObservedTimestamp`,
`Resource`, `SeverityNumber`/`SeverityText`, trace context, `Body`, event name,
scope version -- all native.

What is genuinely new is the restoration semantics: `state_reached`,
`inconsistency`, `restore_when`, `restore_action`, and possibly attempt/retry
state. Fewer keys is better.

And "new metadata" here means **a new attribute KEY, not a new format** -- OTEL
attributes are arbitrary key-value, so SHACL constrains the values of keys we
define while the record stays OTEL-shaped.

### Why the default is nothing

Every field we invent is a field we own, version, and must keep true. In one day
this repository produced: a system prompt false about persistence, the same
prompt false about the graph, a stale compose header, a column that could not
express a denial, and a fraction repeated four times that compared unlike
things. Each began as a reasonable-looking field or sentence.

**A field OTEL already defines is one we do not have to keep true by hand.**
