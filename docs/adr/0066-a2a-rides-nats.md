---
id: "0066"
title: A2A is the in-pod agent envelope; it rides NATS and is not a container
status: accepted
date: 2026-09-08
subject_kind: topology
subject: a2a
components: [a2a, nats, back, mind]
paths:
  - gems/rails-cpcp/lib/rails_cpcp/a2a_binding.rb
  - runtimes/mind-pod/mind/mind_a2a.py
  - runtimes/mind-pod/mind/harness.py
enforced_by:
  - tooling/compose/check_a2a.py
  - tooling/compose/plant_a2a.py
  - tooling/compose/check_nats_exclusive.py
  - gems/rails-cpcp/spec/a2a_binding_spec.rb
supersedes: null
superseded_by: null
---

# A2A rides NATS

## Decision

1. **A2A is not a thirteenth container.** There is no `a2a-server` image.
   Agent2Agent is an envelope (Agent Card, Message, Task, Part). NATS is
   still the L7 broker (ADR 0065). BUS is still the metadata seam.
2. **In-pod A2A uses NATS subjects `a2a.<agent>.rpc`.** JSON-RPC methods
   `agent/card`, `message/send`, `tasks/get` (and the PascalCase aliases).
   Preferred transport on the Agent Card is `NATS`. No
   `/.well-known/agent-card.json` in-pod.
3. **HTTP is not a fallback.** Same rule as CPCP-over-NATS. Empty
   `MM_NATS_URL` may still speak CPCP HTTP for tests and host curl.
   A set URL that then opens HTTP for A2A is a defect.
4. **A CPCP PDU may travel as `Part.data.cpcp`.** Domain writes still go
   through Dispatcher. A2A is not a second admission log (ADR 0052). An
   unsupported part is `rejected`, not an HTTP retry.
5. **v1 listener is BACK only.** MIND is an A2A client of BACK. Other
   roles keep CPCP-over-NATS.

## Why not a container

A2A has no third-party broker analogous to `nats-server` or oxigraph.
A new Rails ROLE would be another HTTP process we just bound to
loopback. The addressing problem is already solved by NATS subjects.

## Why not A2A-over-HTTP in-pod

Official A2A JSON-RPC-over-HTTP is a host/external binding, the same
class as extract BACK `:13002`. Using it between MIND and BACK would
re-open the docker-network HTTP surface ADR 0065 closed.

## Consequences

- MIND `rpc()` wraps CPCP in `message/send` on `a2a.back.rpc` when
  `MM_NATS_URL` is set, and unwraps the Task artifact back to CPCP.
- Agent Card `additionalInterfaces` name the NATS URL and subject, not
  `http://back:3000`.
- Tasks are an in-process map on BACK, not journal rows.
