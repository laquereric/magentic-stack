---
id: "0010"
title: A CPCP Rails deploy is mandatorily two pods
status: accepted
date: 2026-08-26
subject_kind: gem
subject: rails-cpcp
components: [rails-cpcp]
paths:
  - gems/rails-cpcp/lib
  - gems/rails-cpcp/app
  - gems/rails-cpcp/front
enforced_by:
  - gems/rails-cpcp/spec/rails_cpcp_spec.rb
supersedes: null
superseded_by: null
---

## Context

CPCP -- **coordination-protocol-contract-package** -- is the affordance a
deterministic entity grants a non-deterministic one. `direction: :pull` is read
access; `direction: :push` is write access, and requires an `operationId`.

If the surface that serves the contract is the same process that serves the
application, then "what a non-deterministic caller may do" is enforced by code
paths inside one address space, and the boundary is a convention.

## Decision

Project resources as CID-grounded JSON-RPC-LD at `/_cpcp`, as an **additive**
Rails engine.

Deployment is **mandatorily two pods**: Rails is BACK, and a distinct FRONT
accessory serves the contract. They are never co-located. The boundary is a
network hop because a network hop is a thing that can be observed and blocked,
and a module boundary is not.

Refusals are envelopes, never exceptions: `{ok: false, error: {reason, because}}`.
A boundary that raises hands the caller a stack trace where it needed a reason.

## Consequences

- The two-pod rule costs an accessory container in every deploy. It is not
  negotiable per-app; an exception would make the contract advisory.
- Idempotency must be durable across deploys, which is why it is backed by
  SQLite `INSERT OR IGNORE` rather than process memory.
- Note the envelope shape differs from the flat `{ok:, reason:, because:}` used
  by the gems. Nesting under `error:` is the JSON-RPC-LD wire shape.
