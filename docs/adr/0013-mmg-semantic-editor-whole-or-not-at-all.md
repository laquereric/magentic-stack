---
type: Architecture Decision
title: "Prose edits become writes offered whole or not at all"
adr_id: "0013"
status: accepted
date: "2026-08-26"
description: "Take an ACIA tree (ADR 0007) whose nodes carry canonical ids and disclosure tiers, let a person rewrite a Frame as prose, and decompose the result into the set of writes it actuall"
okf_version: "0.2"
tags: [gems, expand, rung-2, silver, refusal, mmg-semantic-editor]
resource: "magentic-stack/docs/adr/0013-mmg-semantic-editor-whole-or-not-at-all.md"
sources:
  - magentic-stack/docs/adr/0013-mmg-semantic-editor-whole-or-not-at-all.md
frame:
  layer: gems
  phase: expand
  freezes_at_rung: 2
  evidence: silver
  instrument: refusal
paths:
  - gems/mmg-semantic-editor/lib
enforced_by:
  - gems/mmg-semantic-editor/spec/semantic_editor_spec.rb
  - gems/mmg-semantic-editor/spec/decompose_spec.rb
  - gems/mmg-semantic-editor/spec/disclosure_spec.rb
generated:
  by: claude-opus-5/claude-code
  at: 2026-09-19
---

# ADR 0013 — Prose edits become writes offered whole or not at all

## Decision

Take an ACIA tree (ADR 0007) whose nodes carry canonical ids and disclosure tiers, let a person rewrite a Frame as prose, and decompose the result into the set of writes it actually implies -- **grouped by target structure, and offered whole or not at all**. Disclosure tier is part of the decomposition, not a filter applied after: what a reader may see determines what an edit may touch.

## Context

A person editing a Frame is editing one document that stands for several records. Applying whatever writes happen to parse leaves the underlying records in a state no one described: half a rewrite is not a smaller rewrite, it is a different and unintended one.

## Frame

Layer **gems** (`gems/` — owned packages) · phase **expand** · freezes at **rung 2** · evidence **silver** · instrument **refusal**.

* [Overlays](../frame.md#overlays) — Writes offered whole or not at all is the slice rule, arriving from the editing side.
* [Failure modes](../frame.md#failure-modes) — A partial write is a fragment presented as a whole.
* [Instrument — refusal](../frame.md#instrument-refusal) — Uses the refusal instrument.

## Enforcement

A paid entry in the futures ledger — the constraint has a gate:

* `gems/mmg-semantic-editor/spec/semantic_editor_spec.rb`
* `gems/mmg-semantic-editor/spec/decompose_spec.rb`
* `gems/mmg-semantic-editor/spec/disclosure_spec.rb`

## Source

* Full record: `magentic-stack/docs/adr/0013-mmg-semantic-editor-whole-or-not-at-all.md`
* Frame: [One Frame](../frame.md)
