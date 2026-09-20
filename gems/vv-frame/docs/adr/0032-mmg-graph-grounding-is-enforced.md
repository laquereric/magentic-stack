---
type: Architecture Decision
title: "The grounding refusal is enforced by specs, and rollback survives nesting"
adr_id: "0032"
status: accepted
date: "2026-08-26"
description: "The rule from ADR 0011 stands unchanged and is now enforced by 32 examples."
okf_version: "0.2"
tags: [gems, extract, rung-2, gold, refusal, mmg-graph]
resource: "magentic-stack/docs/adr/0032-mmg-graph-grounding-is-enforced.md"
sources:
  - magentic-stack/docs/adr/0032-mmg-graph-grounding-is-enforced.md
frame:
  layer: gems
  phase: extract
  freezes_at_rung: 2
  evidence: gold
  instrument: refusal
paths:
  - gems/mmg-graph/lib
  - gems/mmg-graph/app/models/mmg/graph/entry.rb
  - gems/mmg-graph/app/services/mmg/graph/execute.rb
enforced_by:
  - gems/mmg-graph/spec/execute_spec.rb
  - gems/mmg-graph/spec/cpcp_spec.rb
  - gems/mmg-graph/spec/entry_spec.rb
  - gems/mmg-graph/spec/actions_spec.rb
generated:
  by: claude-opus-5/claude-code
  at: 2026-09-19
---

# ADR 0032 — The grounding refusal is enforced by specs, and rollback survives nesting

## Decision

The rule from ADR 0011 stands unchanged and is now enforced by 32 examples. The suite is **hermetic**: `MM_OXIGRAPH_URL` points at a closed port. Every refusal this gem is built on happens *before* any HTTP call, so nothing needs a live store -- and a suite that needs one is a suite that gets skipped. The closed port doubles as a real test of the never-raise property, which is proven against an actual connection failure rather than a stub. What is pinned: the three refusals (`ungrounded_graph`, `entry_required`, `entry_unsaved`) and that they land **before** the store is touched; empty input skipping rather than writing an empty INSERT; the `INSERT DATA` shape targeting the entry's graph; Entry's required date/name/description and id-derived graph name; `federate` refusing explicitly rather than returning empty results. …

## Context

ADR 0011 recorded that `publish` refuses a bare graph name, and recorded honestly that nothing checked it -- the gem had no spec suite at all. The invariant that makes every node in this graph reproducible from a row was held by reading.

## Frame

Layer **gems** (`gems/` — owned packages) · phase **extract** · freezes at **rung 2** · evidence **gold** · instrument **refusal**.

* [The futures ledger](../frame.md#the-futures-ledger) — The rule stands unchanged and is now enforced by examples — the paid entry.
* [Instrument — refusal](../frame.md#instrument-refusal) — Every refusal happens before any call goes out, so the suite is hermetic.

## Enforcement

A paid entry in the futures ledger — the constraint has a gate:

* `gems/mmg-graph/spec/execute_spec.rb`
* `gems/mmg-graph/spec/cpcp_spec.rb`
* `gems/mmg-graph/spec/entry_spec.rb`
* `gems/mmg-graph/spec/actions_spec.rb`

## Related decisions

* **Supersedes** [ADR 0011 — Publishing triples requires a grounded entry](./0011-mmg-graph-publish-requires-grounding.md)

## Source

* Full record: `magentic-stack/docs/adr/0032-mmg-graph-grounding-is-enforced.md`
* Frame: [One Frame](../frame.md)
