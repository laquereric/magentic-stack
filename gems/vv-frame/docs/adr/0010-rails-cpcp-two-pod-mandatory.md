---
type: Architecture Decision
title: "A CPCP Rails deploy is mandatorily two pods"
adr_id: "0010"
status: accepted
date: "2026-08-26"
description: "Project resources as CID-grounded JSON-RPC-LD at /cpcp, as an additive Rails engine."
okf_version: "0.2"
tags: [runtimes, expand, rung-2, silver, refusal, rails-cpcp]
resource: "magentic-stack/docs/adr/0010-rails-cpcp-two-pod-mandatory.md"
sources:
  - magentic-stack/docs/adr/0010-rails-cpcp-two-pod-mandatory.md
frame:
  layer: runtimes
  phase: expand
  freezes_at_rung: 2
  evidence: silver
  instrument: refusal
paths:
  - gems/rails-cpcp/lib
  - gems/rails-cpcp/app
  - gems/rails-cpcp/front
enforced_by:
  - gems/rails-cpcp/spec/rails_cpcp_spec.rb
generated:
  by: claude-opus-5/claude-code
  at: 2026-09-19
---

# ADR 0010 — A CPCP Rails deploy is mandatorily two pods

## Decision

Project resources as CID-grounded JSON-RPC-LD at `/_cpcp`, as an **additive** Rails engine. Deployment is **mandatorily two pods**: Rails is BACK, and a distinct FRONT accessory serves the contract. They are never co-located. The boundary is a network hop because a network hop is a thing that can be observed and blocked, and a module boundary is not. Refusals are envelopes, never exceptions: `{ok: false, error: {reason, because}}`. A boundary that raises hands the caller a stack trace where it needed a reason.

## Context

CPCP -- **coordination-protocol-contract-package** -- is the affordance a deterministic entity grants a non-deterministic one. `direction: :pull` is read access; `direction: :push` is write access, and requires an `operationId`. If the surface that serves the contract is the same process that serves the application, then "what a non-deterministic caller may do" is enforced by code paths inside one address space, and the boundary is a convention.

## Frame

Layer **runtimes** (`runtimes/` — the governed pod) · phase **expand** · freezes at **rung 2** · evidence **silver** · instrument **refusal**.

* [Layers](../frame.md#layers) — The contract surface and the application are separate containers by rule.
* [Instrument — refusal](../frame.md#instrument-refusal) — Never co-located: the boundary is structural, not conventional.

## Enforcement

A paid entry in the futures ledger — the constraint has a gate:

* `gems/rails-cpcp/spec/rails_cpcp_spec.rb`

## Source

* Full record: `magentic-stack/docs/adr/0010-rails-cpcp-two-pod-mandatory.md`
* Frame: [One Frame](../frame.md)
