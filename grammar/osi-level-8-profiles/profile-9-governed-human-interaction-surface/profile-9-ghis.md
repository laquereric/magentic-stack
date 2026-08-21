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

**`operation` derivation (L8-R05 completion).** `operation` is not free prose
and is not an unbounded coinage from `trigger` text. An author discovers a
valid identifier in exactly one of two ways:

1. **Declared CPCP operation.** If the blocked act is a Profile-9 `ux.*` or
   Profile-11 `meaning.*` method, `operation` **is** that method's `name`.
   Discover it from `ux.profile.describe` (and the meaning-profile describe).
   A dotted identifier that is not in that declared set is invalid.
2. **Surface-action identifier.** If the blocked act is a page affordance
   (`ActionControl` / `DecisionForm`), `operation` is a kebab-case token
   `[a-z][a-z0-9-]*` (no dots). The same token is the control's `action` when
   that field is already an identifier; otherwise the author publishes one
   token on both the control and the RefusalNotice. Never derive it from
   `trigger` prose.

The validator **machine-checks** (1) and the identifier grammar plus
same-document publication of (2): a non-dotted `operation` must equal an
`action` on an `ActionControl` or `DecisionForm` in the same AciaDocument.
What it cannot check is *how* that kebab token was chosen — “never derive
from trigger prose” remains a human authoring rule.

**`reason` aggregation (L8-R05 completion).** `reason` is **singular**: one
code naming the *governing* defect — the defect the operator must address
first, or the defect that makes the others moot. `failedCriteria` enumerates
**every** independently blocking criterion, including the one that grounds
`reason`. Do not join multiple reason codes into `reason`. Multiple
`failedCriteria` items against one `reason` is the normative shape, not an
exception.

**P9.11 — first architectural proof.** One authorization-review page (`effect-review`),
not a conversion of all eight panels. The page ACIA is `PageShell` plus
`ContextBanner`, `EvidencePanel`, `Timeline`, `Disclosure` (provenance),
`DecisionForm`, `ActionControl`, and a `RefusalNotice` that already carries the
P9.10 payload. `ux.page.get` returns that document as a `PageRenderBundle`;
`ux.render` emits it; a closed decision goes through `ux.interaction.record`.
The eight-panel fixture remains the M1 vocabulary proof and is not this page.

**Canonical copyable RefusalNotice (L8-R05 complete).** Q5 is what an author
copies; Q7 (below) is why. The live tree is `Profile9::Acia.conformant_refusal_document`.
The payload-only snippet is
`interfaces/rails-osi-level-8/data/osi-level-8/fixtures/refusal-notice-conformant.json`
— paste it into `RefusalNotice` `props.valueJson` and pair it with a same-document
control whose `action` is `request-effect`.

**Authoring `operation` (Q7).** Write the page as a tree, not a payload line.
The kebab token is real only when the same string is the control's
`props.valueJson.action` in this AciaDocument. `label` and `trigger` stay human
prose; they are not identifiers. `action` is not a graph-top predicate
(that is `UX_UNKNOWN_PREDICATE`).

Worked example — surrounding tree, same token on both nodes:

```json
{
  "schemaVersion": "acia/v1",
  "componentRegistryVersion": "ghis-19@1",
  "root": {
    "nodeId": "copy-pageshell-1",
    "componentKind": "PageShell",
    "children": [
      {
        "nodeId": "copy-actioncontrol-1",
        "componentKind": "ActionControl",
        "props": {
          "propsSchemaCid": "cid:schema:actioncontrol",
          "valueJson": {
            "label": "Request effect",
            "action": "request-effect"
          }
        }
      },
      {
        "nodeId": "copy-refusalnotice-1",
        "componentKind": "RefusalNotice",
        "props": {
          "propsSchemaCid": "cid:schema:refusalnotice",
          "valueJson": {
            "operation": "request-effect",
            "reason": "meaning.actability-insufficient",
            "failedCriteria": [
              "dispute-open",
              "authorization-reference-missing",
              "outcomes-reference-missing",
              "semantic-activation-missing",
              "actability-receipt-missing"
            ],
            "evidenceRefs": [
              "cid:page:demo-nineteen",
              "https://ex/dispute/after-hours"
            ],
            "remediation": "Clarify the disputed condition, obtain authorization and outcomes references, then create activation and receipt records.",
            "overridePolicy": "none"
          }
        }
      }
    ]
  }
}
```

`ux.acia.validate` and `ux.contract.check` both accept this tree. A dotted
`operation` (`ux.interaction.record`) needs no sibling control; look it up in
`ux.profile.describe` (and the meaning-profile describe).

Failure modes an author actually hits. The never-raise envelope is
`reason: UX_ACIA_CONTRACT_INVALID` with `because.invalid` including `operation`
unless noted. `because` names the offending field, not a prose diagnosis.

| What you wrote | What you see | Fix |
|---|---|---|
| Orphan kebab: `operation` is `activate-heat-alert-map` and no `ActionControl`/`DecisionForm` in this document publishes that `action`. | `UX_ACIA_CONTRACT_INVALID`, `because.invalid` includes `operation`. | Publish the same kebab as `props.valueJson.action` on an `ActionControl` or `DecisionForm` in this AciaDocument, or switch `operation` to a declared dotted CPCP name. |
| Unknown dotted name: `operation` is `ux.not.a.method`. | Same refusal. | Use a `name` from `ux.profile.describe` / meaning-profile describe. Do not invent `ux.*` / `meaning.*` identifiers. |
| PascalCase: `operation` is `ActivateHeatAlertMap`. | Same refusal (it is neither a declared dotted name nor kebab `[a-z][a-z0-9-]*`). | Lowercase kebab, then publish that token on the control; or use a declared dotted name. |
| Action present as prose, not an identifier (the common “wrote the page first” case). The control’s `action` is English (“Evaluate whether Heat Alert Map Activation may be effected”) and `operation` is a slug of the `trigger` (“activate-heat-alert-map”). They do not match, so the kebab is an orphan. Copying the English into `operation` also fails the kebab grammar (spaces, capitals). | Same refusal. | Replace the control’s `action` with a kebab identifier and use that same token as `operation`. Leave `label` / `trigger` as prose. |
| `action` published as a graph-top predicate instead of inside `props.valueJson`. | `UX_UNKNOWN_PREDICATE`, `because.unknown_predicates` includes `action`. | Move `action` under `props.valueJson`. TypedProps is rdf:JSON; interior keys are not Profile-9 predicates. |

A validator cannot detect a prose-derived token, so the same-document
publication requirement is what makes the rule real — an author who invents a
token and then publishes it on a control has satisfied the rule, and that is
intended.

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
