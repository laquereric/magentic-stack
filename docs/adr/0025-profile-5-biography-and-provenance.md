---
type: Architecture Decision
title: "Profile 5 requires omissions in the record to be detectable"
adr_id: "0025"
status: proposed
date: "2026-08-26"
description: "Profile 5 defines the portable, verifiable biography of a Cyborg system: a causally complete, append-only or bounded-verifiable journal in which every meaningful state change is gr"
okf_version: "0.2"
tags: [grammar, extract, rung-4, gold, refusal, osi-level-8-profiles]
resource: "magentic-stack/docs/adr/0025-profile-5-biography-and-provenance.md"
sources:
  - magentic-stack/docs/adr/0025-profile-5-biography-and-provenance.md
frame:
  layer: grammar
  phase: extract
  freezes_at_rung: 4
  evidence: gold
  instrument: refusal
paths:
  - gems/osi-level-8-profiles/profile-5-biography-and-provenance
enforced_by:
  - gems/osi-level-8-profiles/scripts/validate.py
generated:
  by: claude-opus-5/claude-code
  at: 2026-09-19
---

# ADR 0025 — Profile 5 requires omissions in the record to be detectable

## Decision

Profile 5 defines the portable, verifiable **biography** of a Cyborg system: a causally complete, append-only or bounded-verifiable journal in which every meaningful state change is grounded, ordered, attributable and reconstructable -- `BiographyEvent`, `Journal`, `ReconstructionRule`. The honest part is the scope. The profile does **not** claim an implementation can preserve every transient machine event. It requires the implementation to *define and enforce what counts as meaningful*, and to **make omissions detectable**. Causal completeness is structural: a `BiographyEvent` with no `causalParent` fails validation.

## Context

A system that logs everything is not achievable, and a system that claims to is worse than one that does not: the claim is what a reader trusts when reconstructing what happened.

## Frame

Layer **grammar** (`grammar/` — the owned language) · phase **extract** · freezes at **rung 4** · evidence **gold** · instrument **refusal**.

* [Failure modes](../frame.md#failure-modes) — Omissions must be detectable — the third-state collapse refused at protocol level.
* [The evidence ladder](../frame.md#the-evidence-ladder) — A causally complete journal is what makes a biography evidence rather than a story.
* [Instrument — refusal](../frame.md#instrument-refusal) — Uses the refusal instrument.

## Enforcement

A paid entry in the futures ledger — the constraint has a gate:

* `gems/osi-level-8-profiles/scripts/validate.py`

## Source

* Full record: `magentic-stack/docs/adr/0025-profile-5-biography-and-provenance.md`
* Frame: [One Frame](../frame.md)
