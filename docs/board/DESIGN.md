# StewardshipTranslation Workbench — Translation Board

**Artifact type:** Final design specification only; no implementation is proposed.  
**Product location:** A new request-time work surface within the existing StewardshipTranslation Workbench.  
**Companion artifacts:** [Use cases](stewardship_translation_board_use_cases.md) and [single-page rendered mockup](stewardship_translation_board_mockup.png).

## 1. Purpose, boundaries, and continuity

The **Translation Board** makes the current semantic situation intelligible across the existing Workbench journeys. It is a Kanban-like **visual comparison surface**, not a conventional Kanban workflow. Its job is to let an accountable operator trace: what happened; which points were elicited through personal interview; what meaning is being made; what clarification is required; and what may be needed to carry an adequately supported meaning into stewardship action.

The Board is deliberately not a fifth journey. It is a cross-journey, request-time projection that routes work back into the existing flows. In particular, it must not make an interview optional, turn a machine suggestion into an established meaning, treat a color as a stored status, or suggest that a card can become actionable by being dragged to another column.

| Existing journey | Relationship to the Board | Required continuity treatment |
| --- | --- | --- |
| **A — Orientation** | The Board gathers and surveys interview-derived Orientation points. | The first-run invitation and the `Add orientation point` action route to the existing personal-interview collection journey. |
| **B — Meaning clarification** | The Board displays accepted meanings, candidate suggestions, clarification work, and request-time eligibility explanation. | The Board does not persist a band, color, “clarified,” or board-status value. |
| **C — Stewardship translation** | The Board may display a contingent stewardship suggestion and expose requirements for a carry into action. | Displaying a carry is never authorization to effect it. The user enters the existing stewardship flow for any governed action. |
| **D — Productive-refusal walls** | The Board exposes terms that cannot be responsibly carried forward, disputes, and refused stewardship actions. | Every wall reuses the existing Journey D refusal treatment rather than introducing a new board-specific refusal pattern. |

> **Explicit reconciliation with the supplied continuity.** The Board introduces no conflict with the earlier Profile 9 JSON-LD journeys as described: it is an additive Page-level projection across them. The only conflict in the operator specification is the duplicated definition assigned to Meaning and Clarification. The proposed repair is explicitly marked in §3 and is not silently adopted as canonical vocabulary.

The primary user question is therefore not “What column should I move this task into?” It is:

> **“What is presently available for accountable translation, what remains uncertain, and which existing journey is the legitimate next place to work?”**

## 2. Governing design principles

The Board presents a **traceability order**, not a mutable status sequence. Its composition uses the existing closed ACIA vocabulary and existing behavior kinds. Cross-column highlighting is rendered only as a scoped inspection projection. A user may inspect evidence, collect an orientation point, acknowledge a suggestion decision, or navigate into the relevant journey; the user may not drag a Meaning into “clarified,” “eligible,” or “stewardship.”

| Principle | Board consequence |
| --- | --- |
| **Derived eligibility is not a status.** | A band, color, and highlight are request-time display outcomes. They are never stored and never manually set. Attempts to store a meaning band remain refused as `MEANING_BAND_FORBIDDEN`. |
| **Criteria must be inspectable.** | Red or amber is always accompanied by access to the Profile 11 `EligibilityExplanation` projection: criterion identifiers, passing/failing values, and IRI references. |
| **A suggestion is not an established meaning.** | Machine-proposed cards have a distinct border, label, provenance, and “Consider/Decline” path. They do not carry an eligibility band. |
| **A semantic wall remains visible.** | Inability to clarify, disputes, and action refusal use the existing Journey D productive-refusal surface. They are not hidden, called “done,” or compressed into a generic failure color. |
| **Columns express type, not status.** | Inputs, Orientation, Meaning, Clarification, and Stewardship are different referential projections. Their fixed left-to-right order does not authorize movement between them. |

## 3. Terms and the repaired definition distinction

The operator text gives Meaning and Clarification the same definition, “makes a term adequate for accountable planning or effect.” That duplication is treated as a likely copy-paste defect. The following wording is a **proposed correction**, pending confirmation against the established Profile 9/11 terminology.

| Term | Proposed definition | Operator prompt preserved |
| --- | --- | --- |
| **Meaning** | **Meaning makes explicit the working account of what someone is making of a term, event, or input.** | “What am I making of this?” |
| **Clarification** | **Clarification tests and develops that working account until the term is adequate for accountable planning or effect.** | “What clarification do I need?” |

The distinction is necessary for an honest Board: **Meaning is the working account; Clarification is the governed work that tests whether the account is adequate.** A Meaning does not automatically become clarified, plan-eligible, or effect-eligible simply because it is present on the Board.

## 4. Fixed five-column model

The visual order is fixed as **Inputs → Orientation → Meaning → Clarification → Stewardship**. It is a left-to-right account of traceability, from received happenings through accountable possible carry. It is not a workflow state machine and does not mean that a card “moves” from one semantic object type to another.

| Column | One-line purpose in the operator’s frame | Card material | It must never imply |
| --- | --- | --- | --- |
| **Inputs** | **Stuff that happens.** | Email, research, chat, and other received raw happenings; source and receipt time. | That an input has been interpreted, accepted, or made actionable. |
| **Orientation** | **Points gathered through personal interview that make the current semantic situation intelligible.** | Elicited concerns, local context, and interview-derived observations. | That an orientation point is an established meaning. |
| **Meaning** | **What am I making of this?** | Accepted working accounts and separately rendered machine proposals. | That a candidate is agreed, clarified, or authorized. |
| **Clarification** | **What clarification do I need?** | Criterion-related inquiries, evidence, disputes, definition/formalization work, and bindings. | That a completion cue itself changes a Meaning’s derived band. |
| **Stewardship** | **What is required to carry the meaning forward into action?** | Contingent proposals, requirements, authority dependencies, and stewardship-flow links. | That a visible proposal is an approved effect. |

The Board header includes a scope trail, a page title, a concise projection notice, and filters for **Source**, **Referent**, **Evidence**, and **Suggestions**. The persistent context banner reads: **“Eligibility is derived at request time — board position does not change it.”** This puts the non-Kanban constraint in the user’s line of sight before any familiar drag expectation arises.

## 5. Visual language and card anatomy

The intended visual language is restrained and institutional: a warm white/gray ground, graphite text, fine slate rules, compact evidence metadata, low-saturation blue for active inspection, and a small number of carefully labeled band colors. There are no progress-lane backgrounds, confetti cues, gamified completion surfaces, or consumer-SaaS drag handles.

A visual “card” is an existing `DrillDownCard` inside a `DataList`, not a new ACIA Card kind. A visual column is an existing `PanelFrame`, not a new ACIA Column kind.

| Card region | Required rendering | Accountability rule |
| --- | --- | --- |
| **Identity strip** | Item type, stable title, source/interview provenance, and relevant time. | Identifies a referent; it does not invent a generic task title. |
| **Semantic excerpt** | One or two lines that state the input, elicited point, working account, clarification need, or stewardship carry. | It is an excerpt; `Inspect` must reveal the full source/evidence record. |
| **Relationship cue** | Referent/evidence links and the number or identity of related items where appropriate. | A likely-hit cue is a request-time relation, not a persistent assignment. |
| **Eligibility display** | Only applicable to accepted Meanings and dependent views that have a valid Profile 11 computation. | It renders derivation, never a user-selected field. |
| **Evidence cue** | A direct `Inspect eligibility` or `View evidence` control. | Red/amber cannot be an opaque conclusion. |
| **Action row** | `Explore`, `Inspect`, or an entry action into an existing journey. Suggestions additionally use `Consider` and `Decline`. | Actions either inspect a projection or invoke already-authorized journey behavior. |

### 5.1 Derived-band display: why two colors are insufficient

Profile 11 has three derived bands—`explorable`, `plan-eligible`, and `effect-eligible`—plus cases where no eligibility calculation is applicable or available. A green/red binary would collapse materially different conditions. The Board therefore uses four labeled, non-persisted treatments; color assists recognition but the text label remains authoritative.

| Board treatment | Profile 11 source | Board interpretation | Inspection requirement |
| --- | --- | --- | --- |
| **Green — Effect-eligible** | `effect-eligible` derivation. | The Meaning currently meets the derived criteria for accountable effect, subject to separate downstream stewardship authority. | `Inspect eligibility` shows the passing criteria and IRI references. |
| **Amber — Plan-eligible** | `plan-eligible`, but not `effect-eligible`. | Accountable planning may proceed; accountable effect remains unsupported. | The explanation identifies the unsatisfied effect-level criterion/criteria. |
| **Red — Explorable** | `explorable`, but not a higher band. | The Meaning may be explored but is not adequate for accountable planning or effect. This is the honest rendering of “not fully clarified.” | The explanation exposes each passing/failing criterion and the available clarification or refusal path. |
| **Neutral — Eligibility unavailable** | No applicable calculation, insufficient governed material, or an entity type such as Input/Orientation/unaccepted suggestion. | The Board is making no eligibility claim. | It states why calculation is unavailable and offers the appropriate collection or inspection action. |

> **Color rule.** Green means precisely **Effect-eligible**; it does not mean merely “no unmet criteria visible.” Red means precisely **Explorable**; it does not mean “bad,” “rejected,” “failed,” or a stored “not clarified” status. Amber and neutral are mandatory to avoid a dishonest binary.

`EligibilityExplanation` is a request-time projection, not a stored subrecord. The renderer receives the current derived band and criterion-level explanation; it must not save a color, label, or band surrogate back onto Meaning.

### 5.2 Suggested meaning and stewardship treatment

A suggested card is **machine-proposed and unaccepted**. It renders with a dashed/double border, a `Suggested — unaccepted` label, proposal provenance, evidence/referent links, and an explicit qualifier such as “contingent” where necessary. It never adopts the solid visual treatment of an accepted Meaning and never renders a green/amber/red eligibility band.

Selecting **Consider** navigates to the existing governed Meaning/Clarification flow, where a decision surface identifies the suggestion’s origin and evidence and permits only the authorized collection/decision outcome. Selecting **Decline** acknowledges the proposal for the current exploration and removes it from the active suggestion projection, subject to the existing retention/review policy. Neither action silently makes a suggestion established.

A Stewardship suggestion remains equally contingent. It states what must be true before action can be considered—for example, an effect-eligible Meaning and authority review—and it routes to the existing Stewardship journey. Its display is not authorization.

## 6. Interaction model

### 6.1 Add an Orientation point

The Orientation header offers **Add orientation point**, optionally with a plus glyph. It uses `collect_effect` to reveal or route to the existing Orientation collection surface, which names the personal-interview context, source, and referent. When a governed collection outcome is recorded, the next Board projection can display the resulting Orientation card. It does not create a Meaning, a band, a card movement, or a stewardship action.

### 6.2 Explore an Orientation point or raw Input

`Explore` uses **`behaviorKind: inspect`**. It requests a same-page active exploration projection scoped by the selected Input or Orientation referent. The selected origin displays a restrained navy outline. Related accepted Meaning cards and likely Clarification cards receive a matching request-time emphasis grounded in their `ReferentBridge`/evidence relation. Machine proposals appear beside accepted meanings but retain the dashed suggestion treatment.

If inspection finds a relevant Input, an accepted Meaning, and sufficient clarification context, the Stewardship column may show a **Suggested — contingent** carry. That suggestion remains distinct from authorization.

### 6.3 Explore a Meaning

Exploring an accepted Meaning requests an inspection projection focused on related Clarification material. Meaning eligibility remains separately labeled green/amber/red/neutral. Clarification cards may additionally display an evidence cue such as **Evidence complete** (green) or **Evidence missing** (red). Those clarification cues are distinct from the Meaning band and must never be presented as a shortcut to it.

### 6.4 No drag-to-change-status

No card is draggable; there are no drag handles or drop zones. The Board makes this honest without feeling broken by replacing a false affordance with clear, useful actions: **Explore**, **Inspect eligibility**, **Continue clarification**, and **Enter stewardship flow**. If the surrounding host detects an attempted drag gesture, the existing disclosure/refusal language appears: **“Eligibility is derived from evidence and criteria; board position cannot change it.”** It then offers `Inspect eligibility`.

### 6.5 Cross-column highlighting under the closed behavior set

Cross-column highlight is expressible using the existing closed behavior set. `ActionControl: Explore` is an **`inspect`** action. Its result is a request-time Board projection whose `ReferentBridge` data identifies selected, related, likely-hit, suggested, and out-of-scope items. The deterministic renderer applies an emphasis state to the existing `DrillDownCard` nodes. It does not write a relation, mutate a record, or create a drag behavior.

If the current Profile 9 `inspect` contract is detail-only and cannot return a same-page scoped projection, the conditional P9-BRD-02 clarification in §10 is required before implementation.

## 7. Empty, active, and refusal states

### 7.1 First-run and empty states

A new user sees the full five-column model so that the semantic sequence is legible from the beginning. The Orientation column uses an `EmptyState` reading: **“No orientation points yet. Begin a personal interview to make the current semantic situation intelligible.”** Its action routes to Journey A. Meaning, Clarification, and Stewardship retain neutral explanatory empty states rather than presenting fabricated tasks or default machine meanings.

| Situation | Board state |
| --- | --- |
| **No material in the workbench** | Inputs and Orientation show their appropriate empty states; Meaning, Clarification, and Stewardship explain their later role. |
| **Inputs exist but no Orientation point** | Inputs display normally. Orientation names the available context and invites the personal interview; no established Meaning is manufactured. |
| **Orientation exists but no accepted Meaning** | Orientation cards can be explored. Machine proposals appear only within an explicit active exploration and remain unaccepted. |
| **Active exploration** | The selected card and only its relevant likely hits receive a request-time blue emphasis; all other cards stay visible but unaccented. |

### 7.2 Productive-refusal walls

The Board does not leave a red card as a dead end. It preserves the distinction among absent clarification, dispute, and action refusal, and it routes each to Journey D.

| Wall | Board presentation | Journey D continuity |
| --- | --- | --- |
| **A term cannot presently be clarified** | Red **Explorable** label; Eligibility Explanation shows the failed criteria; `RefusalNotice` explains that accountable planning/effect cannot be claimed now. | `Enter productive-refusal wall` carries the referent, evidence, and failed criteria into the existing refusal flow. |
| **A Meaning is disputed** | `EvidencePanel` surfaces the agreement/dispute material; its actual derived red or amber band remains visible. | `Inspect dispute` and the existing productive-refusal route preserve dissent rather than hiding it. |
| **A stewardship action is refused** | `RefusalNotice` gives authority, scope, reason, and next accountable response. The proposed carry remains inspectable. | `Inspect refusal`/acknowledgement reuses the existing Journey D treatment. |

A green/Effect-eligible Meaning does not override a separately refused stewardship action. Meaning eligibility and stewardship authorization are different accountable claims.

## 8. Closed-vocabulary ACIA expression

The Board can be represented using the existing nineteen ACIA kinds. It requires **no `Board`, `Column`, or `Card` kind**, and no new drag behavior. Visual board/column/card terms are composition names only: `PanelFrame` is the board/column surface, `DataList` renders repeated entities, and `DrillDownCard` renders each inspectable item.

```text
PageShell  "StewardshipTranslation Workbench / Translation Board"
├── ScopeTrail  "Workbench / Case / Translation Board"
├── SemanticText  "Translation Board"
├── ContextBanner  "Eligibility is derived at request time; board position does not change it."
├── FilterBar  "Source · Referent · Evidence state · Suggestions"
├── PanelFrame  "Board projection"
│   ├── PanelFrame  "Inputs — stuff that happens"
│   │   ├── SemanticText  "Email, research, chat, and other received material"
│   │   ├── MetricStrip  "Received / in active exploration"
│   │   └── DataList
│   │       └── DrillDownCard*  "Input projection"
│   │           ├── SemanticText  "excerpt + source + received time"
│   │           ├── StatusBadge?  "In active exploration" [presentation-only]
│   │           ├── ReferentBridge  "linked Orientation / Meaning referents"
│   │           └── ActionControl  "Explore" [behaviorKind: inspect]
│   ├── PanelFrame  "Orientation — interview points"
│   │   ├── ActionControl  "Add orientation point" [behaviorKind: collect_effect]
│   │   ├── EmptyState?  "Begin a personal interview" [ActionControl: navigate]
│   │   └── DataList
│   │       └── DrillDownCard*  "Orientation-point projection"
│   │           ├── SemanticText  "elicited point + interview provenance"
│   │           ├── ReferentBridge  "likely / established related referents"
│   │           └── ActionControl  "Explore" [behaviorKind: inspect]
│   ├── PanelFrame  "Meaning — what am I making of this?"
│   │   └── DataList
│   │       └── DrillDownCard*  "Accepted meaning or suggestion projection"
│   │           ├── SemanticText  "working account"
│   │           ├── StatusBadge?  "Effect-eligible | Plan-eligible | Explorable | Eligibility unavailable | Suggested"
│   │           ├── ReferentBridge  "evidence / orientation links"
│   │           ├── ActionControl  "Explore" [behaviorKind: inspect]
│   │           ├── ActionControl?  "Inspect eligibility" [behaviorKind: inspect]
│   │           └── ActionControl?  "Consider / Decline suggestion" [behaviorKind: navigate or acknowledge]
│   ├── PanelFrame  "Clarification — what clarification do I need?"
│   │   └── DataList
│   │       └── DrillDownCard*  "Clarification projection"
│   │           ├── SemanticText  "criterion, inquiry, or evidence excerpt"
│   │           ├── StatusBadge?  "Evidence complete | Evidence missing" [presentation-only]
│   │           ├── ReferentBridge  "linked Meaning"
│   │           └── ActionControl  "Explore / Continue clarification" [inspect or navigate]
│   └── PanelFrame  "Stewardship — carry meaning forward into action"
│       └── DataList
│           └── DrillDownCard*  "Stewardship proposal / requirement projection"
│               ├── SemanticText  "required carry, authority, or dependency"
│               ├── ReferentBridge  "eligible Meaning + Clarification links"
│               ├── ActionControl  "Inspect / Enter stewardship flow" [inspect or navigate]
│               └── RefusalNotice?  "Existing Journey D productive-refusal treatment"
└── PanelFrame  "Selected exploration: evidence and eligibility"
    ├── EvidencePanel  "EligibilityExplanation: criterion IDs, pass/fail values, IRI references"
    ├── ReferentBridge  "Selected item ↔ likely hits ↔ supporting evidence"
    ├── Disclosure  "Show all criteria and provenance"
    └── ActionControl?  "Enter productive-refusal wall" [behaviorKind: navigate]
```

`*` denotes repeated projection instances; `?` denotes conditional instances. Labels such as **Effect-eligible**, **Explorable**, **Evidence complete**, and **Suggested** are data values rendered in existing `StatusBadge` nodes. They are not added component kinds and must not become persisted status fields.

## 9. Rendering/data contract

The Board request takes a case scope, filters, and—only when exploring—a selected referent. The response uses existing source records plus request-time projection material: Profile 11 derived band; `EligibilityExplanation`; evidence/referent links; suggestion provenance; and any Journey D refusal context. The renderer displays only what the scoped projection supports.

| Item | Persisted? | Board handling |
| --- | --- | --- |
| Definition lifecycle, agreement, dispute, formalization, binding | Yes; existing Profile 11 closed dimensions. | Inputs to derivation, not board-editable status controls. |
| `explorable`, `plan-eligible`, `effect-eligible` | No. | Request-time derivation mapped to the labeled display band. |
| Color, active highlight, likely-hit emphasis | No. | Renderer-local response presentation. |
| `EligibilityExplanation` | No. | `EvidencePanel` projection with criterion identifiers, values, and IRI references. |
| Machine proposal | Governed retention may apply; its acceptance is separately governed. | Dashed/unaccepted projection until an authorized decision outcome exists. |

## 10. Profile 9 and Profile 11 revision analysis

### P9-BRD-01 — No new component or behavior kind required

**Proposal:** No Profile 9 closed-vocabulary revision is necessary. Existing `PanelFrame`, `DataList`, `DrillDownCard`, `ReferentBridge`, `EvidencePanel`, `RefusalNotice`, and `ActionControl` components cover the Board. Existing `inspect` covers cross-column exploration; `collect_effect`, `navigate`, and `acknowledge` cover collection and governed routing.

**Approval status:** This is an additive design interpretation, not an assumed schema change. It must be checked against the existing Profile 9 renderer contract.

**Blast radius:** None to the nineteen kinds, behavior set, or existing fifteen storyboards. Only a new Board Page JSON-LD document is added.

### P9-BRD-02 — Conditional `inspect` projection clarification

**Trigger:** Required only if existing `inspect` is constrained to detail-only results and cannot re-render a same-page, referent-scoped projection.

**Proposed revision:** Permit an `inspect` result to carry a request-time Page projection containing selected referent identity, `ReferentBridge` relationship classifications such as `related`, `likely`, and `suggested`, and renderer-local emphasis tokens for existing `DrillDownCard` nodes. No new behavior kind, component kind, persisted highlight, or stored relation is introduced.

**Approval status:** **Not approved; do not assume it.**

**Blast radius:** Profile 9 behavior-result validation; deterministic renderer support for the optional inspection projection; Board-page tests. Existing pages remain valid because the fields are optional and only this Board emits them.

### P11-BRD-01 — No stored Board status or Meaning band

**Proposal:** No Profile 11 schema revision is implied. The Board consumes existing request-time derived bands and `EligibilityExplanation`; it must not add `boardStatus`, `clarified`, a color field, a lane field, or a stored band surrogate.

**Approval status:** Not a schema change. The existing `MEANING_BAND_FORBIDDEN` prohibition remains controlling.

**Blast radius:** None to stored Meaning records, derivation criteria, or data migration. A renderer presentation mapper and fixtures are the only expected impact.

### P11-BRD-02 — Conditional display-label convention

**Trigger:** Required only if Profile 11 does not already specify user-facing labels for its derived bands.

**Proposed revision:** Define a non-persisted presentation convention mapping `explorable`, `plan-eligible`, and `effect-eligible` to the Board labels in §5.1 and defining neutral display for no calculation. The full Eligibility Explanation remains mandatory.

**Approval status:** **Not approved; do not assume it.**

**Blast radius:** Profile 11 presentation documentation, shared renderer tokens, accessibility tests, and any electing page. There is no data migration and no change to the five stored closed dimensions.

## 11. Rendered mockup and design acceptance

The companion image, [`stewardship_translation_board_mockup.png`](stewardship_translation_board_mockup.png), demonstrates one active Orientation exploration. It shows all five populated columns, an active Orientation origin, cross-column likely-hit highlighting, accepted green/Effect-eligible and red/Explorable Meaning states, distinct suggestion treatments, red/green clarification-evidence cues, a contingent Stewardship proposal, and a visible refusal notice. It is illustrative only: its evidence counts, bands, and highlights model request-time projections and must not be treated as stored records.

The design is acceptable for implementation planning only if the following remain true: all five columns stay in traceability order; a board is compositionally expressed with the closed ACIA kinds; `Explore` uses `inspect`; no drag behavior is exposed; red always leads to an Eligibility Explanation; green means only effect-eligible; amber and neutral remain visible; suggestions cannot masquerade as established meanings; first run begins with personal interview; and all walls reuse the existing Journey D productive-refusal treatment.

---

## References

This document uses only the operator specification provided with this request, including the stated Profile 9 component/behavior closure and Profile 11 derivation constraints. No external sources are used.
