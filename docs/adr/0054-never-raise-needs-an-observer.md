---
id: "0054"
title: A never-raise boundary must make its refusals observable
status: accepted
date: 2026-08-31
subject_kind: doctrine
subject: never-raise refusals
components: [rails-cpcp, rails-osi-level-8, vv-graph, backjob]
paths:
  - gems
  - runtimes
enforced_by:
  - tooling/cpcp/check_refusal_observer.py
supersedes: null
superseded_by: null
---

# Never-raise needs an observer

## The rule

**A never-raise boundary must make its refusals observable by something other
than a human reading output.** Returning `{ok: false, reason:, because:}` or
`:error` and printing it is not observation. If the only way to notice is for
someone to be watching stdout at the time, the refusal is not observed.

The never-raise envelope itself is **not** the defect and is not being changed.
A boundary that raises into its caller is worse. The defect is that we built
the half that says "no" carefully and never built the half that listens.

## Why: three instances in one day, each found by accident

| | Boundary | What it returned | How it was found |
|---|---|---|---|
| 1 | `backjob` → BACK's CPCP seam | `{ok:false, reason:"backjob_cpcp_error"}`, printed | I read the compose file for an unrelated reason. The completion path had been dead **for weeks**. |
| 2 | P6 admission | nothing — the column could not express a denial | grok read the code while writing a protocol document |
| 3 | `Publisher::Immediate#schedule` | `:error`, discarded | grok read the code while investigating an empty graph |

None was found by the system. Each was found because a person happened to be
looking somewhere nearby. That is the pattern, and it is why this is doctrine
rather than three bug fixes.

## The distinction that decides the design

There are **45** `rescue StandardError` sites in our Ruby. They are not the same
kind of thing, and treating them alike would replace silence with noise — which
fails the same way, just louder.

| | Meaning | Needs an observer |
|---|---|---|
| **Refusal** | a boundary told a caller **no**; a decision was made and the caller may need to act | **yes** |
| **Fallback** | internal code chose a default; no caller decision is implied (e.g. `app_name` rescuing to a literal) | no |

Only refusals are in scope. A census that classifies all 45 comes **before** any
mechanism — the same discipline that made ADR 0052 work, where counting first
turned a migration into a decision.

## What "observable" must mean

Not specified here beyond the floor:

- something **other than a human reading logs** can see it — a gate, a health
  surface, or a durable record;
- it survives the process that produced it, or is aggregated somewhere that
  does;
- and a refusal that has never been seen is distinguishable from no refusal
  having occurred. **Absence of evidence must not read as evidence of absence**
  — the same rule ADR 0052 reached for `indeterminate`.

The journal is the obvious candidate for refusals that have an operation
context; it is append-only and already carries a `refused` kind. Refusals with
no operation context need somewhere else. Deciding that is the next step, not
this one.

## Scope

Ruby first. MIND is Python and SwitchYard will be Rust; whatever this becomes
has to cross those boundaries eventually, and a mechanism that cannot is the
wrong one. But it is not solved for three languages before it is solved for
one.

---

# Limit found while reviewing the 8 UNCLEAR (2026-08-31)

The Manus review (`docs/reviews/2026-08-31a`) returned one finding that bounds
this ADR rather than implementing it:

> There is no mechanism that can guarantee external observation if every
> observer and every independent persistence path fails. That is a **reliability
> boundary, not a Ruby idiom.**

So the answer to "what watches the watcher" is not another watcher. It is a
**bounded chain with a stated final observation point**: boundary refuses →
recorder attempts a synchronous write to an independent durable sink and returns
its own `{ok:false, reason: "observation_failed"}` → a health signal makes
recorder degradation visible → and something outside the process retains the
record.

**That last link is not established to exist here.** No supervisor or platform
is identified in our topology that watches a health surface and retains durable
records. Until one does, **this ADR's strongest guarantee cannot be fully met**,
and a mechanism claiming otherwise would be asserting a property it does not
have — which is the failure this ADR exists to stop.

What can be met now: a refusal reaching a durable record, and a recorder that
reports its own failure instead of swallowing it. What cannot yet: proving that
record was ever read by anything.

## Does the SWITCH ecosystem's Rails RES meet the final observation point? NO

Asked directly, 2026-08-31. The answer matters because it is the difference
between this ADR being satisfiable today and not.

**A durable store is not an observer.** The final layer has two jobs — RETAIN
and WATCH. RES does the first well and the second not at all.

| | RES in `ROLE=bus` |
|---|---|
| Survives the process that refused | **yes** — different container, append-only, queryable. Better than our JSONL. |
| Notices that a refusal never arrived | **no.** Silence in an event store is indistinguishable from no events. |

That is the distinguishability problem moved one hop, not solved. Making the bus
*expect* heartbeats and complain about their absence is a different capability
from storing events, and it does not come with RES.

It also **adds** a failure mode: the recorder's write becomes a network call, so
the bus being unreachable looks exactly like nothing having happened.

### The disqualifying property: correlated failure

Under ADR 0047 amendment 1, **one Rails image serves nine roles** — `bus`
included, alongside `back`, `backjob`, `vault` and the rest. Hot-patch
granularity is four units.

So a bad Rails deploy takes out the refuser **and** the recorder at the same
time, and the refusals generated during that failure are precisely the ones that
cannot be recorded.

**A sink must not share a failure domain with the thing whose refusals it
records.** And the sharper version: **a refusal ABOUT the bus has nowhere to
go** — the same shape as the publisher that cannot reach oxigraph, one level up.

### What would meet it

Something in a different failure domain: the MIND image (Python), SwitchYard
(Rust), the third-party oxigraph container — or, most honestly, something
**outside the pod**: a CI gate reading an artifact, a supervisor, or an operator.

**The truthful position is that the final observation point is necessarily
outside the pod.** RES is a better layer-2 sink than our JSONL. It is not
layer 4, and adopting it must not be recorded as having closed this gap.

## Reframed by ADR 0055: refusals are per-container health

ADR 0055 says a container's refusals are a signal about **that container's**
health and quality, not about the system.

That is a better frame than the one this ADR was written in, and it dissolves
part of the observer problem: a health surface is naturally per-container and
needs no single global watcher. The refusal log landed at `fb41771` is that
container's health signal.

It does **not** dissolve the rest. Something must still notice a container that
has gone quiet, and **a missing heartbeat is not zero refusals**. Per-container
health makes the signal legible; it does not make anything read it.
