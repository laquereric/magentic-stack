---
id: "0025"
title: Profile 5 requires omissions in the record to be detectable
status: proposed
date: 2026-08-26
subject_kind: profile
subject: P5
components: [osi-level-8-profiles]
paths:
  - gems/osi-level-8-profiles/profile-5-biography-and-provenance
enforced_by:
  - gems/osi-level-8-profiles/scripts/validate.py
supersedes: null
superseded_by: null
---

## Context

A system that logs everything is not achievable, and a system that claims to is
worse than one that does not: the claim is what a reader trusts when
reconstructing what happened.

## Decision

Profile 5 defines the portable, verifiable **biography** of a Cyborg system: a
causally complete, append-only or bounded-verifiable journal in which every
meaningful state change is grounded, ordered, attributable and reconstructable
-- `BiographyEvent`, `Journal`, `ReconstructionRule`.

The honest part is the scope. The profile does **not** claim an implementation
can preserve every transient machine event. It requires the implementation to
*define and enforce what counts as meaningful*, and to **make omissions
detectable**.

Causal completeness is structural: a `BiographyEvent` with no `causalParent`
fails validation.

## Consequences

- "What happened" is answerable by replay rather than by inference from logs.
- A gap in the record announces itself rather than reading as an absence of
  activity -- which is the difference between a record you can reason from and
  one you can only hope about.
- Each deployment must declare its own meaningfulness boundary. There is no
  default, because a default here is a silent claim about coverage.
- **Proposed, not accepted.** Manus-drafted review-ready draft, no
  implementation.
