---
type: Architecture Decision
title: "Adapters are the only code permitted to reach upstream"
adr_id: "0020"
status: superseded
date: "2026-08-26"
description: "gems/adapters/ is the only code permitted to import from upstreams/."
okf_version: "0.2"
tags: [gems, extract, rung-3, gold, refusal, adapters]
resource: "magentic-stack/docs/adr/0020-adapters-sole-path-to-upstreams.md"
sources:
  - magentic-stack/docs/adr/0020-adapters-sole-path-to-upstreams.md
frame:
  layer: gems
  phase: extract
  freezes_at_rung: 3
  evidence: gold
  instrument: refusal
paths:
  - gems/adapters
  - upstreams
generated:
  by: claude-opus-5/claude-code
  at: 2026-09-19
---

# ADR 0020 — Adapters are the only code permitted to reach upstream

## Decision

`gems/adapters/` is the **only** code permitted to import from `upstreams/`. Upstreams are pinned by revision and never forked. Each adapter wraps one pinned upstream and exposes it through the owned OSI-8 / CPCP contracts, and carries a pin matrix and integration tests so a pin can advance or roll back on evidence.

## Context

Frontier AI churns on roughly a 90-day loop. If the enterprise-facing contract is entangled with upstream runtimes, every upstream change forces a rewrite of the thing that was supposed to be stable. The damage is not the first import. It is the tenth, in ten different files, after which "what would this cost to re-pin" has no answer short of reading everything.

## Frame

Layer **gems** (`gems/` — owned packages) · phase **extract** · freezes at **rung 3** · evidence **gold** · instrument **refusal**.

* [Layers](../frame.md#layers) — Adapters are the only code permitted to reach the upstream tier.
* [Instrument — pin](../frame.md#instrument-pin) — Upstreams are pinned by revision and never forked.
* [Instrument — refusal](../frame.md#instrument-refusal) — Uses the refusal instrument.

## Enforcement

No gate named in the source record. The constraint is carried by the record alone.

## Related decisions

* **Superseded by** [ADR 0030 — The adapters import boundary is enforced by Gate 1](./0030-adapters-boundary-is-enforced.md)

## Source

* Full record: `magentic-stack/docs/adr/0020-adapters-sole-path-to-upstreams.md`
* Frame: [One Frame](../frame.md)
