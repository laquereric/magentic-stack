---
type: Architecture Decision
title: "Profile 11 holds meaning as a governed record"
adr_id: "0008"
status: accepted
date: "2026-08-26"
description: "Profile 11 (osi-level-8/profile-11, vocab https://w3id.org/cpcp/osi8/meaning) makes a definition a governed record with a lifecycle, not a string."
okf_version: "0.2"
tags: [grammar, extract, rung-4, gold, rung, rails-osi-level-8]
resource: "magentic-stack/docs/adr/0008-profile-11-meaning.md"
sources:
  - magentic-stack/docs/adr/0008-profile-11-meaning.md
frame:
  layer: grammar
  phase: extract
  freezes_at_rung: 4
  evidence: gold
  instrument: rung
paths:
  - gems/rails-osi-level-8/lib/rails_osi_level_8/profile11
  - gems/osi-level-8-profiles/profile-11-meaning
enforced_by:
  - gems/rails-osi-level-8/spec/profile11_spec.rb
  - gems/osi-level-8-profiles/scripts/validate.py
generated:
  by: claude-opus-5/claude-code
  at: 2026-09-19
---

# ADR 0008 — Profile 11 holds meaning as a governed record

## Decision

Profile 11 (`osi-level-8/profile-11`, vocab `https://w3id.org/cpcp/osi8/meaning#`) makes a definition a **governed record with a lifecycle**, not a string. Thirteen record types cover the path from proposal to binding and back: `Concept`, `DefinitionRevision`, `SemanticAttestation`, `OperationBinding`, `SemanticActivation`, `ActabilityReceipt`, `SemanticDispute`, `DisputeResolution`, `StewardshipTranslation`, `TranslationReview`, `SemanticAlignmentAssertion`, `FederationAgreement`, `SemanticVerificationEvidence`. Each axis is a closed enumeration: lifecycle `candidate|active|deprecated|withdrawn`, formalization `narrative|structured|testable`, binding `unbound|declared|verified|stale`, dispute `none|open|resolved`.

## Context

A bounded context is a boundary within which a word has one consistent meaning; outside it, the same word means something else. A human resolves that ambiguity by intuition. An agent without a written boundary merges both senses, and does so consistently across a whole module -- which is what makes the damage large before it is visible. So meaning needs somewhere to live that is not a glossary in a wiki.

## Frame

Layer **grammar** (`grammar/` — the owned language) · phase **extract** · freezes at **rung 4** · evidence **gold** · instrument **freeze rung**.

* [The evidence ladder](../frame.md#the-evidence-ladder) — A definition with a lifecycle is a governed record, not a string.
* [The futures ledger](../frame.md#the-futures-ledger) — Thirteen record types cover proposal to binding and back — including the way back.
* [The freeze ladder](../frame.md#the-freeze-ladder) — Uses the freeze rung instrument.

## Enforcement

A paid entry in the futures ledger — the constraint has a gate:

* `gems/rails-osi-level-8/spec/profile11_spec.rb`
* `gems/osi-level-8-profiles/scripts/validate.py`

## Source

* Full record: `magentic-stack/docs/adr/0008-profile-11-meaning.md`
* Frame: [One Frame](../frame.md)
