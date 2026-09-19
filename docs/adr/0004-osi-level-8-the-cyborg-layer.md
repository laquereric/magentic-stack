---
type: Architecture Decision
title: "OSI Level 8 is the layer where a Cyborg perceives and acts"
adr_id: "0004"
status: accepted
date: "2026-08-26"
description: "Model the layer above Application explicitly."
okf_version: "0.2"
tags: [grammar, extract, rung-4, gold, rung, rails-osi-level-8, rails-cpcp]
resource: "magentic-stack/docs/adr/0004-osi-level-8-the-cyborg-layer.md"
sources:
  - magentic-stack/docs/adr/0004-osi-level-8-the-cyborg-layer.md
frame:
  layer: grammar
  phase: extract
  freezes_at_rung: 4
  evidence: gold
  instrument: rung
paths:
  - gems/rails-osi-level-8/lib/rails_osi_level_8
  - grammar
enforced_by:
  - gems/rails-osi-level-8/spec/rails_osi_level_8_spec.rb
generated:
  by: claude-opus-5/claude-code
  at: 2026-09-19
---

# ADR 0004 — OSI Level 8 is the layer where a Cyborg perceives and acts

## Decision

Model the layer above Application explicitly. A **Cyborg** is a responsible Human + Compute; it **perceives Context** and **acts via Effect**. - **Context is perception, and maps to a CPCP PULL** (read access). - **Effect is action, and maps to a CPCP PUSH** (write access). Both ride grounded JSON-RPC-LD constrained by **closed** SHACL shapes. Closed is the operative word: a shape that admits unknown predicates cannot refuse an invented one, and an interface that cannot refuse is not a contract. OSI Level 8 is a **semantic adapter atop CPCP**, not a competing surface. `/_cpcp` stays the single public RPC seam.

## Context

An agent acting on a system needs two things the Application layer does not define: a way to *perceive* state that is grounded in something it cannot fabricate, and a way to *act* that a later reader can audit. Left undefined, every integration invents its own pair, and the resulting surface has no shared notion of what was seen or what was done.

## Frame

Layer **grammar** (`grammar/` — the owned language) · phase **extract** · freezes at **rung 4** · evidence **gold** · instrument **freeze rung**.

* [Layers](../frame.md#layers) — Names the grammar layer's subject: a Cyborg perceives Context and acts via Effect.
* [Phases](../frame.md#phases) — A layer modelled explicitly is Extract work by construction.
* [Trajectory](../frame.md#trajectory) — A Cyborg is a responsible human plus compute: the pairing, not either half, is what the trajectory is for.
* [The freeze ladder](../frame.md#the-freeze-ladder) — Uses the freeze rung instrument.

## Enforcement

A paid entry in the futures ledger — the constraint has a gate:

* `gems/rails-osi-level-8/spec/rails_osi_level_8_spec.rb`

## Source

* Full record: `magentic-stack/docs/adr/0004-osi-level-8-the-cyborg-layer.md`
* Frame: [One Frame](../frame.md)
