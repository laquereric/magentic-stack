---
type: Architecture Decision
title: "Review is a static script over the rendered page"
adr_id: "0018"
status: accepted
date: "2026-08-26"
description: "A single static script that turns an already-rendered Profile 9 page into a review surface, without changing the renderer."
okf_version: "0.2"
tags: [overlay, explore, rung-0, bronze, rung, vv-html-components]
resource: "magentic-stack/docs/adr/0018-vv-html-components-static-review-surface.md"
sources:
  - magentic-stack/docs/adr/0018-vv-html-components-static-review-surface.md
frame:
  layer: overlay
  phase: explore
  freezes_at_rung: 0
  evidence: bronze
  instrument: rung
paths:
  - gems/vv-html-components/lib
  - gems/vv-html-components/dist
enforced_by:
  - gems/vv-html-components/spec/v1_spec.rb
generated:
  by: claude-opus-5/claude-code
  at: 2026-09-19
---

# ADR 0018 — Review is a static script over the rendered page

## Decision

A **single static script** that turns an already-rendered Profile 9 page into a review surface, without changing the renderer. It reads the node attributes the renderer already emits. The demo opens from the filesystem with no server.

## Context

A review surface over an ACIA page could be built into the renderer. Then the renderer serves two masters: producing the page, and producing the affordances for inspecting it. Every review feature becomes a renderer change, and the P9 gate (ADR 0007) now has to admit component kinds that exist only for reviewing.

## Frame

Layer **overlay** (overlay — consumes the substrate) · phase **explore** · freezes at **rung 0** · evidence **bronze** · instrument **freeze rung**.

* [Phases](../frame.md#phases) — A static script over an already-rendered page is Explore: the cheapest thing that produces learning.
* [Overlays](../frame.md#overlays) — It reads what the renderer already emits and changes nothing — an overlay in the strict sense.
* [The freeze ladder](../frame.md#the-freeze-ladder) — Uses the freeze rung instrument.

## Enforcement

A paid entry in the futures ledger — the constraint has a gate:

* `gems/vv-html-components/spec/v1_spec.rb`

## Source

* Full record: `magentic-stack/docs/adr/0018-vv-html-components-static-review-surface.md`
* Frame: [One Frame](../frame.md)
