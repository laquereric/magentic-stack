---
type: Architecture Decision
title: "Profile 4 makes an Effect durable and its receipt evidence"
adr_id: "0006"
status: accepted
date: "2026-08-26"
description: "Profile 4 (osi-l8/p4-durable-execution@1) adds P4::DurableReceiptShape: an Effect returns a receipt that is itself grounded, so \"did this happen\" is a question with an answer that"
okf_version: "0.2"
tags: [grammar, extract, rung-4, gold, refusal, rails-osi-level-8]
resource: "magentic-stack/docs/adr/0006-profile-4-durable-execution.md"
sources:
  - magentic-stack/docs/adr/0006-profile-4-durable-execution.md
frame:
  layer: grammar
  phase: extract
  freezes_at_rung: 4
  evidence: gold
  instrument: refusal
paths:
  - gems/rails-osi-level-8/lib/rails_osi_level_8/ledger.rb
  - gems/osi-level-8-profiles/profile-4-durable-cyborg-execution
  - gems/rails-osi-level-8/lib/rails_osi_level_8/ledger_policy.rb
enforced_by:
  - gems/rails-osi-level-8/spec/rails_osi_level_8_spec.rb
  - gems/osi-level-8-profiles/scripts/validate.py
generated:
  by: claude-opus-5/claude-code
  at: 2026-09-19
---

# ADR 0006 — Profile 4 makes an Effect durable and its receipt evidence

## Decision

Profile 4 (`osi-l8/p4-durable-execution@1`) adds `P4::DurableReceiptShape`: an Effect returns a receipt that is itself grounded, so "did this happen" is a question with an answer that survives a restart. Placement follows the **three-ledger discipline** -- `canonical`, `sync_intent`, `private_local` -- so where a record lives is a declared property rather than a consequence of which code path wrote it.

## Context

An Effect that is accepted and then lost is worse than one that is refused: the caller has been told the world changed. A non-deterministic caller retrying an Effect it is unsure about must not double-apply it, and cannot know whether to retry without something durable to ask.

## Frame

Layer **grammar** (`grammar/` — the owned language) · phase **extract** · freezes at **rung 4** · evidence **gold** · instrument **refusal**.

* [The evidence ladder](../frame.md#the-evidence-ladder) — A grounded receipt is Silver made durable: did this happen, with an answer that survives restart.
* [The outward signal](../frame.md#the-outward-signal) — A receipt is evidence about an effect, not a claim by the actor that caused it.
* [Instrument — refusal](../frame.md#instrument-refusal) — Uses the refusal instrument.

## Enforcement

A paid entry in the futures ledger — the constraint has a gate:

* `gems/rails-osi-level-8/spec/rails_osi_level_8_spec.rb`
* `gems/osi-level-8-profiles/scripts/validate.py`

## Source

* Full record: `magentic-stack/docs/adr/0006-profile-4-durable-execution.md`
* Frame: [One Frame](../frame.md)
