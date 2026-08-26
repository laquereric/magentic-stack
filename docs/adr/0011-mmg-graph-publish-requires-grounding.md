---
id: "0011"
title: Publishing triples requires a grounded entry
status: accepted
date: 2026-08-26
subject_kind: gem
subject: mmg-graph
components: [mmg-graph]
paths:
  - gems/mmg-graph/lib
  - gems/mmg-graph/app/models/mmg/graph/entry.rb
  - gems/mmg-graph/app/services/mmg/graph/execute.rb
enforced_by: []
supersedes: null
superseded_by: null
---

## Context

Every gem that wanted the graph hand-rolled the same `Net::HTTP` block against
Oxigraph, and `publish` took raw triples plus a named-graph string that defaulted
to `urn:mmg:graph:default`. That default resolved to no record. Anything could
write nodes no model could reproduce, and nothing would catch it -- the rule that
every node references a Rails model held by discipline, which is to say it did
not hold.

## Decision

One wrapper -- `publish` / `query` / `update` -- and `publish` **refuses a bare
graph name**. It requires `entry:`, a persisted `Mmg::Graph::Entry` carrying a
date, a name and a description. The graph name derives from the entry's primary
key and is never supplied by the caller.

That last part matters: a caller that can name its own graph can write into
someone else's, or into one that accounts for nothing.

Federation across endpoints is a declared seam that returns `:not_implemented`
rather than an absence, so callers can be written against its shape today.

## Consequences

- The class-or-instance invariant is enforced by construction. There is nowhere
  anonymous to write, so nothing anonymous gets written.
- Every publisher must first create an Entry saying why the triples exist. One
  line, and it is the line a later reader needs.
- **The chain is incomplete here.** `enforced_by` is empty because this gem has
  no spec suite; the refusal above is currently guarded by reading, not by a
  test. Recorded rather than hidden -- see the freeze-baseline note in
  `docs/adr/README.md`.
