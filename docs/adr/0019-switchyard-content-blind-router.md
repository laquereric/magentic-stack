---
type: Architecture Decision
title: "The model router is content-blind and holds the credential"
adr_id: "0019"
status: accepted
date: "2026-08-26"
description: "A routing plane owns the credential and decides local-or-remote under policy."
okf_version: "0.2"
tags: [runtimes, extract, rung-3, gold, refusal, switchyard-offline]
resource: "magentic-stack/docs/adr/0019-switchyard-content-blind-router.md"
sources:
  - magentic-stack/docs/adr/0019-switchyard-content-blind-router.md
frame:
  layer: runtimes
  phase: extract
  freezes_at_rung: 3
  evidence: gold
  instrument: refusal
paths:
  - gems/switchyard-offline/shared
  - gems/switchyard-offline/local-listener
  - runtimes/switch
enforced_by:
  - gems/switchyard-offline/tests/listener.test.mjs
  - gems/switchyard-offline/tests/router.test.mjs
  - runtimes/switch/tests/openrouter.test.mjs
generated:
  by: claude-opus-5/claude-code
  at: 2026-09-19
---

# ADR 0019 — The model router is content-blind and holds the credential

## Decision

A routing plane owns the credential and decides local-or-remote under policy. The agent asks for a completion and holds nothing. - **Content-blind.** Routing reads headers, never the body. A router that reads the prompt to decide where to send it has read the prompt. - **Egress is allowlisted and TLS-only.** `validateTarget` refuses any origin outside the frozen list, and any non-`https:` target. - **Local is a separate class, not a widened allowlist.** A local model bypasses the egress gate entirely, because nothing leaves the device and there is no egress decision to make. Admitting `http://ollama:11434` to the allowlist instead would weaken the remote guarantee to buy a local one. - **Two ports.** Data plane is pod-internal and rejects any request carrying an `Origin` header; the config UI is a separate published port that cannot reach the proxy path. …

## Context

An agent that needs a model needs a credential. Giving it one puts a raw secret in the agent container and lets the agent egress directly, which ends default-deny egress as a property of the system.

## Frame

Layer **runtimes** (`runtimes/` — the governed pod) · phase **extract** · freezes at **rung 3** · evidence **gold** · instrument **refusal**.

* [Instrument — refusal](../frame.md#instrument-refusal) — Content-blind routing: the clue is a header. A router that reads the body is refused.
* [Layers](../frame.md#layers) — The credential lives in the routing plane, and the agent holds nothing.

## Enforcement

A paid entry in the futures ledger — the constraint has a gate:

* `gems/switchyard-offline/tests/listener.test.mjs`
* `gems/switchyard-offline/tests/router.test.mjs`
* `runtimes/switch/tests/openrouter.test.mjs`

## Source

* Full record: `magentic-stack/docs/adr/0019-switchyard-content-blind-router.md`
* Frame: [One Frame](../frame.md)
