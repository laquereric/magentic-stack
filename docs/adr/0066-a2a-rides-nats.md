---
type: Architecture Decision
title: "A2A is the in-pod agent envelope; it rides NATS and is not a container"
adr_id: "0066"
status: accepted
date: "2026-09-08"
description: "A2A is not a thirteenth container."
okf_version: "0.2"
tags: [runtimes, extract, rung-2, gold, refusal, a2a, nats, back, mind]
resource: "magentic-stack/docs/adr/0066-a2a-rides-nats.md"
sources:
  - magentic-stack/docs/adr/0066-a2a-rides-nats.md
frame:
  layer: runtimes
  phase: extract
  freezes_at_rung: 2
  evidence: gold
  instrument: refusal
paths:
  - gems/rails-cpcp/lib/rails_cpcp/a2a_binding.rb
  - runtimes/mind-pod/mind/mind_a2a.py
  - runtimes/mind-pod/mind/harness.py
enforced_by:
  - tooling/compose/check_a2a.py
  - tooling/compose/plant_a2a.py
  - tooling/compose/check_nats_exclusive.py
  - gems/rails-cpcp/spec/a2a_binding_spec.rb
generated:
  by: claude-opus-5/claude-code
  at: 2026-09-19
---

# ADR 0066 — A2A is the in-pod agent envelope; it rides NATS and is not a container

## Decision

1. **A2A is not a thirteenth container.** There is no `a2a-server` image. Agent2Agent is an envelope (Agent Card, Message, Task, Part). NATS is still the L7 broker (ADR 0065). BUS is still the metadata seam. 2. **In-pod A2A uses NATS subjects `a2a.<agent>.rpc`.** JSON-RPC methods `agent/card`, `message/send`, `tasks/get` (and the PascalCase aliases). Preferred transport on the Agent Card is `NATS`. No `/.well-known/agent-card.json` in-pod. 3. **HTTP is not a fallback.** Same rule as CPCP-over-NATS. Empty `MM_NATS_URL` may still speak CPCP HTTP for tests and host curl. A set URL that then opens HTTP for A2A is a defect. 4. **A CPCP PDU may travel as `Part.data.cpcp`.** Domain writes still go through Dispatcher. A2A is not a second admission log (ADR 0052). An unsupported part is `rejected`, not an HTTP retry. 5. **v1 listener is BACK only.** MIND is an A2A client of BACK. …

## Frame

Layer **runtimes** (`runtimes/` — the governed pod) · phase **extract** · freezes at **rung 2** · evidence **gold** · instrument **refusal**.

* [Instrument — refusal](../frame.md#instrument-refusal) — Not a thirteenth container: an envelope is refused the status of a component.
* [Layers](../frame.md#layers) — The broker stays the broker and the metadata seam stays the seam.

## Enforcement

A paid entry in the futures ledger — the constraint has a gate:

* `tooling/compose/check_a2a.py`
* `tooling/compose/plant_a2a.py`
* `tooling/compose/check_nats_exclusive.py`
* `gems/rails-cpcp/spec/a2a_binding_spec.rb`

## Source

* Full record: `magentic-stack/docs/adr/0066-a2a-rides-nats.md`
* Frame: [One Frame](../frame.md)
