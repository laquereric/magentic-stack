---
type: Architecture Decision
title: "Profile 6 makes authorization structural evidence, never ambient permission"
adr_id: "0026"
status: proposed
date: "2026-08-26"
description: "Authorization is structural evidence: a policy-versioned AuthorizationDecision bound to a subject, an action, a resource, and the boundary-crossing Effect it authorizes."
okf_version: "0.2"
tags: [grammar, extract, rung-4, gold, refusal, osi-level-8-profiles]
resource: "magentic-stack/docs/adr/0026-profile-6-authorization-evidence.md"
sources:
  - magentic-stack/docs/adr/0026-profile-6-authorization-evidence.md
frame:
  layer: grammar
  phase: extract
  freezes_at_rung: 4
  evidence: gold
  instrument: refusal
paths:
  - gems/osi-level-8-profiles/profile-6-enterprise-authorization-evidence
enforced_by:
  - gems/osi-level-8-profiles/scripts/validate.py
generated:
  by: claude-opus-5/claude-code
  at: 2026-09-19
---

# ADR 0026 — Profile 6 makes authorization structural evidence, never ambient permission

## Decision

Authorization is **structural evidence**: a policy-versioned `AuthorizationDecision` bound to a subject, an action, a resource, and the boundary-crossing Effect it authorizes. `CredentialRef` and `Revocation` complete the set. A **credential reference is not a credential secret**, and the distinction is enforced rather than advised -- the `invalid-literal-secret` fixture must fail validation. A profile that permitted an inline secret would put credentials into exactly the durable, portable, replicated records this layer exists to produce. Default-deny from the base profile is preserved. Deliberately out of scope: any particular policy language, credential format, identity provider or cryptographic scheme.

## Context

Ambient permission -- the call succeeded, so it must have been allowed -- cannot be audited, delegated accountably, or revoked with confidence. Nobody can say which policy version permitted a specific boundary crossing, because nothing recorded it.

## Frame

Layer **grammar** (`grammar/` — the owned language) · phase **extract** · freezes at **rung 4** · evidence **gold** · instrument **refusal**.

* [The evidence ladder](../frame.md#the-evidence-ladder) — Authorization as structural evidence is the protocol form of performance is not authority.
* [Instrument — refusal](../frame.md#instrument-refusal) — Ambient permission is refused: a decision must be bound to subject, action, resource and effect.

## Enforcement

A paid entry in the futures ledger — the constraint has a gate:

* `gems/osi-level-8-profiles/scripts/validate.py`

## Source

* Full record: `magentic-stack/docs/adr/0026-profile-6-authorization-evidence.md`
* Frame: [One Frame](../frame.md)
