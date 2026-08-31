---
id: "0056"
title: BACK and BACKJOB are the sole writers of domain state
status: accepted
date: 2026-08-31
subject_kind: doctrine
subject: domain state writers
components: [back, backjob, persist]
paths:
  - runtimes/mind-pod/app
enforced_by: []
supersedes: null
superseded_by: null
---

# BACK and BACKJOB are the writers

## Decision

**BACK and BACKJOB are the sole writers of domain state.** Plural.

This closes gap 2 as a **declaration, not a fix**. `bin/backjob:37`
`Reconciliation.create!` stops being a violation and becomes a declared
co-writer's legitimate write. Gap 1 — both roles mounting `mind-data` — becomes
the correct arrangement rather than a defect.

It also departs from `2026-08-30c`, which held that no two independently failing
production roles should share a writable domain-storage volume. That was advice;
this is a decision, and the memo did not know the roles were siblings of one
application.

## "Sole writers" only means something if it says who writes what

Two declared writers with no division is just two writers. The word *sole* is
doing work only if the split is stated: today BACKJOB writes `Reconciliation`
and nothing else, and everything else is BACK's.

**That is my reading of current behaviour, not a rule anyone has written.** It
should be stated and gated, or the next write BACKJOB adds will be legitimate by
precedent rather than by decision.

## Two operational facts this now depends on

### 1. WAL is on by the adapter's default, not by our declaration

The live domain database reports `journal_mode = wal`. But **nothing in our
tree sets it**: `config/database.yml` declares only `adapter`, `pool` and
`timeout: 5000`. The single `PRAGMA journal_mode=WAL` in the codebase
(`idempotency.rb:41`) belongs to a *different* database.

So WAL is arriving from the Rails sqlite3 adapter's defaults. Under one writer
that was luck we did not need. Under two writers **it is load-bearing**, because
rollback-journal mode makes concurrent writes fail far harder.

We should declare it rather than inherit it. A property this decision depends on
should not be a default someone else can change.

### 2. The multi-writer failure mode lands in a rescue that prints

SQLite permits one writer at a time even in WAL. `timeout: 5000` means the
second writer waits up to five seconds, then raises `SQLITE_BUSY`.

In BACKJOB that exception reaches the loop's `rescue StandardError` and is
**printed**. So lock contention would look like every other backjob error, and
the thing we would most want to know about a two-writer arrangement is the thing
least likely to be noticed. That is gap 63's pattern arriving at the defect this
ADR creates.

Contention is currently low — BACKJOB writes on an 8s interval, BACK on request —
but low is not zero, and "low" is not a property anything measures.

## The prose is now false, again

Every statement in the tree says **BACK is the sole writer**, singular —
`routes.rb`, the compose header, MIND's system prompt, and several ADRs
including 0052 and 0055.

That is the **third** time today that prose has outlived the code it described:
MIND's persistence claim, MIND's graph claims, and now this. Fixing these one at
a time is how we got here. It wants a sweep, not another patch.
