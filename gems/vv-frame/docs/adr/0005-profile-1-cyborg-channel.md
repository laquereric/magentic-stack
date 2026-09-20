---
type: Architecture Decision
title: "Profile 1 is the minimal Cyborg channel"
adr_id: "0005"
status: accepted
date: "2026-08-26"
description: "Profile 1 (osi-l8/p1/cyborg-channel@1) is the reference channel: note create and note list, as an Effect pair and a Pull pair -- P1::NoteCreateEffectShape, P1::NoteCreateContextSha"
okf_version: "0.2"
tags: [grammar, extract, rung-4, gold, refusal, rails-osi-level-8]
resource: "magentic-stack/docs/adr/0005-profile-1-cyborg-channel.md"
sources:
  - magentic-stack/docs/adr/0005-profile-1-cyborg-channel.md
frame:
  layer: grammar
  phase: extract
  freezes_at_rung: 4
  evidence: gold
  instrument: refusal
paths:
  - gems/rails-osi-level-8/lib/rails_osi_level_8/profile_catalog.rb
  - gems/osi-level-8-profiles/profile-1-cyborg-channel
enforced_by:
  - gems/rails-osi-level-8/spec/rails_osi_level_8_spec.rb
  - gems/osi-level-8-profiles/scripts/validate.py
generated:
  by: claude-opus-5/claude-code
  at: 2026-09-19
---

# ADR 0005 — Profile 1 is the minimal Cyborg channel

## Decision

Profile 1 (`osi-l8/p1/cyborg-channel@1`) is the reference channel: note create and note list, as an Effect pair and a Pull pair -- `P1::NoteCreateEffectShape`, `P1::NoteCreateContextShape`, `P1::NoteListPullShape`, `P1::NoteListContextShape`. It stays deliberately trivial. Its job is to be the smallest complete instance of the grammar, not to be useful.

## Context

Before any rich profile is worth building, the Context/Effect pair from ADR 0004 has to be shown to work end to end on something small enough to hold in one head. A profile that debuts on a complex domain cannot distinguish a flaw in the protocol from a flaw in the domain model.

## Frame

Layer **grammar** (`grammar/` — the owned language) · phase **extract** · freezes at **rung 4** · evidence **gold** · instrument **refusal**.

* [The evidence ladder](../frame.md#the-evidence-ladder) — A reference channel is the Gold bar other profiles are measured against.
* [Instrument — refusal](../frame.md#instrument-refusal) — Closed shapes refuse what the profile does not declare.

## Enforcement

A paid entry in the futures ledger — the constraint has a gate:

* `gems/rails-osi-level-8/spec/rails_osi_level_8_spec.rb`
* `gems/osi-level-8-profiles/scripts/validate.py`

## Source

* Full record: `magentic-stack/docs/adr/0005-profile-1-cyborg-channel.md`
* Frame: [One Frame](../frame.md)
