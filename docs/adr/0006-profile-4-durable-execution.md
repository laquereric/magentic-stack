---
id: "0006"
title: Profile 4 makes an Effect durable and its receipt evidence
status: accepted
date: 2026-08-26
subject_kind: profile
subject: P4
components: [rails-osi-level-8]
paths:
  - gems/rails-osi-level-8/lib/rails_osi_level_8/ledger.rb
  - gems/osi-level-8-profiles/profile-4-durable-cyborg-execution
  - gems/rails-osi-level-8/lib/rails_osi_level_8/ledger_policy.rb
enforced_by:
  - gems/rails-osi-level-8/spec/rails_osi_level_8_spec.rb
  - gems/osi-level-8-profiles/scripts/validate.py
supersedes: null
superseded_by: null
---

## Context

An Effect that is accepted and then lost is worse than one that is refused: the
caller has been told the world changed. A non-deterministic caller retrying an
Effect it is unsure about must not double-apply it, and cannot know whether to
retry without something durable to ask.

## Decision

Profile 4 (`osi-l8/p4-durable-execution@1`) adds `P4::DurableReceiptShape`: an
Effect returns a receipt that is itself grounded, so "did this happen" is a
question with an answer that survives a restart.

Placement follows the **three-ledger discipline** -- `canonical`,
`sync_intent`, `private_local` -- so where a record lives is a declared property
rather than a consequence of which code path wrote it.

## Consequences

- Retry is safe by construction rather than by the caller's care.
- Every durable write costs a ledger-placement decision. There is no default,
  and that is deliberate: a default placement is the one nobody thinks about.
