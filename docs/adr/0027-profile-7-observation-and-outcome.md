---
id: "0027"
title: Profile 7 separates measuring from evaluating from deciding
status: proposed
date: 2026-08-26
subject_kind: profile
subject: P7
components: [osi-level-8-profiles]
paths:
  - gems/osi-level-8-profiles/profile-7-observation-and-outcome
enforced_by:
  - gems/osi-level-8-profiles/scripts/validate.py
supersedes: null
superseded_by: null
---

## Context

A system that adapts on a metric, where measurement and decision are the same
step, changes its future behaviour for reasons no one recorded. It is also the
shape in which Goodhart's law does its damage fastest: the metric becomes the
target, and the system optimises the number rather than the outcome.

## Decision

Make the business-outcome learning loop a native language property -- observe,
act, measure, evaluate, decide, improve -- and keep its stages **distinct
records**. A measurement is not an evaluation; an evaluation is not an
`ImprovementDecision`.

Outcomes are attributable reward signals connected to the Effects that plausibly
produced them **within a declared attribution window**. Declared, because an
undeclared window lets an attribution be chosen after the fact to suit the
conclusion.

An `OutcomeMeasurement` with no `effectRef` fails validation, so a metric
floating free of the action it supposedly measures is refused.

## Consequences

- A system cannot quietly mutate future behaviour on an unexplained metric,
  because the decision to change is its own record with its own evidence.
- Attribution is arguable on the record rather than assumed.
- More records per loop iteration. That is the cost of being able to ask why the
  system changed.
- **Proposed, not accepted.** Manus-drafted review-ready draft, no
  implementation.
