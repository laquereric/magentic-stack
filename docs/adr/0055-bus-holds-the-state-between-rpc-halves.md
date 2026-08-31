---
id: "0055"
title: BUS holds the state between the two halves of an RPC call and maintains integrity
status: accepted
date: 2026-08-31
subject_kind: doctrine
subject: BUS charter
components: [bus, back, mind, switchyard, rails-cpcp]
paths:
  - gems/rails-cpcp
  - gems/rails-osi-level-8
enforced_by: []
supersedes: null
superseded_by: null
---

# The BUS charter

## Decision

1. **BUS is the holder of state between the two halves of an RPC call.** It *is*
   Rails Event Store.
2. **Integrity is maintained by BUS.**
3. **Refusals a container has are a signal about THAT CONTAINER's health and
   quality**, not about the system.
4. **Participants in BUS JSON-RPC-LD conversations may require recompilation and
   redeployment when BUS imposes a change.**
5. **An envelope refusal must carry enough semantic content for an intelligent
   agent — AI or human — to decide how to RESTORE a broken process.**

## (3) reframes what we built today

ADR 0054 treated refusals as a system-wide observability problem and asked what
watches them. Under this charter they are **per-container health telemetry**: a
container producing refusals is telling you about its own condition.

That is a better frame and it dissolves part of the observer question. A health
surface is naturally per-container; it does not need one global watcher. The
refusal log landed at `fb41771` becomes that container's health signal rather
than a system ledger.

What it does **not** dissolve: something must still notice a container that has
gone quiet. See ADR 0054 — a missing heartbeat is not zero refusals.

## (5) raises the bar on the envelope, and we do not meet it yet

Today a refusal is `{ok: false, reason:, because:}`. `reason` is a stable symbol;
`because` is prose. That is enough to say **what failed**. It is not enough to
decide **how to restore**.

A restoration decision needs, at least: what was being attempted, what state it
had reached, what is now inconsistent, and what would make it consistent again.
None of that is in the envelope, and `RefusalLog` records `reason`, `because`,
`source`, `method` and `operation_id` — which identifies the call but not its
state.

**This is a gap, not a completed decision.** What "enough semantic content"
means has to be specified before it can be built or gated.

## Three tensions this creates, named rather than resolved

### A. Two integrity authorities

Every existing statement says **BACK is the sole writer of domain state**. This
ADR says **integrity is maintained by BUS**. Those are compatible only if they
govern different things — BACK owning *domain* integrity and BUS owning
*conversation and protocol* integrity. That split is the obvious reading and it
is **not yet stated anywhere**. Until it is, "integrity" has two owners and a
reader cannot tell which one a given rule belongs to.

### B. BUS becomes a runtime dependency of every call

If BUS holds the state between the halves, then it is not an asynchronous
side-channel — it is **in the path of every RPC**. Today `/_cpcp/rpc` is a
synchronous POST that BACK completes by itself.

So: can any call complete while BUS is down? If not, this materially changes the
pod's availability story, and it puts BUS in the same position `vault` is in for
credentials. **Not established.**

### C. What state actually moves

The two halves of an L8 call today are **admission** and
`l8.execution.complete`. The state between them is the `OperationRequest` row
plus its journal, in BACK's SQLite — which is exactly what ADRs 0052 and 0053
spent this day correcting.

If that state moves to BUS, those two ADRs describe the right invariants in the
wrong place, and the admission journal leaves BACK. **That is my reading of
"holder of state between the two halves" and it should be confirmed or corrected
before anything is built** — it is a much larger change than adding a bus.

## (4) needs a mechanism, and we have most of one

"Participants may require recompilation and redeployment" is a **versioned
contract**: a participant has to be able to tell that a BUS change affects it,
rather than discovering it at runtime. MIND is Python and SwitchYard is Rust, so
this crosses images and languages — a Rails-only mechanism will not do.

We already have the pieces: content-addressed identity (`cid`), SHACL as the
language-neutral data contract, and gates that fail closed. What is missing is a
statement of which BUS changes are breaking, and a gate that refuses a
participant pinned to a superseded contract.

## Amendment: who records, and who handles

Two further clauses, 2026-08-31:

> **RES (inside BUS) records successes AND failures.**
> **BACK and MIND are responsible for how build-time alignment and runtime
> refusals are handled.**

### The division this completes

| | |
|---|---|
| **BUS records** | successes and failures both, in RES. It is the metadata source of truth (ADR 0057) and does not act on what it records. |
| **BACK and MIND handle** | build-time alignment (clause 4's recompilation) and runtime refusals. |

So recording and handling are **different jobs with different owners**. That
closes gap 71: BACK writes domain state, BUS is the source of truth for
metadata, and neither is "integrity" in the abstract.

Note the two named handlers are **BACK and MIND** — not BACKJOB, not SwitchYard.
MIND being a handler fits ADR 0057: it is the nondeterministic plane, and coping
with a refusal is exactly the kind of judgement that belongs there rather than in
a deterministic writer.

### What this does NOT settle

RES recording failures makes it a **sink**. ADR 0054's open question is about a
**watcher**, and those are still different:

- Silence in RES is indistinguishable from no failures, unless something expects
  a heartbeat.
- `bus` shares one Rails image with eight other roles (ADR 0047 amendment 1), so
  a Rails-lineage failure takes out the recorder and most of what it records.
- A refusal **about BUS** still has nowhere to go.

RES is a better layer-2 sink than the JSONL landed at `fb41771`. It is not the
final observation point, and adopting it must not be recorded as having closed
ADR 0054.
