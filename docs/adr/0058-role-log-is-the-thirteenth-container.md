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
