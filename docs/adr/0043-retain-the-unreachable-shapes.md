---
type: Architecture Decision
title: "Unreachable shapes are retained, not deleted"
adr_id: "0043"
status: accepted
date: "2026-08-29"
description: "Retain all 46. None is deleted, relocated, or renamed."
okf_version: "0.2"
tags: [gems, extract, rung-2, gold, rung, osi-level-8-profiles, rails-osi-level-8]
resource: "magentic-stack/docs/adr/0043-retain-the-unreachable-shapes.md"
sources:
  - magentic-stack/docs/adr/0043-retain-the-unreachable-shapes.md
frame:
  layer: gems
  phase: extract
  freezes_at_rung: 2
  evidence: gold
  instrument: rung
paths:
  - tooling/shacl/shape_quarantine_inventory.json
enforced_by:
  - tooling/shacl/check_shape_quarantine.py
generated:
  by: claude-opus-5/claude-code
  at: 2026-09-19
---

# ADR 0043 — Unreachable shapes are retained, not deleted

## Decision

**Retain all 46.** None is deleted, relocated, or renamed.

## Context

Of 171 NodeShapes, 65 are `unowned` -- no call site names them. Step 2 classified why: 46 `unreferenced`, 16 `self_targeting`, 2 `transitively_reachable`, 1 `orphan_referenced`. The 46 unreferenced ones were left without a decision.

## Frame

Layer **gems** (`gems/` — owned packages) · phase **extract** · freezes at **rung 2** · evidence **gold** · instrument **freeze rung**.

* [Promotion and priced descent](../frame.md#promotion-and-priced-descent) — Retain, do not delete: deletion is an unpriced descent that converts held futures into nobody's features.
* [The futures ledger](../frame.md#the-futures-ledger) — Unreachable is a fact about now, not a verdict on the artifact.
* [Smart context](../frame.md#smart-context) — Retain rather than delete: what is unreachable now is still the record a later reader needs.
* [The freeze ladder](../frame.md#the-freeze-ladder) — Uses the freeze rung instrument.

## Enforcement

A paid entry in the futures ledger — the constraint has a gate:

* `tooling/shacl/check_shape_quarantine.py`

## Source

* Full record: `magentic-stack/docs/adr/0043-retain-the-unreachable-shapes.md`
* Frame: [One Frame](../frame.md)
