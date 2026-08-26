---
id: "0029"
title: Profile 10 binds an Effect to the intent that motivated it
status: superseded
date: 2026-08-26
subject_kind: profile
subject: P10
components: [rails-osi-level-8, vv-base]
paths:
  - gems/rails-osi-level-8/lib/rails_osi_level_8/intent
enforced_by:
  - gems/rails-osi-level-8/spec/rails_osi_level_8_spec.rb
supersedes: null
superseded_by: "0031"
---

## Context

An Effect records that something was done and, via Profile 6, that it was
allowed. Neither says what it was *for*. Without that, a reviewer reconstructs
motive from the change itself, which is the least reliable evidence available
and the easiest to rationalise after the fact.

## Decision

Profile 10 (`osi-level-8/profile-10`) is **INTENT**. It projects the platform
models -- Journey, Flow, Mission, Vision, whose canonical home is `vv-base` per
ADR 0015 -- into deterministic P10 CIDs, materializes a Journey into an
`IntentGrounding` in the graph, and decorates effect commit with a `TraceGate`
that requires an `IntentTrace`.

The projection is **read-only** and its CIDs are deterministic, so the same
intent yields the same identity and grounding cannot be forged by re-deriving it
differently.

## Consequences

- "Why was this done" is grounded in the same way as "what was done", rather
  than living in a commit message.
- `TraceGate` refuses an effect commit with no intent trace, which is friction on
  every write and is the point.
- **P10 has no shapes directory.** Every other profile carries closed SHACL under
  `gems/osi-level-8-profiles/`; P10 exists only as Ruby. So P10 is the one
  profile whose contract is enforced by its implementation rather than by a
  shape the implementation is checked against, and it is invisible to Gate 2.
  Recorded as a gap, not resolved here -- see `docs/adr/README.md`.
