---
type: Architecture Decision
title: "ROLE=LOG is a thirteenth container, and OTEL is the basis for its CPCP contract"
adr_id: "0058"
status: accepted
date: "2026-08-31"
description: "A thirteenth container, ROLE=LOG."
okf_version: "0.2"
tags: [runtimes, expand, rung-2, silver, ledger, log, back, backjob, mind]
resource: "magentic-stack/docs/adr/0058-role-log-is-the-thirteenth-container.md"
sources:
  - magentic-stack/docs/adr/0058-role-log-is-the-thirteenth-container.md
frame:
  layer: runtimes
  phase: expand
  freezes_at_rung: 2
  evidence: silver
  instrument: ledger
paths:
  - runtimes/mind-pod
enforced_by:
  - tooling/pins/check_no_logfire.py
  - tooling/pins/check_genai_spans.py
unenforced: true
generated:
  by: claude-opus-5/claude-code
  at: 2026-09-19
---

# ADR 0058 — ROLE=LOG is a thirteenth container, and OTEL is the basis for its CPCP contract

## Decision

1. **A thirteenth container, `ROLE=LOG`.** Under ADR 0047 that makes it a tenth role on the Rails image. 2. **OTEL is the basis for a CPCP contract governing writes from the other containers.** Target becomes **13 containers, 4 images**.

## Frame

Layer **runtimes** (`runtimes/` — the governed pod) · phase **expand** · freezes at **rung 2** · evidence **silver** · instrument **ledger entry**.

* [The outward signal](../frame.md#the-outward-signal) — Observability governed by a contract rather than emitted at each container's discretion.
* [The futures ledger](../frame.md#the-futures-ledger) — A thirteenth container declared with its contract basis named and its gate outstanding.

## Enforcement

A paid entry in the futures ledger — the constraint has a gate:

* `tooling/pins/check_no_logfire.py`
* `tooling/pins/check_genai_spans.py`

**Declared unenforced** — a futures liability, booked rather than silent. See [The futures ledger](../frame.md#the-futures-ledger).


> ROLE=LOG is decided, unbuilt (row 86). The gap table is not a gate. stand-in is the local refusal floor LOG will govern

## Source

* Full record: `magentic-stack/docs/adr/0058-role-log-is-the-thirteenth-container.md`
* Frame: [One Frame](../frame.md)
