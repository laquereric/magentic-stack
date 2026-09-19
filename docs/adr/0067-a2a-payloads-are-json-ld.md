---
type: Architecture Decision
title: "A2A payloads are JSON-LD Context and Effect nodes, not nested JSON-RPC"
adr_id: "0067"
status: accepted
date: "2026-09-09"
description: "The A2A JSON-RPC frame is unchanged (jsonrpc, id, method, params / result)."
okf_version: "0.2"
tags: [runtimes, extract, rung-3, gold, rung, a2a, nats, back, mind]
resource: "magentic-stack/docs/adr/0067-a2a-payloads-are-json-ld.md"
sources:
  - magentic-stack/docs/adr/0067-a2a-payloads-are-json-ld.md
frame:
  layer: runtimes
  phase: extract
  freezes_at_rung: 3
  evidence: gold
  instrument: rung
paths:
  - gems/rails-cpcp/lib/rails_cpcp/a2a_binding.rb
  - runtimes/mind-pod/mind/mind_a2a.py
  - runtimes/mind-pod/mind/harness.py
enforced_by:
  - gems/rails-cpcp/spec/a2a_binding_spec.rb
  - tooling/compose/check_a2a.py
  - tooling/compose/plant_a2a.py
generated:
  by: claude-opus-5/claude-code
  at: 2026-09-19
---

# ADR 0067 — A2A payloads are JSON-LD Context and Effect nodes, not nested JSON-RPC

## Decision

The A2A JSON-RPC **frame** is unchanged (`jsonrpc`, `id`, `method`, `params` / `result`). Every **payload** it carries — Message, Task, Agent Card, and the grant inside a DataPart — is JSON-LD 1.1. A DataPart's `data` **is** a `cpcp:Context` (PULL) or `cpcp:Effect` (PUSH) node: `@context`, `id`, `type`, `method`, `params`, and `operationId` on PUSH. It is not `{ "cpcp": { "jsonrpc": "2.0", "method": "note.list" } }`. That nest is refused as `a2a_json_not_jsonld`. A dispatcher that still wants `{ jsonrpc, method, params, operationId }` is an implementation adapter behind the seam, not the document on `a2a.back.rpc`. Contract: `coordination-protocol-contract-package` `a2a/internet` and `a2a/intrapod`. ADR 0066 still holds (A2A is not a container; NATS is exclusive in-pod). This ADR revises only the payload shape 0066 inherited from the first landing.

## Frame

Layer **runtimes** (`runtimes/` — the governed pod) · phase **extract** · freezes at **rung 3** · evidence **gold** · instrument **freeze rung**.

* [Layers](../frame.md#layers) — The frame is unchanged and every payload is the owned grammar's node types.
* [The evidence ladder](../frame.md#the-evidence-ladder) — A payload that is a contract node rather than nested calls is inspectable by the same shapes.
* [The freeze ladder](../frame.md#the-freeze-ladder) — Uses the freeze rung instrument.

## Enforcement

A paid entry in the futures ledger — the constraint has a gate:

* `gems/rails-cpcp/spec/a2a_binding_spec.rb`
* `tooling/compose/check_a2a.py`
* `tooling/compose/plant_a2a.py`

## Source

* Full record: `magentic-stack/docs/adr/0067-a2a-payloads-are-json-ld.md`
* Frame: [One Frame](../frame.md)
