# Level 8 modifications proposed by this design

Designing Oriented Translation against the **closed** Level 8 vocabularies was the
point of the exercise, not an obstacle to it. Where the design could not say
something, that is recorded here as a proposal rather than worked around — a closed
vocabulary that quietly accretes exceptions is no longer closed.

Source: Manus task `CytwP7RoqiXZQK6sqcQKFH`, 2026-08-20. Review-ready; not
independently verified.

## Proposals

| # | Profile | Addition | Why the existing vocabulary cannot say it |
|---|---|---|---|
| 1 | 11 | `meaning:SemanticDispute`, `meaning:DisputeResolution` | `dispute` is a dimension with no object behind it, so an open dispute has no attributable target, scope, or resolution evidence. |
| 2 | 11 | `meaning:StewardshipTranslation` | A steward's audience-specific rendering has no home. It is not a `DefinitionRevision` (it does not compete with the definition) and not an attestation (it asserts nothing about truth). |
| 3 | 11 | `meaning:TranslationReview` | Accepting, returning or rejecting a translation must be attributable and scoped without abusing `DefinitionRevision` or `SemanticAttestation`. |
| 4 | 11 | refusal `meaning.translation-grounding-insufficient` | A translation can be syntactically complete yet not responsibly affirmable as an account of its declared referent. No existing reason says that. |
| 5 | 9 | ACIA kind `ScopeTrail` | The seventeen kinds can show the *current* scope but not scope ancestry or source-to-target movement, which orientation and translation both depend on. |

Proposal 1 lands precisely on an open question the Profile 11 spec named for itself:
*"dispute resolution authority is out of scope: this profile records that a dispute is
open, not who wins it."* The design needed the object the spec deferred.

## Additions considered and rejected

This list matters as much as the one above: it is the evidence that the closed
vocabulary was respected rather than merely tolerated.

| Considered | Rejected because |
|---|---|
| A manually set actability band | Bands are derived per request and never stored. A control that sets one would defeat the profile it is built on. |
| A `translation-ready` / `trusted` Concept dimension | Duplicates the P11 evidence gates, and would make audience wording appear to upgrade meaning. |
| A `DefinitionTranslation` record | Parallels and confuses `DefinitionRevision`. The needed artifact is a rendering grounded in a definition, not one competing with it. |
| A generic comments record | Hides material dispute and review facts in ungoverned prose instead of preserving target, scope, authority, evidence and outcome. |
| A new authorization datatype | Profile 6 already supplies authorization evidence; the design references it by IRI. |

## Unused components, deliberately

`DrillDownCard` and `TabSet` are not used. `DataList` plus `Disclosure` carry record
density without separate card semantics, and page-level work states are clearer than
tabs that could obscure a changed scope. Recorded so a later reviewer does not read
their absence as an oversight.

## Status

None of these are adopted. Each needs the Profile 11 or Profile 9 spec amended,
shapes updated, and conformance tests extended before any implementation depends on
them.
