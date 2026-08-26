---
id: "0031"
title: Profile 10 has closed shapes, held in step with its validator
status: accepted
date: 2026-08-26
subject_kind: profile
subject: P10
components: [rails-osi-level-8, osi-level-8-profiles, vv-base]
paths:
  - gems/osi-level-8-profiles/profile-10-intent
  - gems/rails-osi-level-8/lib/rails_osi_level_8/intent
enforced_by:
  - gems/osi-level-8-profiles/scripts/validate.py
  - gems/osi-level-8-profiles/scripts/check_p10_alignment.py
  - gems/rails-osi-level-8/spec/rails_osi_level_8_spec.rb
supersedes: "0029"
superseded_by: null
---

## Context

ADR 0029 recorded P10's decision and, honestly, its gap: every other profile
carried closed SHACL under `gems/osi-level-8-profiles/`, and P10 existed only as
Ruby. It was the one profile invisible to Gate 2.

The sharpest evidence was in the implementation's own words. `validator.rb`
describes itself as a *"closed-shape validator (Ruby allowlist over compiled
SHACL vocab)"* -- over a SHACL vocabulary that had never been written. The
allowlist was not derived from a contract; it *was* the contract, in a form no
gate could read and no other implementation could conform to.

## Decision

P10 gets closed SHACL shapes: `gems/osi-level-8-profiles/profile-10-intent/`,
vocabulary `https://w3id.org/cpcp/osi8/intent#`, seventeen node shapes, all
`sh:closed`, one per type in `Validator::SHAPE_PREDICATES`.

The shapes encode the constraints the validator already enforced, rather than a
tidier version of them: `digest` must match `^sha256:`, a Persona must carry a
`backingCohortCid`, an `IntentGrounding` requires all five references and may not
be `private_local`, an `IntentTrace` must be `committed`.

**And the two are held in step.** `scripts/check_p10_alignment.py` compares, per
type, the properties the shape admits against the ones the allowlist admits, and
fails Gate 2 on divergence in either direction. Without it this would be a second
copy of one rule, drifting at its own rate -- the failure ADR 0014 exists to
name. The checker **fails closed**: unreadable Ruby, unparsable Turtle, or zero
types found are all errors, because a drift check that finds nothing to compare
and reports success is worse than no check.

## Consequences

- P10 is no longer the exception. Every profile in the tree is validated by
  Gate 2, and the validator now reports 11.
- P10 has the tree's most thorough fixture coverage -- one valid and six invalid,
  one per enforced rule -- so each constraint is proven to *refuse*, not merely
  to parse.
- Changing P10's contract now takes two edits, and forgetting either fails the
  build. That friction is the mechanism working.
- The shapes were recovered from the implementation rather than the implementation
  derived from the shapes, which inverts ADR 0009 for this one profile. The
  alignment check makes the inversion safe going forward; it does not pretend it
  did not happen.
- Not addressed: the alignment check reads `SHAPE_PREDICATES` with a regex. It is
  regular by construction and the check fails closed if it stops matching, but it
  is a text scan, not a Ruby parse.
