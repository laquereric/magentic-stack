---
type: Architecture Decision
title: "Profile 10 has closed shapes, held in step with its validator"
adr_id: "0031"
status: accepted
date: "2026-08-26"
description: "P10 gets closed SHACL shapes: gems/osi-level-8-profiles/profile-10-intent/, vocabulary https://w3id.org/cpcp/osi8/intent, seventeen node shapes, all sh:closed, one per type in Vali"
okf_version: "0.2"
tags: [grammar, extract, rung-4, gold, refusal, rails-osi-level-8, osi-level-8-profiles, vv-base]
resource: "magentic-stack/docs/adr/0031-profile-10-has-shapes.md"
sources:
  - magentic-stack/docs/adr/0031-profile-10-has-shapes.md
frame:
  layer: grammar
  phase: extract
  freezes_at_rung: 4
  evidence: gold
  instrument: refusal
paths:
  - gems/osi-level-8-profiles/profile-10-intent
  - gems/rails-osi-level-8/lib/rails_osi_level_8/intent
enforced_by:
  - gems/osi-level-8-profiles/scripts/validate.py
  - gems/osi-level-8-profiles/scripts/check_p10_alignment.py
  - gems/rails-osi-level-8/spec/rails_osi_level_8_spec.rb
generated:
  by: claude-opus-5/claude-code
  at: 2026-09-19
---

# ADR 0031 — Profile 10 has closed shapes, held in step with its validator

## Decision

P10 gets closed SHACL shapes: `gems/osi-level-8-profiles/profile-10-intent/`, vocabulary `https://w3id.org/cpcp/osi8/intent#`, seventeen node shapes, all `sh:closed`, one per type in `Validator::SHAPE_PREDICATES`. The shapes encode the constraints the validator already enforced, rather than a tidier version of them: `digest` must match `^sha256:`, a Persona must carry a `backingCohortCid`, an `IntentGrounding` requires all five references and may not be `private_local`, an `IntentTrace` must be `committed`. **And the two are held in step.** `scripts/check_p10_alignment.py` compares, per type, the properties the shape admits against the ones the allowlist admits, and fails Gate 2 on divergence in either direction. Without it this would be a second copy of one rule, drifting at its own rate -- the failure ADR 0014 exists to name. …

## Context

ADR 0029 recorded P10's decision and, honestly, its gap: every other profile carried closed SHACL under `gems/osi-level-8-profiles/`, and P10 existed only as Ruby. It was the one profile invisible to Gate 2. The sharpest evidence was in the implementation's own words. `validator.rb` describes itself as a *"closed-shape validator (Ruby allowlist over compiled SHACL vocab)"* -- over a SHACL vocabulary that had never been written. The allowlist was not derived from a contract; …

## Frame

Layer **grammar** (`grammar/` — the owned language) · phase **extract** · freezes at **rung 4** · evidence **gold** · instrument **refusal**.

* [Instrument — refusal](../frame.md#instrument-refusal) — Seventeen closed node shapes, one per type — an undeclared predicate has nowhere to land.
* [The futures ledger](../frame.md#the-futures-ledger) — Shapes held in step with the validator: two documents agreeing is not an invariant.
* [Trajectory](../frame.md#trajectory) — Closed shapes over intent keep the aim a contract rather than a note, so a second reader gets the same aim.

## Enforcement

A paid entry in the futures ledger — the constraint has a gate:

* `gems/osi-level-8-profiles/scripts/validate.py`
* `gems/osi-level-8-profiles/scripts/check_p10_alignment.py`
* `gems/rails-osi-level-8/spec/rails_osi_level_8_spec.rb`

## Related decisions

* **Supersedes** [ADR 0029 — Profile 10 binds an Effect to the intent that motivated it](./0029-profile-10-intent.md)

## Source

* Full record: `magentic-stack/docs/adr/0031-profile-10-has-shapes.md`
* Frame: [One Frame](../frame.md)
