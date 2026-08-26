---
id: "0023"
title: Profile 2 makes an IRI a pass-by-reference handle
status: proposed
date: 2026-08-26
subject_kind: profile
subject: P2
components: [osi-level-8-profiles]
paths:
  - gems/osi-level-8-profiles/profile-2-reference-passing
enforced_by:
  - gems/osi-level-8-profiles/scripts/validate.py
supersedes: null
superseded_by: null
---

## Context

An agent given data by value is given all of it. Context windows make that a
hard limit rather than an inefficiency, and it forces a choice between
truncating what the model sees and sending more than it needs -- both of which
degrade quietly.

## Decision

A JSON-RPC-LD `@id` is a **pass-by-reference handle, portable across process and
trust boundaries**. From that one identification: BACK publishes a typed method
surface, the model reads Context *by reference* with typed bounded previews
dereferenced on demand, and returns structured output as a typed Effect
enforced identically at decode time and at ingest time.

Scope is deliberately minimal. Profile 2 does **not** use the `private_local`
ledger -- it exposes no private data -- and does **not** use `baseVersion`
optimistic concurrency, because Effects are idempotent and keyed by
`operationId`. Both remain defined in the base for deployments that need them.

Where Profile 1 grounds data as typed rows, Profile 2 governs how an agent reads
and acts on that data across the Level 8 boundary.

## Consequences

- The model sees a preview and fetches only what it dereferences.
- Enforcing the same contract at decode and at ingest means a malformed Effect
  is refused in the same terms wherever it is caught.
- **Proposed, not accepted.** The specification is a review-ready draft and there
  is no Ruby implementation; the shapes are validated for well-formedness only,
  with no valid/invalid fixtures. Accepting this would claim a settled decision
  the evidence does not support.
