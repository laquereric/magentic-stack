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

**`operation` derivation (L8-R05 completion, Q8).** `operation` is not free
prose and is not an unbounded coinage from `trigger` text. An author discovers
a valid identifier in exactly one of two ways:

1. **Declared CPCP operation.** If the blocked act is a Profile-9 `ux.*` or
   Profile-11 `meaning.*` method, `operation` **is** that method's `name`.
   Discover it from `ux.profile.describe` (and the meaning-profile describe).
   A dotted identifier that is not in that declared set is invalid.
2. **Surface-action identifier.** If the blocked act is a page affordance,
   `operation` is a kebab-case token `[a-z][a-z0-9-]*` (no dots). Never derive
   it from `trigger` prose. `label` / `trigger` stay human prose.

**Q8 — same-document publication is not required.** A `RefusalNotice` names an
act *not on offer*. Requiring a publishing control on the refusal page forces
either a dummy/unavailable affordance (rejected: validator-driven composition)
or a false claim that the remediation button performs the blocked act
(rejected: fabrication). Forcing a kebab that is not offered to become a
dotted `ux.*` / `meaning.*` name is the wrong layer: domain surface acts are
not Profile-9/11 methods, and collapsing them into `ux.interaction.record`
loses which act was blocked.

The validator **machine-checks** (1), kebab grammar of (2), and — separately —
that `ActionControl` / `DecisionForm` `action`, when present, is itself kebab
`[a-z][a-z0-9-]*` (English in `action` refuses). What it cannot check is *how*
a kebab `operation` was chosen. That hole is real and is not closed by
pretending the page offers the act it is refusing.

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
`interfaces/rails-osi-level-8/data/osi-level-8/fixtures/refusal-notice-conformant.json`.
When this page *offers* the blocked act, the sibling control's `action` is the
same token. When this page *refuses productively*, the sibling control names
the remediation and `operation` names the blocked act — they must not be
forced equal.

**Authoring `operation` (Q7, revised Q8).** Write the page as a tree, not a
payload line. `label` and `trigger` stay human prose; they are not identifiers.
`action` is not a graph-top predicate (that is `UX_UNKNOWN_PREDICATE`).

Two legal surrounding trees.

Offered-and-refused (same token on both nodes) — the Q5 copyable:

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

Productive refusal (Journey D / A3 pattern) — the notice names the blocked
act; the control names the next step. This is not sloppy authoring:

```json
{
  "schemaVersion": "acia/v1",
  "componentRegistryVersion": "ghis-19@1",
  "root": {
    "componentKind": "PageShell",
    "children": [
      {
        "componentKind": "ActionControl",
        "props": {
          "valueJson": {
            "label": "Begin meaning clarification",
            "action": "begin-meaning-clarification"
          }
        }
      },
      {
        "componentKind": "RefusalNotice",
        "props": {
          "valueJson": {
            "operation": "activate-heat-alert-map",
            "reason": "meaning.actability-insufficient",
            "failedCriteria": ["dispute-open"],
            "evidenceRefs": ["cid:page:a3-orientation-activation-refused"],
            "remediation": "Begin meaning clarification, then retry activation.",
            "overridePolicy": "none"
          }
        }
      }
    ]
  }
}
```

Do **not** set the clarification button's `action` to `activate-heat-alert-map`.
That encodes a false claim. `ux.acia.validate` and `ux.contract.check` accept
both trees. A dotted `operation` (`ux.interaction.record`) needs no sibling
control; look it up in `ux.profile.describe`.

Failure modes an author actually hits. The never-raise envelope is
`reason: UX_ACIA_CONTRACT_INVALID` with `because.invalid` naming the field,
unless noted.

| What you wrote | What you see | Fix |
|---|---|---|
| Productive refusal: `operation` is `activate-heat-alert-map` and the only control is the remediation (`begin-meaning-clarification`). | Conforms. This is the intended Q8 shape. | Keep the two tokens distinct. Do not rename the remediation `action` to the blocked act. |
| Unknown dotted name: `operation` is `ux.not.a.method`. | `UX_ACIA_CONTRACT_INVALID`, `because.invalid` includes `operation`. | Use a `name` from `ux.profile.describe` / meaning-profile describe. Do not invent `ux.*` / `meaning.*` identifiers. |
| PascalCase: `operation` is `ActivateHeatAlertMap`. | Same refusal (neither a declared dotted name nor kebab `[a-z][a-z0-9-]*`). | Lowercase kebab, or use a declared dotted name. |
| Action present as prose, not an identifier (wrote-the-page-first). The control’s `action` is English (“Evaluate whether Heat Alert Map Activation may be effected”). | `UX_ACIA_CONTRACT_INVALID`, `because.invalid` includes `action`. Copying that English into `operation` also fails kebab grammar. | Replace the control’s `action` with a kebab that names **what that button does**. If the notice blocks a different act, give `operation` its own kebab. Leave `label` / `trigger` as prose. |
| `action` published as a graph-top predicate instead of inside `props.valueJson`. | `UX_UNKNOWN_PREDICATE`, `because.unknown_predicates` includes `action`. | Move `action` under `props.valueJson`. TypedProps is rdf:JSON; interior keys are not Profile-9 predicates. |

A validator cannot detect a prose-derived kebab on `RefusalNotice` — slugging
`trigger` into `operation` satisfies the machine, and that hole is intended to
stay visible rather than be papered over with a dummy control. The remaining
machine-checkable identifier rule is: dotted `operation` is a declared CPCP
name, and `ActionControl`/`DecisionForm` `action`, when present, is kebab.

**P9-BRD-02 — `inspect` yields a new attested ACIA (R1).** Approved in
principle with an operator condition: every page carries an embedded ACIA
document with `correlation` and `aciaDigest`, and `vv-html-components` refuses
to hydrate on mismatch. That gate runs **once, at load**. Client-side
annotation of the loaded document after Explore is **not** an inspect
projection. It is silent unattested drift: the DOM no longer matches the
attested document and nothing checks it. On a governed review surface that is
worse than a refusal.

An `inspect` PULL (`ux.inspect`) therefore **must** yield a **new** attested
ACIA document — new digest, new correlation — and the consumer **must**
re-gate on arrival. Every explored state is its own governed artifact.

What the projection returns (`@type` `ux:InspectProjectionBundle`):

| Field | Rule |
|---|---|
| `aciaDocument` | Full successor ACIA tree. Envelope stamps `projectionKind=inspect`, `predecessorDigest`, `predecessorCorrelation`, `inspectOriginNodeId`. Request-time only. Writes no relation and mutates no stored record. |
| `aciaDigest` | Canonical `sha256:` digest of that successor document (same algorithm as `ux.acia.validate`). **Must differ** from `predecessorDigest`. |
| `correlationId` | New correlation for this projection. **Must differ** from `predecessorCorrelation`. Caller may supply it; if omitted the server mints one. Reusing the predecessor correlation refuses. |
| `predecessorDigest` / `predecessorCorrelation` | The attested pair of the page that was inspected. Stale predecessor digest (does not match the current page ACIA) refuses `UX_LINEAGE_UNRESOLVED`. |
| `inspectOriginNodeId` | The node that was explored. Unknown origin refuses `UX_LINEAGE_UNRESOLVED`. |
| `tokenSet`, `shownContext`, `page` | Same as `ux.page.get` for the same `pageCid`, except `shownContext` binds the **successor** digest. |

The round trip is required and workable. FRONT already PULLs `ux.page.get` and
`ux.render`. Explore is another PULL plus an atomic replace, not a DOM patch.
Latency is the cost of attestation. If that cost were skipped, the hydrate
gate would be a lie.

What a consumer does when an inspect result arrives:

1. Replace the entire render root HTML (`ux.render` of the new bundle).
2. Replace the embedded JSON-LD package. Set package `correlation` and
   `aciaDigest` to the successor pair. Do not leave the predecessor package
   in the page.
3. Set `data-ux-correlation` and `data-ux-acia-digest` on the new root to
   that same successor pair.
4. Re-run the existing hydrate gate. On mismatch / malformed / no-block:
   leave readable flow; do not apply explore marks.
5. Do **not** patch, annotate, or mutate the predecessor DOM or JSON-LD
   in place. That is the forbidden client-side annotation.

Persisting an inspect projection as a stored ACIA successor
(`ux.acia.mutate.propose` of a `projectionKind=inspect` tree) refuses
`UX_ACIA_CONTRACT_INVALID` with `because.invalid` including
`projectionKind`. Inspect is a request-time projection, like Profile 11
`EligibilityExplanation`.

**R2 — `DrillDownCard.presentationState`.** Approved, inspect-projection
only. Closed domain: `selected | related | likely-hit | suggested |
out-of-scope`. It rides in the `ux:InspectProjectionBundle` successor
`aciaDocument` (`props.valueJson.presentationState` on a `DrillDownCard`).
It is absent on stored trees and on the uninspected board document.
Unknown values, use on any other kind, or use outside `projectionKind=inspect`
refuse `UX_ACIA_CONTRACT_INVALID` with `because.invalid` including
`presentationState`. Persisting it via `ux.acia.mutate.propose` refuses
the same way — never stored.

The renderer surfaces it as **text** in a fixed card-header position:
immediately below the card title, a `span[data-ux-explore-trace]` whose
literal text is `Explore: selected` / `Explore: related` / `Explore: likely
hit` / `Explore: suggested` / `Explore: out of scope`, plus
`data-ux-presentation-state` on the card. It is not a `StatusBadge`, not a
variant, not a `ReferentBridge` field, and not a colour channel. Acceptance
provenance, derived eligibility, and explore state can land on one card at
once; colour cannot carry three signals.

**Unaccepted machine suggestions (folded into R2).** Structural
separation in the current vocabulary: their own `DataList`, bounded by a
`ContextBanner` and heading that name **machine**, **suggestions**, and
**unaccepted**. Never interleaved with accepted cards. `quiet` must not
carry the meaning “unaccepted.” Explore-`suggested` is a transient inspect
mark on a card in that list; it is not the unaccepted-provenance signal.

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
