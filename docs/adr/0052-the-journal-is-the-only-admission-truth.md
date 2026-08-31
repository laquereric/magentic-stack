---
id: "0052"
title: admission_status is removed; the operation journal is the only admission truth
status: accepted
date: 2026-08-31
subject_kind: data
subject: OperationRequest admission
components: [rails-osi-level-8, backjob]
paths:
  - gems/rails-osi-level-8/lib/rails_osi_level_8
  - runtimes/mind-pod/app/bin/backjob
enforced_by: []
supersedes: null
superseded_by: null
---

# The journal is the only admission truth

## Decision

**Remove `OperationRequest#admission_status`.** Admission is derived from the
operation journal, which is append-only and already records the real decision.

## Why the column could not be fixed in place

It is not that the column holds a wrong value. It is **structurally incapable of
holding the right one**:

- `cpcp_adapter.rb:275` writes `admission_status: "admitted"` when the row is
  created — **before** `Authorization.admit!` has run.
- The P6 denial path (`:127-132`) appends a `refused` journal entry and re-raises.
- `:113` deliberately declines an outer transaction so that deny evidence
  survives the refusal. **So the row persists, saying `admitted`.**
- `operation_request.rb:20` declares `inclusion: { in: %w[admitted refused] }`,
  but **all three write sites write `"admitted"` and nothing in the tree ever
  writes `"refused"`.** The value is declared and unreachable.

A column written before the decision it purports to record is not a status. It
is a constant with a status's name.

## Why this was not cosmetic

`bin/backjob:42` selects on exactly that predicate to decide what receives an
`l8.execution.complete`:

    .where(operation_name: "note.create", admission_status: "admitted")

**A P6-denied `note.create` was therefore eligible to be completed.** The replay
lookup filters the same column, so a denial could also serve as a prior admitted
operation.

## The derivation

An operation is **admitted** when its journal has an `authorized` entry and no
`refused` entry.

The journal's kinds are `received`, `grounded`, `authorized`, `refused`,
`response_refused`, `routed`, `dispatched`, `completed`.

**`response_refused` is not `refused`.** One is a refused *response*, the other a
refused *admission*. Conflating them would reintroduce the same class of error
this ADR exists to remove.

The derivation lives in **one place** on the model, so both readers share a
definition rather than each carrying a predicate.

## What must be established before the column is dropped

The column is being removed because it cannot express a denial. But it is still
data, and dropping it in SQLite rebuilds the table.

1. **Can the journal answer for every existing row?** Rows with neither an
   `authorized` nor a `refused` entry become **unclassifiable** once the column
   is gone. Count them first. If there are any, they are a migration problem,
   not a rounding error.
2. **Dump before drop, and gate the drop on the count just read.** This is a
   live table with durable rows. Printing a count and then dropping
   unconditionally is how rows get lost.
3. Losing the column loses nothing recoverable: it says `admitted` for every
   row, including the denied ones. The journal is strictly more informative.

## The one thing that may not be free

The replay lookup is on the request hot path. A column predicate becomes a
journal join. Whether that is acceptable is a **measurement**, not an
assumption — and if it is not, say so rather than keeping a lying column for
speed.

---

# Amendment: three states, and the two historical rows are backfilled

Step 1 found two classes the two-state derivation could not answer (gaps 56,
57). The owner's decision: **three states, and backfill the two rows.**

## Not a boolean

An `admitted?` predicate inherits the column's flaw: it cannot distinguish
**absence of evidence** from **evidence of denial**. A reader seeing `false`
will eventually read it as "denied".

| State | Meaning | Determined by |
|---|---|---|
| `admitted` | P6 permitted it | an `authorized` entry, no `refused` entry |
| `refused` | P6 denied it | a `refused` entry (**never** `response_refused`) |
| `not_an_admission` | the operation never enters the P6 path | a **declared list** of operation names |

## `not_an_admission` is a positive property, never a fallback

This is the part that decides whether the fix holds.

If `not_an_admission` is the else-branch — "no journal evidence, so it must not
have been an admission" — then it becomes the new home for absence of evidence
and **we have rebuilt the defect with a better name.**

It is therefore determined by a **declared list of operation names that bypass
P6**. Today that list is exactly `l8.execution.complete`, which `P7Commands`
creates outside the admission path (gap 56).

## Which implies a fourth state, and it must be loud

| State | Meaning | Required population |
|---|---|---|
| `indeterminate` | the operation IS in the admission path, and the journal has neither `authorized` nor `refused` | **zero** |

`indeterminate` is not a classification we live with. It is an alarm. After the
backfill it must be empty, and a checker must assert it stays empty — otherwise
the next `p7_commands`-shaped bug lands silently, which is precisely how gap 52
survived this long.

## The backfill must be marked as a backfill

The two rows in `runtimes/mind-pod/app/db/mind_pod.sqlite3` (gap 57) get an
`authorized` journal entry.

**It must be visibly distinguishable from a real authorization.** This system's
value is that admission is auditable; writing an entry that claims P6 permitted
something P6 never saw would be a worse defect than the one being fixed — it
would be forged evidence rather than missing evidence.

The entry carries, in `detail_json`, at minimum: that it is a backfill, the
reason (the rows predate P6), the ADR that authorized it, and when it was
written. A reader must be able to tell, forever, that no authorization decision
was actually made for these rows.

## Gap 56 is not fixed here

Declaring `l8.execution.complete` as `not_an_admission` makes ADR 0052
implementable. It does **not** address whether `p7_commands.rb:151-165` writing
the `completed` entry onto the parent's cid is itself correct — a complete row
with no journal of its own is still a record that cannot describe itself. That
remains open as gap 56.
