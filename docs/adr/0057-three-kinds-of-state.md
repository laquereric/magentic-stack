---
id: "0057"
title: Three kinds of state, three owners, and the mission is the division itself
status: accepted
date: 2026-08-31
subject_kind: doctrine
subject: state ownership
components: [back, backjob, bus, mind]
paths:
  - runtimes/mind-pod
enforced_by: []
supersedes: null
superseded_by: null
---

# Three kinds of state

## The mission

**The architecture's mission is to provide explicit divisions.** Not to minimise
containers, not to unify languages, not to reduce moving parts. Those are
consequences or costs. The division is the product.

## The three

| Kind | Owner | Character |
|---|---|---|
| **Application state** | BACK and BACKJOB (ADR 0056) | deterministic; the domain record |
| **Metadata** | BUS, via RES (ADR 0055) | deterministic; source of truth for what happened |
| **Ephemeral nondeterministic inference state** | MIND's SQLite | **nondeterministic**; the inference plane |

MIND's store is **a third kind**, not a private copy of the first. That is the
whole point. The first two are the **deterministic plane**; the third is where
nondeterminism is allowed to live. This is the Flexible Determinism split —
causation explicit at a defined plane, opaque at the emergent level — expressed
as storage ownership rather than as a principle.

## What this corrects, in my own words at 030af95

When NOOA's SQLite was bound I wrote, twice:

> MIND does keep **durable** memory of its own
> You may carry **durable** memory across sessions

**"Durable" is the wrong word**, and wrong in the direction that matters. It
invites the model to treat its own store as persistent and truth-adjacent, which
is the inverse of the division. I was describing the binding mechanism and not
asking what kind of state it held.

What survives from that commit, because it holds under this division:

> nothing in it is true of the pod merely because you remember it
> a memory you cannot ground is a lead, not a fact

## A fourth audit verdict

The MIND prompt audit (gap 62) was checking TRUE / FALSE / ASPIRATIONAL. This
ADR adds:

> **MISCLASSIFIED** — roughly true, but names the wrong KIND of thing, and
> therefore teaches a wrong division.

That bucket is the interesting one. **A statement that is factually accurate and
categorically wrong is worse than one that is plainly false**, because nothing
will ever contradict it. "Durable memory" is the first entry.

## The open question this raises about the volume

`mind-nooa-data` is a **named volume**: it survives a restart and dies on
`down -v`. If MIND's state is *ephemeral*, that choice deserves re-examination —
it may be the volume that is wrong rather than the word.

The reasoning at the time was that agent memory is not a credential and `down -v`
is meant to clear it, plus NOOA's own virtiofs warning. That reasoning is intact.
What was never asked is whether the state should survive a **restart** at all.
**Not established; do not change the volume on the strength of this ADR.**

## The third category needs splitting (Manus, 2026-08-31b)

The operator extended PERSIST's placement authority to MIND's store, and NOOA
will over time keep continuous inference state with stop/restore through KV
cache. That breaks **the name and implied lifecycle** of "ephemeral", though not
the three-owner division.

| Subcategory | Meaning | Treatment |
|---|---|---|
| **transient inference state** | droppable, recomputable | may stay ephemeral |
| **durable inference artifact** | persisted, restorable, resumes a continuation | versioned, attestable, admitted **fail-closed** |

> **Durability changes how long an artifact exists and how it must be admitted;
> it does not change who owns the truth.**

A durable artifact does not become application state or metadata by being on
disk. It stays non-authoritative and still may not write domain state.

And a distinction that had not occurred to me: **placement is not admission.** A
valid path from PERSIST can contain stale, incompatible, incomplete or unsafe
state. PERSIST says where; something else must say whether it may be consumed.

This also settles gap 82 in principle: surviving a restart is the *point* of
stop/restore, so the named volume is not the error. The word was.
