---
type: Architecture Decision
title: "Profile 9 is presentation as a closed component tree"
adr_id: "0007"
status: accepted
date: "2026-08-26"
description: "Profile 9 is ACIA -- a document tree of components with a property table, over a closed 19-kind vocabulary (ghis-19@1)."
okf_version: "0.2"
tags: [grammar, extract, rung-4, gold, refusal, rails-osi-level-8, vv-html-components, mmg-semantic-editor]
resource: "magentic-stack/docs/adr/0007-profile-9-acia-presentation.md"
sources:
  - magentic-stack/docs/adr/0007-profile-9-acia-presentation.md
frame:
  layer: grammar
  phase: extract
  freezes_at_rung: 4
  evidence: gold
  instrument: refusal
paths:
  - gems/rails-osi-level-8/lib/rails_osi_level_8/profile9
  - gems/osi-level-8-profiles/profile-9-governed-human-interaction-surface
enforced_by:
  - gems/osi-level-8-profiles/scripts/validate.py
  - gems/rails-osi-level-8/spec/projection_spec.rb
  - gems/rails-osi-level-8/spec/composed_frame_spec.rb
  - gems/rails-osi-level-8/spec/board_reach_spec.rb
generated:
  by: claude-opus-5/claude-code
  at: 2026-09-19
---

# ADR 0007 — Profile 9 is presentation as a closed component tree

## Decision

Profile 9 is **ACIA** -- a document tree of components with a property table, over a **closed 19-kind vocabulary** (`ghis-19@1`). Each node carries an SLT tuple (semantic role, content role, layout kind, layout arity, behavior kind), properties live in `props.valueJson` under a declared `propsSchemaCid`, and the whole document passes a **closed** SHACL shape gate before it is anything. The top of the ACIA tree aligns with the Rails page layout, so the document describes the page that exists rather than a parallel idea of it. Node identity is content-addressed: `cid:node:<sha256(digest:nodeId)[0,16]>`.

## Context

A non-deterministic entity asked to change a screen needs to know what the screen *is*, in terms it cannot invent. Handed HTML, it will produce plausible HTML, and plausibility is the failure mode: the result renders, and nothing checks whether the thing it rendered was a component this system has.

## Frame

Layer **grammar** (`grammar/` — the owned language) · phase **extract** · freezes at **rung 4** · evidence **gold** · instrument **refusal**.

* [Instrument — refusal](../frame.md#instrument-refusal) — A closed nineteen-kind vocabulary makes an undeclared kind unavailable rather than discouraged.
* [The evidence ladder](../frame.md#the-evidence-ladder) — A property table over a closed vocabulary is a contracted artifact.

## Enforcement

A paid entry in the futures ledger — the constraint has a gate:

* `gems/osi-level-8-profiles/scripts/validate.py`
* `gems/rails-osi-level-8/spec/projection_spec.rb`
* `gems/rails-osi-level-8/spec/composed_frame_spec.rb`
* `gems/rails-osi-level-8/spec/board_reach_spec.rb`

## Source

* Full record: `magentic-stack/docs/adr/0007-profile-9-acia-presentation.md`
* Frame: [One Frame](../frame.md)
