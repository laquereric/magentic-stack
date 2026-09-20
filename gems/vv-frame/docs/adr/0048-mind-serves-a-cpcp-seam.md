---
type: Architecture Decision
title: "MIND serves its own CPCP seam and owns the NOOA push/pull mapping"
adr_id: "0048"
status: accepted
date: "2026-08-31"
description: "The Python MIND image provides a /cpcp/rpc endpoint, and holds all the logic needed to map NOOA push and pull."
okf_version: "0.2"
tags: [runtimes, expand, rung-2, silver, ledger, mind, rails-cpcp, back]
resource: "magentic-stack/docs/adr/0048-mind-serves-a-cpcp-seam.md"
sources:
  - magentic-stack/docs/adr/0048-mind-serves-a-cpcp-seam.md
frame:
  layer: runtimes
  phase: expand
  freezes_at_rung: 2
  evidence: silver
  instrument: ledger
paths:
  - runtimes/mind-pod/mind
  - gems/rails-cpcp
unenforced: true
generated:
  by: claude-opus-5/claude-code
  at: 2026-09-19
---

# ADR 0048 — MIND serves its own CPCP seam and owns the NOOA push/pull mapping

## Decision

The Python MIND image **provides a `/_cpcp/rpc` endpoint**, and holds all the logic needed to map **NOOA push and pull**.

## Frame

Layer **runtimes** (`runtimes/` — the governed pod) · phase **expand** · freezes at **rung 2** · evidence **silver** · instrument **ledger entry**.

* [The futures ledger](../frame.md#the-futures-ledger) — Declared and not yet gated — a liability booked where a reader can see it.

## Enforcement

No gate named in the source record. The constraint is carried by the record alone.

**Declared unenforced** — a futures liability, booked rather than silent. See [The futures ledger](../frame.md#the-futures-ledger).


> MIND /_cpcp seam is accepted and unbuilt (row 10); stand-in is the current client-only boundary test

## Source

* Full record: `magentic-stack/docs/adr/0048-mind-serves-a-cpcp-seam.md`
* Frame: [One Frame](../frame.md)
