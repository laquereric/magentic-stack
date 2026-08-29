---
id: "0042"
title: The seam refuses what the protocol forbids
status: accepted
date: 2026-08-29
subject_kind: protocol
subject: closed-shape enforcement
components: [rails-osi-level-8, osi-level-8-profiles]
paths:
  - gems/rails-osi-level-8/lib/rails_osi_level_8/grounding.rb
  - gems/rails-osi-level-8/data/osi-level-8
  - tooling/shacl/shape_compiler.py
enforced_by: [tooling/shacl/check_shape_runtime_artifact.py]
supersedes: null
superseded_by: null
---

# The seam refuses what the protocol forbids

## Context

Step 5 built a compiler interface that compiles TTL and Ruby to a common IR and
compares them at the seven live wrap sites. It recorded **11 divergences** and
reconciled none, because reconciling is an owner decision.

The substantive one: `osi:P1NoteCreateEffectShape` declares `sh:closed true` and
enumerates its allowed paths. The Ruby branch checks the idempotency key, the
title, and refuses a client-supplied `ledgerPlacement` -- and never rejects an
unknown key. The code says so itself: `# Closed-ish`.

**So the seam admits properties the protocol declares forbidden**, on
`note.create` and `note.list`. The TTL was never executed at request time; it
documented a refusal that did not happen.

## Decision

**Close the Ruby to match the TTL.** Where a shape declares `sh:closed true`,
Grounding refuses keys outside the declared set. The recorded divergence count
goes to zero by changing the enforcement, not by relaxing the declaration.

The alternative -- relax the TTL to describe what Ruby actually does -- was
rejected. It would make the protocol document the implementation rather than
constrain it, and `sh:closed` on a request shape exists precisely so a client
cannot smuggle in fields the server never agreed to.

## This changes admission behaviour, deliberately

Requests carrying undeclared properties that the seam previously **admitted**
will now be **refused**. That is the point of the decision, not a side effect.
It must ship with an admission regression run and the changed cases approved as
changed, per step 7 of the shape-gem plan.

## Mechanism: explicit allow-lists, not codegen

The allow-list is written in the Ruby branch, duplicating the TTL's declared
set. Duplication is normally the exact drift this arc exists to remove -- but
`check_shape_runtime_artifact.py` now fails in **both** directions (a property
in Ruby but not TTL, and in TTL but not Ruby), each plant proven to name the
offending property. The anti-drift guard already exists, so the simpler
mechanism is the right one. Generating Ruby from TTL stays available if the
allow-lists later become numerous enough to justify a build step.

## The checker must be able to confirm the fix

`RubyBackend.shapes` currently hardcodes `closed = False` for every shape. That
is accurate today, since Grounding has no closedness mechanism at all -- but it
means `closed_mismatch` would keep being reported after this decision is
implemented. It over-reports, which is the safe direction, yet a checker that
cannot observe success is not evidence. The backend must **detect** the
closedness mechanism as part of implementing this ADR.

## Consequences

- 11 recorded divergences resolve to 0; the ledger records the resolution.
- A previously-accepted request shape may now be refused; this is a
  behaviour change requiring regression evidence, not a silent fix.
- `sh:ignoredProperties` becomes load-bearing: envelope keys the seam itself
  carries must stay declared, or closing the shape will refuse the seam's own
  traffic.
