---
type: Architecture Decision
title: "A never-raise boundary must make its refusals observable"
adr_id: "0054"
status: accepted
date: "2026-08-31"
description: "A never-raise boundary must make its refusals observable"
okf_version: "0.2"
tags: [gems, extract, rung-2, gold, ledger, rails-cpcp, rails-osi-level-8, vv-graph, backjob]
resource: "magentic-stack/docs/adr/0054-never-raise-needs-an-observer.md"
sources:
  - magentic-stack/docs/adr/0054-never-raise-needs-an-observer.md
frame:
  layer: gems
  phase: extract
  freezes_at_rung: 2
  evidence: gold
  instrument: ledger
paths:
  - gems
  - runtimes
enforced_by:
  - tooling/cpcp/check_refusal_observer.py
generated:
  by: claude-opus-5/claude-code
  at: 2026-09-19
---

# ADR 0054 — A never-raise boundary must make its refusals observable

## Decision

*(Stated in the source record; this decision carries its content outside a Decision heading.)*

## Frame

Layer **gems** (`gems/` — owned packages) · phase **extract** · freezes at **rung 2** · evidence **gold** · instrument **ledger entry**.

* [The outward signal](../frame.md#the-outward-signal) — A refusal nobody can observe is indistinguishable from an absence.
* [Failure modes](../frame.md#failure-modes) — Never-raise without observability turns every failure into silence, which reads as success.
* [The futures ledger](../frame.md#the-futures-ledger) — Uses the ledger entry instrument.

## Enforcement

A paid entry in the futures ledger — the constraint has a gate:

* `tooling/cpcp/check_refusal_observer.py`

## Source

* Full record: `magentic-stack/docs/adr/0054-never-raise-needs-an-observer.md`
* Frame: [One Frame](../frame.md)
