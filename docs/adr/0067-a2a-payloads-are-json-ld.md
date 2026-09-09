---
id: "0067"
title: A2A payloads are JSON-LD Context and Effect nodes, not nested JSON-RPC
status: accepted
date: 2026-09-09
subject_kind: protocol
subject: a2a
components: [a2a, nats, back, mind, rails-cpcp]
paths:
  - gems/rails-cpcp/lib/rails_cpcp/a2a_binding.rb
  - runtimes/mind-pod/mind/mind_a2a.py
  - runtimes/mind-pod/mind/harness.py
enforced_by:
  - gems/rails-cpcp/spec/a2a_binding_spec.rb
  - tooling/compose/check_a2a.py
  - tooling/compose/plant_a2a.py
supersedes: null
superseded_by: null
---

# A2A payloads are JSON-LD

## Decision

The A2A JSON-RPC **frame** is unchanged (`jsonrpc`, `id`, `method`,
`params` / `result`). Every **payload** it carries — Message, Task,
Agent Card, and the grant inside a DataPart — is JSON-LD 1.1.

A DataPart's `data` **is** a `cpcp:Context` (PULL) or `cpcp:Effect`
(PUSH) node: `@context`, `id`, `type`, `method`, `params`, and
`operationId` on PUSH. It is not `{ "cpcp": { "jsonrpc": "2.0",
"method": "note.list" } }`.

That nest is refused as `a2a_json_not_jsonld`. A dispatcher that still
wants `{ jsonrpc, method, params, operationId }` is an implementation
adapter behind the seam, not the document on `a2a.back.rpc`.

Contract: `coordination-protocol-contract-package` `a2a/internet` and
`a2a/intrapod`. ADR 0066 still holds (A2A is not a container; NATS is
exclusive in-pod). This ADR revises only the payload shape 0066
inherited from the first landing.
