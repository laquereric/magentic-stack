---
type: Architecture Decision
title: "Shape ownership wins over file boundaries; the runtime resolves per shape"
adr_id: "0044"
status: accepted
date: "2026-08-30"
description: "Split the two mixed files along the ownership line, so each part lands in its owning gem, and replace the single shaperoot with a per-shape resolution map in ProfileCatalog."
okf_version: "0.2"
tags: [gems, expand, rung-2, silver, rung, shapes-level-8, shapes-application, rails-osi-level-8]
resource: "magentic-stack/docs/adr/0044-ownership-wins-over-file-boundaries.md"
sources:
  - magentic-stack/docs/adr/0044-ownership-wins-over-file-boundaries.md
frame:
  layer: gems
  phase: expand
  freezes_at_rung: 2
  evidence: silver
  instrument: rung
paths:
  - gems/shapes-level-8
  - gems/shapes-application
  - gems/rails-osi-level-8/lib/rails_osi_level_8/profile_catalog.rb
enforced_by:
  - tooling/shacl/check_shape_resolution.py
  - tooling/shacl/check_shape_digests.py
  - tooling/shacl/check_catalog_ttl_iri.py
generated:
  by: claude-opus-5/claude-code
  at: 2026-09-19
---

# ADR 0044 — Shape ownership wins over file boundaries; the runtime resolves per shape

## Decision

**Split the two mixed files along the ownership line**, so each part lands in its owning gem, and **replace the single `shape_root` with a per-shape resolution map** in `ProfileCatalog`. The file boundary is an accident of how the protocol was written down. Ownership is a governance fact. Where they disagree, ownership wins and the file gives way.

## Context

Step 9 was specified as a file MOVE with two constraints that turned out to contradict each other in this tree: - the relocation unit is the **file** (the legacy `shape_digest` is SHA-256 of exact runtime-root file bytes, so bytes must not change), and - the ownership unit is the **shape** (`owner` is per NodeShape, ADR 0041). …

## Frame

Layer **gems** (`gems/` — owned packages) · phase **expand** · freezes at **rung 2** · evidence **silver** · instrument **freeze rung**.

* [Layers](../frame.md#layers) — Ownership wins over file boundaries; the file layout was an accident of how it was written.
* [The freeze ladder](../frame.md#the-freeze-ladder) — Uses the freeze rung instrument.

## Enforcement

A paid entry in the futures ledger — the constraint has a gate:

* `tooling/shacl/check_shape_resolution.py`
* `tooling/shacl/check_shape_digests.py`
* `tooling/shacl/check_catalog_ttl_iri.py`

## Source

* Full record: `magentic-stack/docs/adr/0044-ownership-wins-over-file-boundaries.md`
* Frame: [One Frame](../frame.md)
