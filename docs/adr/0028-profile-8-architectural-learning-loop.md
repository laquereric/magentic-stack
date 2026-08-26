---
id: "0028"
title: Profile 8 makes assumptions inspectable and drift reconciliation gated
status: proposed
date: 2026-08-26
subject_kind: profile
subject: P8
components: [osi-level-8-profiles]
paths:
  - gems/osi-level-8-profiles/profile-8-architectural-learning-loop
enforced_by:
  - gems/osi-level-8-profiles/scripts/validate.py
supersedes: null
superseded_by: null
---

## Context

A delivery team holds a split system model: a human-held model and an agent-held
model, meeting in the Spec. Code and shipped artifacts harden assumptions that
were never written down, and the two models drift apart without either side
observing it -- which is the same failure ADR 0014 describes for architecture,
one level down.

## Decision

Make joint cognition, assumption visibility, drift reconciliation and
frame-change absorption first-class properties.

- An **`AssumptionRecord` is inspectable**, so a hardened assumption is a
  document rather than an inference from behaviour.
- Divergence between specification and reality is **measured**, not noticed.
- `/learn` is a gated reconciliation Effect with **exactly one human checkpoint
  before commit**. One, because zero makes reconciliation autonomous and several
  makes it a meeting.
- Adopting, skipping or deferring a recurrent external framework change has a
  named owner.

A `ReconciliationRun` with no checkpoint fails validation, so the gate cannot be
omitted by a caller that would rather not wait.

## Consequences

- The machine assembles the evidence; the human makes the call. Reversing those
  is not automating governance, it is dismantling it.
- Absorbing a frame change is an owned decision rather than something that
  happens to the codebase.
- **Proposed, not accepted.** Manus-drafted review-ready draft, no
  implementation.
