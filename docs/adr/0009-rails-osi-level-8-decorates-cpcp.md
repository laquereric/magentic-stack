---
type: Architecture Decision
title: "rails-osi-level-8 decorates rails-cpcp rather than competing with it"
adr_id: "0009"
status: accepted
date: "2026-08-26"
description: "rails-osi-level-8 is additive: it mounts alongside rails-cpcp in the BACK app and adds grounding (closed-SHACL validation), the three-ledger discipline, and profile evidence."
okf_version: "0.2"
tags: [gems, expand, rung-2, silver, refusal, rails-osi-level-8]
resource: "magentic-stack/docs/adr/0009-rails-osi-level-8-decorates-cpcp.md"
sources:
  - magentic-stack/docs/adr/0009-rails-osi-level-8-decorates-cpcp.md
frame:
  layer: gems
  phase: expand
  freezes_at_rung: 2
  evidence: silver
  instrument: refusal
paths:
  - gems/rails-osi-level-8/lib
  - gems/rails-osi-level-8/db
enforced_by:
  - gems/rails-osi-level-8/spec/rails_osi_level_8_spec.rb
generated:
  by: claude-opus-5/claude-code
  at: 2026-09-19
---

# ADR 0009 — rails-osi-level-8 decorates rails-cpcp rather than competing with it

## Decision

`rails-osi-level-8` is **additive**: it mounts alongside `rails-cpcp` in the BACK app and adds grounding (closed-SHACL validation), the three-ledger discipline, and profile evidence. It never becomes a competing surface; `/_cpcp` stays the single public seam. SHACL shapes and normative profiles are authoritative; code derives from them. Shape digests are pinned at load, so a shape correction is visible in evidence rather than silently changing what validates.

## Context

Grounding, ledger placement and profile evidence all need a place to live in a Rails app. The obvious move -- a second engine with its own mount point and its own RPC surface -- gives an agent two doors into the same system, and two doors means the guarantees of one can be reached around via the other.

## Frame

Layer **gems** (`gems/` — owned packages) · phase **expand** · freezes at **rung 2** · evidence **silver** · instrument **refusal**.

* [Layers](../frame.md#layers) — Additive rather than competing: one seam stays one seam.
* [Instrument — refusal](../frame.md#instrument-refusal) — Never becoming a competing surface is a refusal to create a second home.

## Enforcement

A paid entry in the futures ledger — the constraint has a gate:

* `gems/rails-osi-level-8/spec/rails_osi_level_8_spec.rb`

## Source

* Full record: `magentic-stack/docs/adr/0009-rails-osi-level-8-decorates-cpcp.md`
* Frame: [One Frame](../frame.md)
