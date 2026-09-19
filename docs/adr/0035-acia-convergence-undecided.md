---
type: Architecture Decision
title: "Which ACIA vocabulary survives is not yet decided"
adr_id: "0035"
status: proposed
date: "2026-08-26"
description: "None yet, and that is the record."
okf_version: "0.2"
tags: [gems, explore, rung-0, bronze, rung, rails-osi-level-8, mmg-semantic-editor]
resource: "magentic-stack/docs/adr/0035-acia-convergence-undecided.md"
sources:
  - magentic-stack/docs/adr/0035-acia-convergence-undecided.md
frame:
  layer: gems
  phase: explore
  freezes_at_rung: 0
  evidence: bronze
  instrument: rung
paths:
  - gems/rails-osi-level-8/lib/rails_osi_level_8/profile9
enforced_by:
  - gems/rails-osi-level-8/spec/no_half_cut_spec.rb
generated:
  by: claude-opus-5/claude-code
  at: 2026-09-19
---

# ADR 0035 — Which ACIA vocabulary survives is not yet decided

## Decision

**None yet, and that is the record.** `entity_token` against the SLT tuple, AR rows against JSON documents: which vocabulary survives is an open question with live consumers on both sides, and it is not a decision to take by default or by whoever edits next. What IS decided is the constraint that holds while it is open: **Do not delete Profile 9 from `rails-osi-level-8` in a half-cut.** The image would build and the sites would not boot. `rails-osi-level-8` is a baseline gem that the rails-base image builds in and that two production sites consume -- stewardshiptranslation.com and magenticmarket.ai. When the vocabulary question is answered, the repin sequence is ordered because the image and both sites share the gem: 1. Decide which vocabulary survives. Everything below carries whatever that produces; until it is taken, steps 2-5 have nothing to carry. 2. …

## Context

ADR 0003 recorded this as `Accepted`, and its own Correction section said the opposite: the real first step *"is deciding which vocabulary survives, and that decision is NOT yet taken."* An accepted status over an untaken decision is the false-confidence failure -- an agent reading 0003 would find a settled decision and build on it. The original framing was that ACIA should be *extracted* from `rails-osi-level-8` into a new gem. That was wrong on the facts. …

## Frame

Layer **gems** (`gems/` — owned packages) · phase **explore** · freezes at **rung 0** · evidence **bronze** · instrument **freeze rung**.

* [The freeze ladder](../frame.md#the-freeze-ladder) — The purest statement of F1 in the corpus: in discovery you stay at rungs 0-1, and refusing to freeze is the decision.
* [Phases](../frame.md#phases) — Live consumers on both sides means the problem space is still open — Explore, and recorded as such.

## Enforcement

A paid entry in the futures ledger — the constraint has a gate:

* `gems/rails-osi-level-8/spec/no_half_cut_spec.rb`

## Related decisions

* **Supersedes** [ADR 0003 — ACIA moves to mmg-acia; native oxigraph backs SPARQL](./0003-acia-moves-to-mmg-acia.md)

## Source

* Full record: `magentic-stack/docs/adr/0035-acia-convergence-undecided.md`
* Frame: [One Frame](../frame.md)
