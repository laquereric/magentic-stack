---
type: Architecture Decision
title: "Profile 2 makes an IRI a pass-by-reference handle"
adr_id: "0023"
status: proposed
date: "2026-08-26"
description: "A JSON-RPC-LD @id is a pass-by-reference handle, portable across process and trust boundaries."
okf_version: "0.2"
tags: [grammar, extract, rung-4, gold, rung, osi-level-8-profiles]
resource: "magentic-stack/docs/adr/0023-profile-2-reference-passing.md"
sources:
  - magentic-stack/docs/adr/0023-profile-2-reference-passing.md
frame:
  layer: grammar
  phase: extract
  freezes_at_rung: 4
  evidence: gold
  instrument: rung
paths:
  - gems/osi-level-8-profiles/profile-2-reference-passing
enforced_by:
  - gems/osi-level-8-profiles/scripts/validate.py
generated:
  by: claude-opus-5/claude-code
  at: 2026-09-19
---

# ADR 0023 — Profile 2 makes an IRI a pass-by-reference handle

## Decision

A JSON-RPC-LD `@id` is a **pass-by-reference handle, portable across process and trust boundaries**. From that one identification: BACK publishes a typed method surface, the model reads Context *by reference* with typed bounded previews dereferenced on demand, and returns structured output as a typed Effect enforced identically at decode time and at ingest time. Scope is deliberately minimal. Profile 2 does **not** use the `private_local` ledger -- it exposes no private data -- and does **not** use `baseVersion` optimistic concurrency, because Effects are idempotent and keyed by `operationId`. Both remain defined in the base for deployments that need them. Where Profile 1 grounds data as typed rows, Profile 2 governs how an agent reads and acts on that data across the Level 8 boundary.

## Context

An agent given data by value is given all of it. Context windows make that a hard limit rather than an inefficiency, and it forces a choice between truncating what the model sees and sending more than it needs -- both of which degrade quietly.

## Frame

Layer **grammar** (`grammar/` — the owned language) · phase **extract** · freezes at **rung 4** · evidence **gold** · instrument **freeze rung**.

* [The evidence ladder](../frame.md#the-evidence-ladder) — A handle portable across trust boundaries is what lets evidence travel without copying.
* [The freeze ladder](../frame.md#the-freeze-ladder) — Uses the freeze rung instrument.

## Enforcement

A paid entry in the futures ledger — the constraint has a gate:

* `gems/osi-level-8-profiles/scripts/validate.py`

## Source

* Full record: `magentic-stack/docs/adr/0023-profile-2-reference-passing.md`
* Frame: [One Frame](../frame.md)
