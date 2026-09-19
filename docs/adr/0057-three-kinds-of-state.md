---
type: Architecture Decision
title: "Three kinds of state, three owners, and the mission is the division itself"
adr_id: "0057"
status: accepted
date: "2026-08-31"
description: "Three kinds of state, three owners, and the mission is the division itself"
okf_version: "0.2"
tags: [runtimes, extract, rung-3, gold, operate, back, backjob, bus, mind]
resource: "magentic-stack/docs/adr/0057-three-kinds-of-state.md"
sources:
  - magentic-stack/docs/adr/0057-three-kinds-of-state.md
frame:
  layer: runtimes
  phase: extract
  freezes_at_rung: 3
  evidence: gold
  instrument: operate
paths:
  - runtimes/mind-pod
enforced_by:
  - tooling/compose/check_two_writers.py
unenforced: true
generated:
  by: claude-opus-5/claude-code
  at: 2026-09-19
---

# ADR 0057 — Three kinds of state, three owners, and the mission is the division itself

## Decision

*(Stated in the source record; this decision carries its content outside a Decision heading.)*

## Frame

Layer **runtimes** (`runtimes/` — the governed pod) · phase **extract** · freezes at **rung 3** · evidence **gold** · instrument **operate**.

* [Instrument — operate](../frame.md#instrument-operate) — The third kind of state is where an irreversible artifact goes: ephemeral, rebuildable, never cited as truth.
* [The futures ledger](../frame.md#the-futures-ledger) — Three kinds, three owners, and the mission is the division itself.

## Enforcement

A paid entry in the futures ledger — the constraint has a gate:

* `tooling/compose/check_two_writers.py`

**Declared unenforced** — a futures liability, booked rather than silent. See [The futures ledger](../frame.md#the-futures-ledger).


> BUS metadata (row 9) and MIND inference-state kinds are unbuilt. Application-state division is gated by check_two_writers.py (shared with 0056).

## Source

* Full record: `magentic-stack/docs/adr/0057-three-kinds-of-state.md`
* Frame: [One Frame](../frame.md)
