---
id: "0053"
title: An l8.execution.complete row journals itself
status: accepted
date: 2026-08-31
subject_kind: data
subject: OperationRequest journalling
components: [rails-osi-level-8]
paths:
  - gems/rails-osi-level-8/lib/rails_osi_level_8/p7_commands.rb
enforced_by: []
supersedes: null
superseded_by: null
---

# A complete row journals itself

## Decision

**`l8.execution.complete` rows get their own journal.** Closes gap 56.

Today `p7_commands.rb:151-165` creates an `OperationRequest` for the complete
and then writes the `completed` entry with `operation_request_cid: op_cid` --
the **parent** `note.create`'s cid -- taking `seq` from the parent's journal.
The complete row it just created gets nothing. Measured: the one existing
complete row in the host database has **zero** journal entries of its own.

A durable record that cannot describe itself is not a record. It is a row.

## Additive, not a rewrite

**The parent keeps its `completed` entry.** That the note.create was completed
is a true fact about the note.create, and it is where a reader following the
parent's history would look for it. Removing it would change the meaning of
every existing parent row.

The complete row gains its own entries. Nothing moves.

## This does NOT make a complete an admission

**`NOT_AN_ADMISSION_NAMES` stays exactly as it is.**

A complete will now have journal entries, but it will still have no
`authorized` and no `refused`, because it never enters the P6 path. Removing
it from the declared list on the grounds that "it has a journal now" would make
every complete `indeterminate`.

The gate from ADR 0052 would catch that, which is the point of having it. But
it is worth stating rather than discovering: **self-description and admission
are different properties.** Gap 56 was never evidence that completes are
admissions; it was evidence that they were invisible.

## Constraints

- **`seq` comes from the complete's own journal**, not the parent's. The table
  has a unique index on `cid` only -- there is no uniqueness on
  `(operation_request_cid, sequence)` -- so nothing in the database will catch
  a sequence collision. The code has to be right.
- **Append-only.** `osi_l8_operation_journal_entries` carries `BEFORE UPDATE`
  and `BEFORE DELETE` triggers that `RAISE(ABORT)`. Every change here is an
  insert.
- **The one existing complete row is backfilled**, marked as a backfill in the
  same style ADR 0052 required: what it is, why, the ADR, and when. A reader
  must be able to tell that these entries were reconstructed rather than
  recorded at the time.

## What a complete's journal should say

Not specified here beyond the requirement that the row can describe its own
lifecycle without reference to its parent. `received` at creation is the
obvious floor. Whether it also carries its own `completed`, given the parent
already has one, is an implementation judgement -- but a reader holding only
the complete's cid must be able to learn that it happened.

## Correction to "Constraints": the database DOES catch a sequence collision

This ADR said the unique index is on `cid` alone and that "nothing in the
database will catch a sequence collision". **That is wrong.**

    idx_osi_l8_journal_req_seq
      UNIQUE (operation_request_cid, sequence)

The error was mine and it was a query, not a reading: I listed indexes with
`WHERE name LIKE '%operation_journal%'`, which matches four of the six and
silently misses the two named `idx_osi_l8_journal_*`. The constraint I said was
absent has been there all along.

The requirement that `seq` come from the complete's **own** journal still
stands, and for a reason the index does not cover: taking `seq` from the parent
yields the tuple `(complete.cid, parent_seq + 1)`, which is fresh and collides
with nothing. The index protects against inserting the same sequence twice on
one record; it cannot protect against a sequence that is simply wrong.
