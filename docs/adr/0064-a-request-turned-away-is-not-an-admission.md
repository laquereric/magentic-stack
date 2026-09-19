---
type: Architecture Decision
title: "A request turned away is not an admission; the journal's subject is an operation that exists"
adr_id: "0064"
status: accepted
date: "2026-09-05"
description: "A request turned away is not an admission;"
okf_version: "0.2"
tags: [gems, extract, rung-3, gold, refusal, rails-osi-level-8]
resource: "magentic-stack/docs/adr/0064-a-request-turned-away-is-not-an-admission.md"
sources:
  - magentic-stack/docs/adr/0064-a-request-turned-away-is-not-an-admission.md
frame:
  layer: gems
  phase: extract
  freezes_at_rung: 3
  evidence: gold
  instrument: refusal
paths:
  - gems/rails-osi-level-8/lib/rails_osi_level_8/cpcp_adapter.rb
  - gems/rails-osi-level-8/lib/rails_osi_level_8/models/admission_attempt.rb
enforced_by:
  - tooling/osi/check_refusal_registers.py
  - tooling/osi/plant_refusal_registers.py
  - gems/rails-osi-level-8/spec/refusal_evidence_spec.rb
generated:
  by: claude-opus-5/claude-code
  at: 2026-09-19
---

# ADR 0064 — A request turned away is not an admission; the journal's subject is an operation that exists

## Decision

*(Stated in the source record; this decision carries its content outside a Decision heading.)*

## Frame

Layer **gems** (`gems/` — owned packages) · phase **extract** · freezes at **rung 3** · evidence **gold** · instrument **refusal**.

* [Failure modes](../frame.md#failure-modes) — A request turned away is not an admission: the exact shape of stored counted as admitted.
* [The evidence ladder](../frame.md#the-evidence-ladder) — The journal's subject is an operation that exists, so absence stays distinguishable from refusal.
* [Instrument — refusal](../frame.md#instrument-refusal) — Uses the refusal instrument.

## Enforcement

A paid entry in the futures ledger — the constraint has a gate:

* `tooling/osi/check_refusal_registers.py`
* `tooling/osi/plant_refusal_registers.py`
* `gems/rails-osi-level-8/spec/refusal_evidence_spec.rb`

## Source

* Full record: `magentic-stack/docs/adr/0064-a-request-turned-away-is-not-an-admission.md`
* Frame: [One Frame](../frame.md)
