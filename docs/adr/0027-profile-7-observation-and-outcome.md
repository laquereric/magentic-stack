---
type: Architecture Decision
title: "Profile 7 separates measuring from evaluating from deciding"
adr_id: "0027"
status: proposed
date: "2026-08-26"
description: "Make the business-outcome learning loop a native language property -- observe, act, measure, evaluate, decide, improve -- and keep its stages distinct records."
okf_version: "0.2"
tags: [grammar, extract, rung-4, gold, rung, osi-level-8-profiles]
resource: "magentic-stack/docs/adr/0027-profile-7-observation-and-outcome.md"
sources:
  - magentic-stack/docs/adr/0027-profile-7-observation-and-outcome.md
frame:
  layer: grammar
  phase: extract
  freezes_at_rung: 4
  evidence: gold
  instrument: rung
paths:
  - gems/osi-level-8-profiles/profile-7-observation-and-outcome
enforced_by:
  - gems/osi-level-8-profiles/scripts/validate.py
generated:
  by: claude-opus-5/claude-code
  at: 2026-09-19
---

# ADR 0027 — Profile 7 separates measuring from evaluating from deciding

## Decision

Make the business-outcome learning loop a native language property -- observe, act, measure, evaluate, decide, improve -- and keep its stages **distinct records**. A measurement is not an evaluation; an evaluation is not an `ImprovementDecision`. Outcomes are attributable reward signals connected to the Effects that plausibly produced them **within a declared attribution window**. Declared, because an undeclared window lets an attribution be chosen after the fact to suit the conclusion. An `OutcomeMeasurement` with no `effectRef` fails validation, so a metric floating free of the action it supposedly measures is refused.

## Context

A system that adapts on a metric, where measurement and decision are the same step, changes its future behaviour for reasons no one recorded. It is also the shape in which Goodhart's law does its damage fastest: the metric becomes the target, and the system optimises the number rather than the outcome.

## Frame

Layer **grammar** (`grammar/` — the owned language) · phase **extract** · freezes at **rung 4** · evidence **gold** · instrument **freeze rung**.

* [The outward signal](../frame.md#the-outward-signal) — Measuring, evaluating and deciding stay distinct records — the metric is input to a decision, never the decision.
* [Failure modes](../frame.md#failure-modes) — Collapsing a measurement into an evaluation is the inward-for-outward error at protocol level.
* [The freeze ladder](../frame.md#the-freeze-ladder) — Uses the freeze rung instrument.

## Enforcement

A paid entry in the futures ledger — the constraint has a gate:

* `gems/osi-level-8-profiles/scripts/validate.py`

## Source

* Full record: `magentic-stack/docs/adr/0027-profile-7-observation-and-outcome.md`
* Frame: [One Frame](../frame.md)
