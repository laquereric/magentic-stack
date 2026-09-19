---
type: Architecture Decision
title: "admission_status is removed; the operation journal is the only admission truth"
adr_id: "0052"
status: accepted
date: "2026-08-31"
description: "Remove OperationRequestadmissionstatus."
okf_version: "0.2"
tags: [gems, extract, rung-3, gold, refusal, rails-osi-level-8, backjob]
resource: "magentic-stack/docs/adr/0052-the-journal-is-the-only-admission-truth.md"
sources:
  - magentic-stack/docs/adr/0052-the-journal-is-the-only-admission-truth.md
frame:
  layer: gems
  phase: extract
  freezes_at_rung: 3
  evidence: gold
  instrument: refusal
paths:
  - gems/rails-osi-level-8/lib/rails_osi_level_8
  - runtimes/mind-pod/app/bin/backjob
enforced_by:
  - tooling/osi/check_admission_status_absent.py
  - tooling/osi/check_admission_indeterminate.py
  - .github/workflows/admission-journal.yml
generated:
  by: claude-opus-5/claude-code
  at: 2026-09-19
---

# ADR 0052 — admission_status is removed; the operation journal is the only admission truth

## Decision

**Remove `OperationRequest#admission_status`.** Admission is derived from the operation journal, which is append-only and already records the real decision.

## Frame

Layer **gems** (`gems/` — owned packages) · phase **extract** · freezes at **rung 3** · evidence **gold** · instrument **refusal**.

* [Instrument — refusal](../frame.md#instrument-refusal) — The column is the affordance, stated as a removal: delete the field and the journal becomes the only answer.
* [Failure modes](../frame.md#failure-modes) — A status column beside an append-only journal is a second truth that will eventually be read as the first.

## Enforcement

A paid entry in the futures ledger — the constraint has a gate:

* `tooling/osi/check_admission_status_absent.py`
* `tooling/osi/check_admission_indeterminate.py`
* `.github/workflows/admission-journal.yml`

## Source

* Full record: `magentic-stack/docs/adr/0052-the-journal-is-the-only-admission-truth.md`
* Frame: [One Frame](../frame.md)
