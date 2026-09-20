---
type: Architecture Decision
title: "Profile 8 makes assumptions inspectable and drift reconciliation gated"
adr_id: "0028"
status: proposed
date: "2026-08-26"
description: "Make joint cognition, assumption visibility, drift reconciliation and frame-change absorption first-class properties."
okf_version: "0.2"
tags: [grammar, extract, rung-4, gold, rung, osi-level-8-profiles]
resource: "magentic-stack/docs/adr/0028-profile-8-architectural-learning-loop.md"
sources:
  - magentic-stack/docs/adr/0028-profile-8-architectural-learning-loop.md
frame:
  layer: grammar
  phase: extract
  freezes_at_rung: 4
  evidence: gold
  instrument: rung
paths:
  - gems/osi-level-8-profiles/profile-8-architectural-learning-loop
enforced_by:
  - gems/osi-level-8-profiles/scripts/validate.py
generated:
  by: claude-opus-5/claude-code
  at: 2026-09-19
---

# ADR 0028 — Profile 8 makes assumptions inspectable and drift reconciliation gated

## Decision

Make joint cognition, assumption visibility, drift reconciliation and frame-change absorption first-class properties. - An **`AssumptionRecord` is inspectable**, so a hardened assumption is a document rather than an inference from behaviour. - Divergence between specification and reality is **measured**, not noticed. - `/learn` is a gated reconciliation Effect with **exactly one human checkpoint before commit**. One, because zero makes reconciliation autonomous and several makes it a meeting. - Adopting, skipping or deferring a recurrent external framework change has a named owner. A `ReconciliationRun` with no checkpoint fails validation, so the gate cannot be omitted by a caller that would rather not wait.

## Context

A delivery team holds a split system model: a human-held model and an agent-held model, meeting in the Spec. Code and shipped artifacts harden assumptions that were never written down, and the two models drift apart without either side observing it -- which is the same failure ADR 0014 describes for architecture, one level down.

## Frame

Layer **grammar** (`grammar/` — the owned language) · phase **extract** · freezes at **rung 4** · evidence **gold** · instrument **freeze rung**.

* [The futures ledger](../frame.md#the-futures-ledger) — A hardened assumption is a document rather than an inference — the ledger's epistemic half.
* [The evidence ladder](../frame.md#the-evidence-ladder) — Drift reconciliation is gated, so a frame change is absorbed rather than silently applied.
* [The freeze ladder](../frame.md#the-freeze-ladder) — Uses the freeze rung instrument.

## Enforcement

A paid entry in the futures ledger — the constraint has a gate:

* `gems/osi-level-8-profiles/scripts/validate.py`

## Source

* Full record: `magentic-stack/docs/adr/0028-profile-8-architectural-learning-loop.md`
* Frame: [One Frame](../frame.md)
