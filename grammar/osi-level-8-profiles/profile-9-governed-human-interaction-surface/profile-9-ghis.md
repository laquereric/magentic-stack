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

## Canonical component kinds (closed)

The ACIA registry is a closed catalog of **19** kinds. Unknown kinds refuse
`UX_UNKNOWN_COMPONENT_KIND`. Each kind is `sh:closed` (see `shapes/`
`ux:ComponentShape` `sh:in`). This short spec names the kinds and the gaps the
later kinds fill; the full table and panel composition live in
`docs/osi-level-8-profile-9-governed-human-interaction-surface.md`. These two
files are **not** byte-identical mirrors: this file is the profile-dir core
beside the shapes; the docs/ copy is the long design brief.

The prior kinds: `PageShell`, `PanelFrame`, `SemanticText`,
`StatusBadge`, `MetricStrip`, `ContextBanner`, `DrillDownCard`, `DataList`,
`Timeline`, `EvidencePanel`, `DecisionForm`, `ActionControl`, `Disclosure`,
`FilterBar`, `TabSet`, `EmptyState`, `RefusalNotice`.

**`ScopeTrail` (18th).** A non-editable ordered chain of Context/scope IRIs
with relationship labels `contains` | `narrows` | `source` | `target` and
segment applicability. Each segment is drillable; the terminal shows the
effective scope. It exists so a surface can show **scope ancestry** and
**source-to-target scope movement**, which orientation and translation both
depend on. The other kinds cannot say that: `ContextBanner` presents the
*current* Context only; `Timeline` is temporal, not hierarchical; `DataList`
can enumerate relations but cannot establish the directed effective path.
`ScopeTrail` is closed like every other kind — unknown properties refuse;
it does not alter Profile 11 dimensions or derived bands.

**`ReferentBridge` (19th).** One inspectable referent-retention claim. Mandatory
fields: `sourceConcept`, `sourceDefinitionRevision`, `targetExpression`,
`mappingArtifact`, `mappingProof`, `sourceToTargetScope` (non-editable). They
jointly support the assertion. `ScopeTrail` shows scope movement and
`EvidencePanel` lists references, but neither asserts that those particular
references jointly retain the referent. Missing any of the six fields refuses.
Registry version `ghis-19@1`.

**`RefusalNotice` payload (P9.10).** A portable fail-closed refusal. Required
payload: `operation` (blocked operation identifier), `reason` (reason *code*,
not prose), `failedCriteria` (one or more criterion identifiers), `remediation`,
and `overridePolicy` (`none` | `escalate` | `retry_after_remediation`).
`evidenceRefs` (IRIs) are required unless `reason` is in the closed
envelope/shape/token-failure set (`UX_ENVELOPE_INVALID`,
`UX_SHACL_CLOSED_VIOLATION`, `UX_UNKNOWN_PREDICATE`,
`UX_UNKNOWN_COMPONENT_KIND`, `UX_ACIA_CONTRACT_INVALID`, `UX_TOKEN_REF_BROKEN`)
— those name the malformed object itself, so independent evidence IRIs are not
available. The rule is checkable, not taste. Trees missing required parts fail
validation; they are not grandfathered. Checkable from a plain AciaDocument
JSON-LD via `Profile9::Contract`, not only through the renderer.

**P9.11 — first architectural proof.** One authorization-review page (`effect-review`),
not a conversion of all eight panels. The page ACIA is `PageShell` plus
`ContextBanner`, `EvidencePanel`, `Timeline`, `Disclosure` (provenance),
`DecisionForm`, `ActionControl`, and a `RefusalNotice` that already carries the
P9.10 payload. `ux.page.get` returns that document as a `PageRenderBundle`;
`ux.render` emits it; a closed decision goes through `ux.interaction.record`.
The eight-panel fixture remains the M1 vocabulary proof and is not this page.

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
