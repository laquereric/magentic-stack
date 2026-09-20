---
type: Architecture Decision
title: "Profile 10 binds an Effect to the intent that motivated it"
adr_id: "0029"
status: superseded
date: "2026-08-26"
description: "Profile 10 (osi-level-8/profile-10) is INTENT."
okf_version: "0.2"
tags: [grammar, extract, rung-4, gold, rung, rails-osi-level-8, vv-base]
resource: "magentic-stack/docs/adr/0029-profile-10-intent.md"
sources:
  - magentic-stack/docs/adr/0029-profile-10-intent.md
frame:
  layer: grammar
  phase: extract
  freezes_at_rung: 4
  evidence: gold
  instrument: rung
paths:
  - gems/rails-osi-level-8/lib/rails_osi_level_8/intent
enforced_by:
  - gems/rails-osi-level-8/spec/rails_osi_level_8_spec.rb
generated:
  by: claude-opus-5/claude-code
  at: 2026-09-19
---

# ADR 0029 — Profile 10 binds an Effect to the intent that motivated it

## Decision

Profile 10 (`osi-level-8/profile-10`) is **INTENT**. It projects the platform models -- Journey, Flow, Mission, Vision, whose canonical home is `vv-base` per ADR 0015 -- into deterministic P10 CIDs, materializes a Journey into an `IntentGrounding` in the graph, and decorates effect commit with a `TraceGate` that requires an `IntentTrace`. The projection is **read-only** and its CIDs are deterministic, so the same intent yields the same identity and grounding cannot be forged by re-deriving it differently.

## Context

An Effect records that something was done and, via Profile 6, that it was allowed. Neither says what it was *for*. Without that, a reviewer reconstructs motive from the change itself, which is the least reliable evidence available and the easiest to rationalise after the fact.

## Frame

Layer **grammar** (`grammar/` — the owned language) · phase **extract** · freezes at **rung 4** · evidence **gold** · instrument **freeze rung**.

* [The evidence ladder](../frame.md#the-evidence-ladder) — Binding an effect to the intent that motivated it is what makes the effect explainable later.
* [Trajectory](../frame.md#trajectory) — Journey, Flow, Mission and Vision projected into an effect's motivating intent: the aim half, made addressable.
* [The freeze ladder](../frame.md#the-freeze-ladder) — Uses the freeze rung instrument.

## Enforcement

A paid entry in the futures ledger — the constraint has a gate:

* `gems/rails-osi-level-8/spec/rails_osi_level_8_spec.rb`

## Related decisions

* **Superseded by** [ADR 0031 — Profile 10 has closed shapes, held in step with its validator](./0031-profile-10-has-shapes.md)

## Source

* Full record: `magentic-stack/docs/adr/0029-profile-10-intent.md`
* Frame: [One Frame](../frame.md)
