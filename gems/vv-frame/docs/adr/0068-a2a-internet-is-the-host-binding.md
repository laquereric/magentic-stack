---
type: Architecture Decision
title: "Internet A2A is the host/external binding; loopback BACK 404s the well-known Card"
adr_id: "0068"
status: accepted
date: "2026-09-09"
description: "The internet A2A binding is host-published HTTP."
okf_version: "0.2"
tags: [runtimes, expand, rung-2, silver, refusal, a2a, back, rails-cpcp]
resource: "magentic-stack/docs/adr/0068-a2a-internet-is-the-host-binding.md"
sources:
  - magentic-stack/docs/adr/0068-a2a-internet-is-the-host-binding.md
frame:
  layer: runtimes
  phase: expand
  freezes_at_rung: 2
  evidence: silver
  instrument: refusal
paths:
  - gems/rails-cpcp/lib/rails_cpcp/a2a_internet.rb
  - runtimes/mind-pod/app/app/controllers/a2a_internet_controller.rb
  - runtimes/mind-pod/app/config/routes.rb
enforced_by:
  - gems/rails-cpcp/spec/a2a_internet_spec.rb
  - tooling/compose/check_a2a.py
  - tooling/compose/plant_a2a.py
generated:
  by: claude-opus-5/claude-code
  at: 2026-09-19
---

# ADR 0068 — Internet A2A is the host/external binding; loopback BACK 404s the well-known Card

## Decision

1. **The internet A2A binding is host-published HTTP.** Discovery is `GET /.well-known/agent-card.json`. The JSON-RPC frame is `POST /_a2a/rpc`. `preferredTransport` is `HTTP`. Payloads are the same JSON-LD Context / Effect DataParts as intrapod (ADR 0067). This is not a thirteenth container and not an in-pod path (ADR 0066). 2. **Loopback does not speak internet A2A.** `HTTP_BIND=127.0.0.1` (in-pod BACK) 404s the well-known Card and `/_a2a/rpc`. `HTTP_BIND=0.0.0.0` (extract BACK, CI host-published BACK) serves them. Host-published HTTP is a different surface, not a backup path for in-pod calls. 3. **The internet Card must not advertise `nats://nats:4222` or `http://back:3000`.** Those are in-pod addresses. NATS discovery remains `agent/card` on `a2a.<agent>.rpc`. 4. **`POST /_cpcp/rpc` stays CPCP JSON-RPC-LD.** Mixing A2A `message/send` onto that path would break existing CPCP clients. …

## Frame

Layer **runtimes** (`runtimes/` — the governed pod) · phase **expand** · freezes at **rung 2** · evidence **silver** · instrument **refusal**.

* [Layers](../frame.md#layers) — External binding is host-published; the loopback path refuses the discovery document.
* [Overlays](../frame.md#overlays) — Discovery is a property of the published surface, not of the container behind it.
* [Instrument — refusal](../frame.md#instrument-refusal) — Uses the refusal instrument.

## Enforcement

A paid entry in the futures ledger — the constraint has a gate:

* `gems/rails-cpcp/spec/a2a_internet_spec.rb`
* `tooling/compose/check_a2a.py`
* `tooling/compose/plant_a2a.py`

## Source

* Full record: `magentic-stack/docs/adr/0068-a2a-internet-is-the-host-binding.md`
* Frame: [One Frame](../frame.md)
