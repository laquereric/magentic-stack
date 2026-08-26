---
id: "0032"
title: The grounding refusal is enforced by specs, and rollback survives nesting
status: accepted
date: 2026-08-26
subject_kind: gem
subject: mmg-graph
components: [mmg-graph]
paths:
  - gems/mmg-graph/lib
  - gems/mmg-graph/app/models/mmg/graph/entry.rb
  - gems/mmg-graph/app/services/mmg/graph/execute.rb
enforced_by:
  - gems/mmg-graph/spec/execute_spec.rb
  - gems/mmg-graph/spec/cpcp_spec.rb
  - gems/mmg-graph/spec/entry_spec.rb
  - gems/mmg-graph/spec/actions_spec.rb
supersedes: "0011"
superseded_by: null
---

## Context

ADR 0011 recorded that `publish` refuses a bare graph name, and recorded honestly
that nothing checked it -- the gem had no spec suite at all. The invariant that
makes every node in this graph reproducible from a row was held by reading.

## Decision

The rule from ADR 0011 stands unchanged and is now enforced by 32 examples.

The suite is **hermetic**: `MM_OXIGRAPH_URL` points at a closed port. Every
refusal this gem is built on happens *before* any HTTP call, so nothing needs a
live store -- and a suite that needs one is a suite that gets skipped. The
closed port doubles as a real test of the never-raise property, which is proven
against an actual connection failure rather than a stub.

What is pinned: the three refusals (`ungrounded_graph`, `entry_required`,
`entry_unsaved`) and that they land **before** the store is touched; empty input
skipping rather than writing an empty INSERT; the `INSERT DATA` shape targeting
the entry's graph; Entry's required date/name/description and id-derived graph
name; `federate` refusing explicitly rather than returning empty results.

**A bug was found writing these specs, which is what writing them is for.**
`Cpcp.publish` wrapped its work in `ActiveRecord::Base.transaction`, and its own
comment promised the entry and the assertion "stand or fall TOGETHER". They did
-- until a caller wrapped the call in a transaction of their own. A plain
`transaction` block nested inside an outer one **joins** it, and
`ActiveRecord::Rollback` raised in a joined block is swallowed: the outer
transaction carries on and commits the entry. The result was an account of
triples that were never asserted -- exactly what the comment calls *worse than no
record, because it reads as evidence* -- produced by the code written to prevent
it. Fixed with `requires_new: true`, which makes it a savepoint that rolls back
on its own terms either way.

## Consequences

- The grounding refusals cannot regress silently.
- The nested-transaction case is pinned by a spec that fails if `requires_new` is
  ever removed; every example runs inside an outer transaction, so the harness
  exercises the nesting that exposed the bug.
- `actions_spec.rb` pins a **known gap** rather than hiding it: the legacy MCB
  `graphdb_publish` still accepts a bare graph name, which ADR 0011 recorded. The
  spec asserts the current behaviour with a message saying what to update, so the
  day that path is closed the spec fails and says so.
