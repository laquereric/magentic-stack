---
type: Architecture Decision
title: "ACIA moves to mmg-acia; native oxigraph backs SPARQL"
adr_id: "0003"
status: superseded
date: "2026-08-25"
description: "ACIA moves out of rails-osi-level-8 into mmg-acia rails-osi-level-8 then depends on mmg-acia."
okf_version: "0.2"
tags: [gems, expand, rung-2, silver, rung, rails-osi-level-8, mmg-graph]
resource: "magentic-stack/docs/adr/0003-acia-moves-to-mmg-acia.md"
sources:
  - magentic-stack/docs/adr/0003-acia-moves-to-mmg-acia.md
frame:
  layer: gems
  phase: expand
  freezes_at_rung: 2
  evidence: silver
  instrument: rung
paths:
  - gems/rails-osi-level-8/lib/rails_osi_level_8/profile9
  - gems/mmg-graph
enforced_by:
  - gems/mmg-graph/spec/execute_spec.rb
generated:
  by: claude-opus-5/claude-code
  at: 2026-09-19
---

# ADR 0003 — ACIA moves to mmg-acia; native oxigraph backs SPARQL

## Decision

### 1. ACIA moves out of `rails-osi-level-8` into `mmg-acia` `rails-osi-level-8` then **depends on** `mmg-acia`. Profile 9 keeps the OSI-8 operations (`ux.render`, `ux.inspect`, …) and calls the new gem for the document and the renderer. ACIA is presentation; OSI Level 8 is the grant that may present it. **Cost — state it plainly.** This is a **breaking** change to a baseline gem that the **rails-base image** builds in and that two production sites consume: **stewardshiptranslation.com** and **magenticmarket.ai**. A lockfile bump is not enough; repo doctrine is that a repin edits the **Gemfile ref**, not just the lock. Both sites and the image rebuild together or they drift. ### 2. Native oxigraph backs the SPARQL surface — **done** Docker oxigraph is deprecated for this substrate; the native path is the one in use. …

## Context

Profile 9 ACIA lives inside `rails-osi-level-8` because that is where the first renderer was written. OSI Level 8 is protocol grounding (Context, Effect, SHACL). ACIA is presentation (a tree of components, a prop table, a page shell). One gem holding both is why ACIA has no name of its own: every caller reaches it as `RailsOsiLevel8::Profile9::Acia`. SPARQL over that tree was sketched against a URL nobody read (`MMG_GRAPH_URL`). Meanwhile native oxigraph is the store the substrate actually runs.

## Frame

Layer **gems** (`gems/` — owned packages) · phase **expand** · freezes at **rung 2** · evidence **silver** · instrument **freeze rung**.

* [Layers](../frame.md#layers) — Moving a package to its owning gem is a layer correction.
* [Promotion and priced descent](../frame.md#promotion-and-priced-descent) — Superseded twice over — the descent is recorded, not erased.
* [The freeze ladder](../frame.md#the-freeze-ladder) — Uses the freeze rung instrument.

## Enforcement

A paid entry in the futures ledger — the constraint has a gate:

* `gems/mmg-graph/spec/execute_spec.rb`

## Related decisions

* **Superseded by** [ADR 0034 — Native oxigraph backs the SPARQL surface](./0034-native-oxigraph-backs-sparql.md)
* **Superseded by** [ADR 0035 — Which ACIA vocabulary survives is not yet decided](./0035-acia-convergence-undecided.md)

## Source

* Full record: `magentic-stack/docs/adr/0003-acia-moves-to-mmg-acia.md`
* Frame: [One Frame](../frame.md)
