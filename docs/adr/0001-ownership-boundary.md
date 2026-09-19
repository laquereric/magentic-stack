---
type: Architecture Decision
title: "Make the ownership boundary visible in the tree"
adr_id: "0001"
status: accepted
date: "2026-08-18"
description: "Structure the repository so that ownership is legible at the top level: - 🟢 OWN IT — grammar/, gems/, runtimes/: durable, versioned, contract-driven."
okf_version: "0.2"
tags: [repo, extract, rung-4, gold, refusal]
resource: "magentic-stack/docs/adr/0001-ownership-boundary.md"
sources:
  - magentic-stack/docs/adr/0001-ownership-boundary.md
frame:
  layer: repo
  phase: extract
  freezes_at_rung: 4
  evidence: gold
  instrument: refusal
paths:
  - grammar
  - gems
  - runtimes
  - upstreams
enforced_by:
  - tooling/boundary/check_boundary.py
  - tooling/pins/check_pydantic_ai_harness.py
  - .github/workflows/boundary-conformance.yml
generated:
  by: claude-opus-5/claude-code
  at: 2026-09-19
---

# ADR 0001 — Make the ownership boundary visible in the tree

## Decision

Structure the repository so that ownership is legible at the top level: - 🟢 **OWN IT** — `grammar/`, `gems/`, `runtimes/`: durable, versioned, contract-driven. This is the enterprise truth boundary. - 🔵 **OFFICIAL** — `apps/`, `plugins/`: Magentic products that *consume* the owned contracts. - 🟡 **FOLLOW THEM** — `upstreams/`: pinned, never forked; reached via adapters. SHACL shapes and normative profiles are authoritative; code derives from them.

## Context

Frontier AI churns on a ~90-day loop. If the enterprise-facing contract is entangled with upstream runtimes, every upstream change forces a rewrite. Enterprises need a stable language and a bounded governance surface.

## Frame

Layer **repo** (repository / boundary doctrine) · phase **extract** · freezes at **rung 4** · evidence **gold** · instrument **refusal**.

* [Layers](../frame.md#layers) — The tier a path sits in is this frame's WHERE axis; this decision is where it comes from.
* [Thesis](../frame.md#thesis) — Making ownership legible at the top level is the boundary that makes the red curve purchasable.
* [Futures and features](../frame.md#futures-and-features) — A tier is a declaration of which currency that area may spend.
* [Instrument — refusal](../frame.md#instrument-refusal) — Uses the refusal instrument.

## Enforcement

A paid entry in the futures ledger — the constraint has a gate:

* `tooling/boundary/check_boundary.py`
* `tooling/pins/check_pydantic_ai_harness.py`
* `.github/workflows/boundary-conformance.yml`

## Source

* Full record: `magentic-stack/docs/adr/0001-ownership-boundary.md`
* Frame: [One Frame](../frame.md)
