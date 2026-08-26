---
id: "0024"
title: Profile 3 records a routing decision before the call crosses a boundary
status: proposed
date: 2026-08-26
subject_kind: profile
subject: P3
components: [osi-level-8-profiles, switchyard-offline]
paths:
  - gems/osi-level-8-profiles/profile-3-switchyard
enforced_by:
  - gems/osi-level-8-profiles/scripts/validate.py
supersedes: null
superseded_by: null
---

## Context

Routing an invocation somewhere else is a disclosure. If the decision is made
inside a router and not recorded, then after the fact there is no way to say
which policy applied, what the alternatives were, or why this destination won.

## Decision

Profile 3 answers one bounded question: *given a requested capability, where may
this invocation be served under the user's policy?* Execution classes are
**local** (including Violet Chrome local inference), a preconfigured **direct
API**, and a verified **marketplace** offer.

Before a call crosses an execution boundary it **records a grounded decision**.
Every request, candidate, decision, offer and metric carries a stable `@id` and
`@type` -- `RouteRequest`, `RouteDecision`, `ProviderOffer`, `UsageMetric`.

The governing principle:

> SwitchYard may recommend a destination; it may never create authority to
> disclose payload, override an explicit user rule, or turn a market signal into
> a routing command.

A closed-payload fixture and a missing-`policyDigest` fixture both fail
validation, so "routed without a recorded policy" is refused structurally.

## Consequences

- This is the normative statement of what `switchyard-offline` (ADR 0019)
  implements. The content-blind rule there is the same principle at runtime: a
  router that reads the payload to choose a destination has read the payload.
- A market signal cannot become a command, which bounds what a marketplace can
  do to a deployment that consults it.
- **Proposed, not accepted.** The specification is a Manus-drafted review-ready
  draft whose citations are not independently verified, and the shapes have no
  Ruby implementation behind them.
