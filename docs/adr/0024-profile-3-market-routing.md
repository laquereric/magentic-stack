---
type: Architecture Decision
title: "Profile 3 records a routing decision before the call crosses a boundary"
adr_id: "0024"
status: proposed
date: "2026-08-26"
description: "Profile 3 answers one bounded question: given a requested capability, where may this invocation be served under the user's policy? Execution classes are local (including Violet Chr"
okf_version: "0.2"
tags: [grammar, extract, rung-4, gold, rung, osi-level-8-profiles, switchyard-offline]
resource: "magentic-stack/docs/adr/0024-profile-3-market-routing.md"
sources:
  - magentic-stack/docs/adr/0024-profile-3-market-routing.md
frame:
  layer: grammar
  phase: extract
  freezes_at_rung: 4
  evidence: gold
  instrument: rung
paths:
  - gems/osi-level-8-profiles/profile-3-switchyard
enforced_by:
  - gems/osi-level-8-profiles/scripts/validate.py
generated:
  by: claude-opus-5/claude-code
  at: 2026-09-19
---

# ADR 0024 — Profile 3 records a routing decision before the call crosses a boundary

## Decision

Profile 3 answers one bounded question: *given a requested capability, where may this invocation be served under the user's policy?* Execution classes are **local** (including Violet Chrome local inference), a preconfigured **direct API**, and a verified **marketplace** offer. Before a call crosses an execution boundary it **records a grounded decision**. Every request, candidate, decision, offer and metric carries a stable `@id` and `@type` -- `RouteRequest`, `RouteDecision`, `ProviderOffer`, `UsageMetric`. The governing principle: > SwitchYard may recommend a destination; it may never create authority to > disclose payload, override an explicit user rule, or turn a market signal into > a routing command. A closed-payload fixture and a missing-`policyDigest` fixture both fail validation, so "routed without a recorded policy" is refused structurally.

## Context

Routing an invocation somewhere else is a disclosure. If the decision is made inside a router and not recorded, then after the fact there is no way to say which policy applied, what the alternatives were, or why this destination won.

## Frame

Layer **grammar** (`grammar/` — the owned language) · phase **extract** · freezes at **rung 4** · evidence **gold** · instrument **freeze rung**.

* [The evidence ladder](../frame.md#the-evidence-ladder) — Recording the routing decision before the call crosses makes the boundary auditable.
* [Instrument — refusal](../frame.md#instrument-refusal) — Where an invocation may be served is a policy answer, not a caller preference.
* [The freeze ladder](../frame.md#the-freeze-ladder) — Uses the freeze rung instrument.

## Enforcement

A paid entry in the futures ledger — the constraint has a gate:

* `gems/osi-level-8-profiles/scripts/validate.py`

## Source

* Full record: `magentic-stack/docs/adr/0024-profile-3-market-routing.md`
* Frame: [One Frame](../frame.md)
