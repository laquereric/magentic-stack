---
type: Architecture Decision
title: "An l8.execution.complete row journals itself"
adr_id: "0053"
status: accepted
date: "2026-08-31"
description: "l8.execution.complete rows get their own journal."
okf_version: "0.2"
tags: [gems, expand, rung-2, silver, rung, rails-osi-level-8]
resource: "magentic-stack/docs/adr/0053-a-complete-row-journals-itself.md"
sources:
  - magentic-stack/docs/adr/0053-a-complete-row-journals-itself.md
frame:
  layer: gems
  phase: expand
  freezes_at_rung: 2
  evidence: silver
  instrument: rung
paths:
  - gems/rails-osi-level-8/lib/rails_osi_level_8/p7_commands.rb
enforced_by:
  - gems/rails-osi-level-8/spec/p7_observation_gate_spec.rb
  - .github/workflows/admission-journal.yml
generated:
  by: claude-opus-5/claude-code
  at: 2026-09-19
---

# ADR 0053 — An l8.execution.complete row journals itself

## Decision

**`l8.execution.complete` rows get their own journal.** Closes gap 56. Today `p7_commands.rb:151-165` creates an `OperationRequest` for the complete and then writes the `completed` entry with `operation_request_cid: op_cid` -- the **parent** `note.create`'s cid -- taking `seq` from the parent's journal. The complete row it just created gets nothing. Measured: the one existing complete row in the host database has **zero** journal entries of its own. A durable record that cannot describe itself is not a record. It is a row.

## Frame

Layer **gems** (`gems/` — owned packages) · phase **expand** · freezes at **rung 2** · evidence **silver** · instrument **freeze rung**.

* [The outward signal](../frame.md#the-outward-signal) — A completion that journals itself is an event with its own evidence rather than a claim attached to another.
* [The freeze ladder](../frame.md#the-freeze-ladder) — Uses the freeze rung instrument.

## Enforcement

A paid entry in the futures ledger — the constraint has a gate:

* `gems/rails-osi-level-8/spec/p7_observation_gate_spec.rb`
* `.github/workflows/admission-journal.yml`

## Source

* Full record: `magentic-stack/docs/adr/0053-a-complete-row-journals-itself.md`
* Frame: [One Frame](../frame.md)
