---
type: Architecture Decision
title: "NATS is the 12th container, the in-pod L7 broker; BUS remains the metadata seam"
adr_id: "0065"
status: accepted
date: "2026-09-08"
description: "nats is a twelfth running container in mind-pod."
okf_version: "0.2"
tags: [runtimes, expand, rung-2, silver, pin, nats, bus, back, vault]
resource: "magentic-stack/docs/adr/0065-nats-is-the-in-pod-l7-broker.md"
sources:
  - magentic-stack/docs/adr/0065-nats-is-the-in-pod-l7-broker.md
frame:
  layer: runtimes
  phase: expand
  freezes_at_rung: 2
  evidence: silver
  instrument: pin
paths:
  - runtimes/mind-pod/docker-compose.yml
  - runtimes/mind-pod/app/extract/compose.yml
  - tooling/compose/check_nats.py
  - tooling/compose/language_rule.json
  - gems/rails-cpcp/lib/rails_cpcp/nats_binding.rb
enforced_by:
  - tooling/compose/check_nats.py
  - tooling/compose/plant_nats.py
  - tooling/compose/check_language_rule.py
  - gems/rails-cpcp/spec/nats_binding_spec.rb
  - tooling/compose/check_nats_exclusive.py
  - tooling/compose/plant_nats_exclusive.py
generated:
  by: claude-opus-5/claude-code
  at: 2026-09-19
---

# ADR 0065 — NATS is the 12th container, the in-pod L7 broker; BUS remains the metadata seam

## Decision

1. **`nats` is a twelfth running container** in mind-pod. It is the official `nats-server` image, digest-pinned, unpublished, with JetStream on a named volume `nats-data`. It is the same *class* of thing as `graph` (oxigraph): third-party, unforked, we ship no source into it. 2. **It is not `ROLE=bus`.** BUS remains the Rails CPCP seam plus an async sqlite projection of metadata derived from BACK's journal (ADR 0050 amendment 2, row 18). NATS is Level 7 transport. BUS may later *publish* as a NATS client; it must never *be* the broker. 3. **In-pod CPCP rides NATS.** JSON-RPC-LD envelopes travel on `cpcp.<role>.rpc` request-reply. The payload is the same PDU HTTP carries; NATS headers carry `Authorization`. OSI L8 §10.2: HTTP and NATS MUST preserve identical Level 8 semantics. JetStream sequence numbers MUST NOT replace `operationId`. 4. **HTTP inside the pod can be disabled. …

## Frame

Layer **runtimes** (`runtimes/` — the governed pod) · phase **expand** · freezes at **rung 2** · evidence **silver** · instrument **pin**.

* [Instrument — pin](../frame.md#instrument-pin) — The official image, digest-pinned and unpublished — a followed component held at a number.
* [Layers](../frame.md#layers) — The same class of thing as the graph: infrastructure we run but do not author.

## Enforcement

A paid entry in the futures ledger — the constraint has a gate:

* `tooling/compose/check_nats.py`
* `tooling/compose/plant_nats.py`
* `tooling/compose/check_language_rule.py`
* `gems/rails-cpcp/spec/nats_binding_spec.rb`
* `tooling/compose/check_nats_exclusive.py`
* `tooling/compose/plant_nats_exclusive.py`
* `tooling/compose/check_http_bind.py`
* `tooling/compose/plant_http_bind.py`

## Source

* Full record: `magentic-stack/docs/adr/0065-nats-is-the-in-pod-l7-broker.md`
* Frame: [One Frame](../frame.md)
