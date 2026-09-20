---
type: Architecture Decision
title: "Publishing triples requires a grounded entry"
adr_id: "0011"
status: superseded
date: "2026-08-26"
description: "One wrapper -- publish / query / update -- and publish refuses a bare graph name."
okf_version: "0.2"
tags: [gems, expand, rung-2, silver, refusal, mmg-graph]
resource: "magentic-stack/docs/adr/0011-mmg-graph-publish-requires-grounding.md"
sources:
  - magentic-stack/docs/adr/0011-mmg-graph-publish-requires-grounding.md
frame:
  layer: gems
  phase: expand
  freezes_at_rung: 2
  evidence: silver
  instrument: refusal
paths:
  - gems/mmg-graph/lib
  - gems/mmg-graph/app/models/mmg/graph/entry.rb
  - gems/mmg-graph/app/services/mmg/graph/execute.rb
generated:
  by: claude-opus-5/claude-code
  at: 2026-09-19
---

# ADR 0011 — Publishing triples requires a grounded entry

## Decision

One wrapper -- `publish` / `query` / `update` -- and `publish` **refuses a bare graph name**. It requires `entry:`, a persisted `Mmg::Graph::Entry` carrying a date, a name and a description. The graph name derives from the entry's primary key and is never supplied by the caller. That last part matters: a caller that can name its own graph can write into someone else's, or into one that accounts for nothing. Federation across endpoints is a declared seam that returns `:not_implemented` rather than an absence, so callers can be written against its shape today.

## Context

Every gem that wanted the graph hand-rolled the same `Net::HTTP` block against Oxigraph, and `publish` took raw triples plus a named-graph string that defaulted to `urn:mmg:graph:default`. That default resolved to no record. Anything could write nodes no model could reproduce, and nothing would catch it -- the rule that every node references a Rails model held by discipline, which is to say it did not hold.

## Frame

Layer **gems** (`gems/` — owned packages) · phase **expand** · freezes at **rung 2** · evidence **silver** · instrument **refusal**.

* [Instrument — refusal](../frame.md#instrument-refusal) — Refusing a bare graph name makes the ungrounded publish unavailable.
* [The evidence ladder](../frame.md#the-evidence-ladder) — A persisted entry with a date and a description is what raises a name to a claim.

## Enforcement

No gate named in the source record. The constraint is carried by the record alone.

## Related decisions

* **Superseded by** [ADR 0032 — The grounding refusal is enforced by specs, and rollback survives nesting](./0032-mmg-graph-grounding-is-enforced.md)

## Source

* Full record: `magentic-stack/docs/adr/0011-mmg-graph-publish-requires-grounding.md`
* Frame: [One Frame](../frame.md)
