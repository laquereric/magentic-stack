---
id: "0004"
title: OSI Level 8 is the layer where a Cyborg perceives and acts
status: accepted
date: 2026-08-26
subject_kind: protocol
subject: osi-level-8
components: [rails-osi-level-8, rails-cpcp]
paths:
  - gems/rails-osi-level-8/lib/rails_osi_level_8
  - grammar
enforced_by:
  - gems/rails-osi-level-8/spec/rails_osi_level_8_spec.rb
supersedes: null
superseded_by: null
---

## Context

An agent acting on a system needs two things the Application layer does not
define: a way to *perceive* state that is grounded in something it cannot
fabricate, and a way to *act* that a later reader can audit. Left undefined,
every integration invents its own pair, and the resulting surface has no shared
notion of what was seen or what was done.

## Decision

Model the layer above Application explicitly. A **Cyborg** is a responsible
Human + Compute; it **perceives Context** and **acts via Effect**.

- **Context is perception, and maps to a CPCP PULL** (read access).
- **Effect is action, and maps to a CPCP PUSH** (write access).

Both ride grounded JSON-RPC-LD constrained by **closed** SHACL shapes. Closed is
the operative word: a shape that admits unknown predicates cannot refuse an
invented one, and an interface that cannot refuse is not a contract.

OSI Level 8 is a **semantic adapter atop CPCP**, not a competing surface.
`/_cpcp` stays the single public RPC seam.

## Consequences

- Perception and action are distinguishable in evidence, because they are
  different verbs at the protocol level rather than a convention about naming.
- A profile can be added without a new endpoint family; it registers shapes.
- The closed-shape rule means adding a field is a deliberate act with a shape
  change behind it. This is friction, and it is the point.
