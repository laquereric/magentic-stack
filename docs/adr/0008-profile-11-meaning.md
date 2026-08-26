---
id: "0008"
title: Profile 11 holds meaning as a governed record
status: accepted
date: 2026-08-26
subject_kind: profile
subject: P11
components: [rails-osi-level-8]
paths:
  - gems/rails-osi-level-8/lib/rails_osi_level_8/profile11
enforced_by:
  - gems/rails-osi-level-8/spec/profile11_spec.rb
supersedes: null
superseded_by: null
---

## Context

A bounded context is a boundary within which a word has one consistent meaning;
outside it, the same word means something else. A human resolves that ambiguity
by intuition. An agent without a written boundary merges both senses, and does
so consistently across a whole module -- which is what makes the damage large
before it is visible.

So meaning needs somewhere to live that is not a glossary in a wiki.

## Decision

Profile 11 (`osi-level-8/profile-11`, vocab `https://w3id.org/cpcp/osi8/meaning#`)
makes a definition a **governed record with a lifecycle**, not a string.

Thirteen record types cover the path from proposal to binding and back:
`Concept`, `DefinitionRevision`, `SemanticAttestation`, `OperationBinding`,
`SemanticActivation`, `ActabilityReceipt`, `SemanticDispute`,
`DisputeResolution`, `StewardshipTranslation`, `TranslationReview`,
`SemanticAlignmentAssertion`, `FederationAgreement`,
`SemanticVerificationEvidence`.

Each axis is a closed enumeration: lifecycle `candidate|active|deprecated|withdrawn`,
formalization `narrative|structured|testable`, binding
`unbound|declared|verified|stale`, dispute `none|open|resolved`.

## Consequences

- "What does this term mean here, who attested to it, and is that attestation
  still bound to a live operation" is queryable.
- `stale` is a first-class binding state, so a definition drifting away from the
  operation it describes is a condition the system can report rather than a
  discovery someone makes later.
- Disagreement is modelled (`SemanticDispute`) instead of being resolved by
  whoever edits last.
