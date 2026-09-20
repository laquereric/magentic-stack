---
type: Architecture Decision
title: "BACK and BACKJOB are the sole writers of domain state"
adr_id: "0056"
status: accepted
date: "2026-08-31"
description: "BACK and BACKJOB are the sole writers of domain state."
okf_version: "0.2"
tags: [runtimes, extract, rung-3, gold, refusal, back, backjob, persist]
resource: "magentic-stack/docs/adr/0056-back-and-backjob-are-the-writers.md"
sources:
  - magentic-stack/docs/adr/0056-back-and-backjob-are-the-writers.md
frame:
  layer: runtimes
  phase: extract
  freezes_at_rung: 3
  evidence: gold
  instrument: refusal
paths:
  - runtimes/mind-pod/app
enforced_by:
  - tooling/compose/check_two_writers.py
  - runtimes/mind-pod/app/config/domain_writers.json
generated:
  by: claude-opus-5/claude-code
  at: 2026-09-19
---

# ADR 0056 — BACK and BACKJOB are the sole writers of domain state

## Decision

**BACK and BACKJOB are the sole writers of domain state.** Plural. This closes gap 2 as a **declaration, not a fix**. `bin/backjob:37` `Reconciliation.create!` stops being a violation and becomes a declared co-writer's legitimate write. Gap 1 — both roles mounting `mind-data` — becomes the correct arrangement rather than a defect. It also departs from `2026-08-30c`, which held that no two independently failing production roles should share a writable domain-storage volume. That was advice; this is a decision, and the memo did not know the roles were siblings of one application.

## Frame

Layer **runtimes** (`runtimes/` — the governed pod) · phase **extract** · freezes at **rung 3** · evidence **gold** · instrument **refusal**.

* [Instrument — refusal](../frame.md#instrument-refusal) — Sole writers, plural and named: the same shape as a release that exactly one object may stamp.
* [Layers](../frame.md#layers) — A declaration, not a fix — the co-writer becomes legitimate by being named.

## Enforcement

A paid entry in the futures ledger — the constraint has a gate:

* `tooling/compose/check_two_writers.py`
* `runtimes/mind-pod/app/config/domain_writers.json`

## Source

* Full record: `magentic-stack/docs/adr/0056-back-and-backjob-are-the-writers.md`
* Frame: [One Frame](../frame.md)
