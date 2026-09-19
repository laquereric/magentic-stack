---
type: Architecture Decision
title: "FRONT is a Bun container; Rails FRONT is a proxy-only stopgap"
adr_id: "0072"
status: accepted
date: "2026-09-14"
description: "FRONT is a container whose language is Bun (JavaScript runtime)."
okf_version: "0.2"
tags: [runtimes, expand, rung-2, silver, pin, front, rails-base, front-base]
resource: "magentic-stack/docs/adr/0072-front-is-bun.md"
sources:
  - magentic-stack/docs/adr/0072-front-is-bun.md
frame:
  layer: runtimes
  phase: expand
  freezes_at_rung: 2
  evidence: silver
  instrument: pin
paths:
  - runtimes/front-base
  - docs/architecture/CANONICAL.md
  - docs/adr/0047-three-languages-container-boundaries-own-images.md
enforced_by:
  - tooling/compose/check_language_rule.py
  - tooling/pins/check_published_images.py
generated:
  by: claude-opus-5/claude-code
  at: 2026-09-19
---

# ADR 0072 — FRONT is a Bun container; Rails FRONT is a proxy-only stopgap

## Decision

1. **FRONT is a container whose language is Bun** (JavaScript runtime). One image: `front-base`. Overlays `FROM` that digest. 2. **BACK and BACKJOB stay Rails.** Compile, journal, `ui.*`, `front.*`, blob, board stay on BACK. 3. **The browser carve-out in 0047 remains.** In-page JS (`vv-html-components`, skeleton, Stage override) is still not a fourth container language. Bun is how that JS is **served and packed**. 4. **`ROLE=front` on a Rails image is a proxy-only stopgap.** It is not the application host. New overlays do not add ERB product chrome on Rails FRONT. 5. **SWITCH remains a known 0047 violation** (Node, target Rust). This ADR does not clear that row.

## Frame

Layer **runtimes** (`runtimes/` — the governed pod) · phase **expand** · freezes at **rung 2** · evidence **silver** · instrument **pin**.

* [Failure modes](../frame.md#failure-modes) — Extract without Expand, flagged by its own authors: swapped but unproven end to end.
* [Instrument — pin](../frame.md#instrument-pin) — The floor file is the pin that makes the swap a decision rather than a drift.
* [Overlays](../frame.md#overlays) — Overlays build from that digest, so the base image is a contract with consumers it cannot see.

## Enforcement

A paid entry in the futures ledger — the constraint has a gate:

* `tooling/compose/check_language_rule.py`
* `tooling/pins/check_published_images.py`

## Related decisions

* **Amends** [ADR 0047 — Three languages, container boundaries only, one image per container](./0047-three-languages-container-boundaries-own-images.md)

## Source

* Full record: `magentic-stack/docs/adr/0072-front-is-bun.md`
* Frame: [One Frame](../frame.md)
