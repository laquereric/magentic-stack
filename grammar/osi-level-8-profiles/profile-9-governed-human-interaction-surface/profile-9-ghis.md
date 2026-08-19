# OSI Level 8 — Profile 9: Governed Human Interaction Surface (GHIS)

**The UX side of OSI Level 8.** Profiles 1–8 govern how a Cyborg's Context and Effect
become typed, durable, auditable machine records. Profile 9 governs how a Cyborg
**perceives that Context and commits those Effects through a human interaction surface** —
so the surface itself is a Level-8 artifact: typed, closed-shape, ledger-placed, and
auditable, rather than ad-hoc HTML.

## Core rule

**HTML is a render target, never a source of truth.** The source is a semantic **ACIA
document** — a typed tree of component nodes, each carrying the semantic-layout tuple
`<semantic-role, content-role, layout-kind, layout-arity, behavior-kind,
responsive-signature, token-signature>`, a closed typed-props schema, an ordered slot
grammar, and a finite variant. No component accepts an arbitrary props bag, free-form
child HTML, or an arbitrary style override. Every durable user-visible change is a
schema-valid ACIA mutation, admitted only after grounding.

## Governed entities (all `sh:closed`, see `shapes/`)

- **Journey / Flow / Page / Touchpoint** — the four-tier model (Journey → Flow → Page →
  Component). Actors, Journeys and Flows are the authoring units; scenarios and components
  derive downward. Maps to `c4:Journey` / `c4:Touchpoint`, `view:Page`, `view:Widget`.
- **AciaDocument / Component (Widget) / SLTTuple / TypedProps / VariantSelection** — the
  semantic component tree and its node contract.
- **DesignTokenSet / DesignToken** — the style layer, kept SEPARATE from structure and
  referenced by each node's `token-signature`.
- **InteractionEvent** — binds a *shown Context* / a *collected Effect* to the exact
  Journey/Flow/Page/Component/token-set that presented or captured it, and to the
  machine-side Context/Effect CIDs of Profiles 1–7. This makes a governance action
  traceable end-to-end.

## DESIGN.md integration

The style layer adopts the **DESIGN.md** format (YAML design tokens + markdown rationale;
see <https://github.com/google-labs-code/design.md>): tokens are the normative values,
prose is the *why*. Tokens become `DesignToken` records; a node's `tokenSignature`
references them. `lint` (WCAG contrast, broken token references) and `diff` (token/prose
regression) run as **grounding checks before an ACIA mutation is admitted** — fail-closed,
never-raise refusal. The file-form DESIGN.md is reconciled with a graph-backed
`DesignMdProjection` so the document is a deterministic projection of accepted parts.

## Ledger & boundary

Every record carries `ux:ledgerPlacement` (`canonical` / `sync_intent` / `private_local`).
`private_local` never crosses the boundary to a browser-facing FRONT. The FRONT is a
DBless projection consumer: it reads render bundles and records interaction events only
through the single `/_cpcp` seam; it holds no database and no write path.

## Realization

Profile 9 is additive over `rails-cpcp` and decorates the `rails-osi-level-8` engine
(no new endpoint family; `/_cpcp` stays the only seam). See the full design brief
`docs/osi-level-8-profile-9-governed-human-interaction-surface.md` for the AR projection,
CPCP `ux.*` operations, canonical component vocabulary, actor-first journeys, and the
KISS delivery plan.

Status: **shape bundle + design brief published.** Conforming valid/invalid example
fixtures are a follow-up (as with Profiles 1–2).
