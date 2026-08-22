# StewardshipTranslation Board — Visual-Semantics Decisions

**Decision status:** Recommended; no implementation authorized  
**Scope:** Two load-bearing visual-semantics decisions for the Profile 9 Board only.  
**Authority preserved:** The closed `COMPONENT_KINDS`, `VARIANTS`, and `BEHAVIOR_KINDS` remain unchanged except for the separately listed, unapproved Profile 9 proposal in this document.

## Decision summary

The Board must communicate three semantically independent facts without letting appearance substitute for governance. **Acceptance provenance** is structural and must be conveyed by placement. **Eligibility** is a derived Profile 11 request-time outcome and remains the exclusive concern of the eligibility badge/band. **Exploration state** is a transient request-time result and needs a distinct, explicit presentation channel.

| Question | Decision | Primary carrier | Catalog impact |
|---|---|---|---|
| 1. Unaccepted machine suggestion | **Choose C: structural separation in the current vocabulary.** | A dedicated `DataList` of `DrillDownCard`s, bounded by a `ContextBanner` and explicit heading stating that all entries are machine suggestions not yet accepted. | None. |
| 2. Five explore marks | **Choose C: introduce a narrowly scoped `presentationState` field for `DrillDownCard` request projections.** | A visible, textual **Explore trace** in a fixed card-header position, driven by one of five closed transient values. | One unapproved numbered Profile 9 proposal. |

> **Governing rule:** A visual treatment may reinforce a semantic distinction, but it must not be its only carrier when misreading that distinction would create a false governance conclusion.

---

## 1. Question 1 — Unaccepted machine suggestions

### Decision

**Adopt structural separation, using only the current vocabulary.** Every unaccepted machine suggestion must appear only in a dedicated `DataList` of `DrillDownCard`s whose enclosing region begins with a `ContextBanner` and visible heading:

> **Machine suggestions — unaccepted**  
> *These are proposals for review. They are not established meanings and are not eligible as accepted Board content.*

The dedicated list may sit within the relevant Board column, but it must be a separate list from established meanings. A suggestion must not be interleaved with accepted cards in the same `DataList`. If filtering, navigation, disclosure, or drill-down would otherwise remove the enclosing context, the renderer must retain an equivalent visible scope statement, using the existing `ScopeTrail` or `ContextBanner`, before the suggested card is shown.

`quiet` may remain a density or de-emphasis choice inside that region, but **it must never carry the meaning “unaccepted.”** The proposal label may remain as redundant text, but the governing signal is the list boundary and its heading, not a border or a badge.

### Reasoning

The risk is not that a user cannot find a label; it is that a skimming decision maker will treat a machine proposal as an established meaning. A per-card badge requires each viewer to notice a small local treatment before making that judgment. A distinct list changes the reading grammar of the column: first the reader encounters a region-level statement of acceptance status, then every card inside inherits that scope. This is the appropriate visual-semantic level for a provenance distinction applying to every member of a set.

Structural separation also gives the required degradation behavior. With the styling library absent, the document still contains a heading, a context statement, and a separately bounded list in semantic HTML. The distinction does not rely on dashed strokes, muted colors, or a particular token implementation. Thus the governance guarantee survives both visual skimming and styling failure.

| Required condition | Binding decision |
|---|---|
| Placement | Suggestions are in their own `DataList`; they are never interleaved with accepted cards. |
| Region declaration | The list starts with a `ContextBanner` and visible heading, both naming **machine**, **suggestions**, and **unaccepted**. |
| Card relationship | Each member remains a `DrillDownCard` inside that dedicated `DataList`, preserving the fixed card rule. |
| Context retention | A filtered, disclosed, navigated, or drilled-down view repeats the unaccepted-machine scope using existing `ScopeTrail` or `ContextBanner`. |
| Styling role | `quiet`, borders, and an optional card label may reinforce the region; none may be the sole acceptance-provenance signal. |
| Eligibility separation | Suggested cards render **no eligibility band**, as already required. The absence of an eligibility band is not itself the unaccepted signal. |

### Rejected alternatives

**A. Keep `quiet` plus a badge** is rejected. The exact badge wording and placement can improve the current design, but it cannot make the badge load-bearing enough. `quiet` conventionally encodes lower visual priority, not unaccepted provenance; an unstyled or rapidly scanned card can still be read as a minor accepted meaning. Moreover, the Board already needs eligibility badges, and a second badge introduces local competition precisely where acceptance needs to be least ambiguous.

**B. Add a `suggested` variant** is rejected. A new variant would make styling more expressive but leaves the semantic burden on noticing a card-level treatment. It would also expand the catalog to solve a problem that the current structural vocabulary already solves better through separation. A variant may later be desirable as redundant polish, but it is neither necessary nor sufficient for the governance rule.

---

## 2. Question 2 — Five explore marks

### Decision

**Adopt a narrow Profile 9 extension: `DrillDownCard.presentationState`.** It is a request-projection-only, closed field that carries exactly one of the following values when the active interaction is `inspect`:

| Closed value | Required visible text | Decision-making reading |
|---|---|---|
| `selected` | **Explore: selected** | This is the card from which the exploration began. |
| `related` | **Explore: related** | This is contextually connected and merits comparative review. |
| `likely-hit` | **Explore: likely hit** | This is a priority candidate for review; it is not a conclusion or acceptance claim. |
| `suggested` | **Explore: suggested** | This card was surfaced as a proposal by the exploration result; it is not thereby accepted. |
| `out-of-scope` | **Explore: out of scope** | This result was considered and excluded by the active exploration scope; it is not merely unmarked or overlooked. |

The renderer shall display the value as an **Explore trace**: a fixed, visible textual line immediately below the card title and above the card’s body content. The trace begins with the literal prefix `Explore:`. It is a distinct header field, not a `StatusBadge`, not an eligibility band, not a card variant, and not a `ReferentBridge` claim. A semantic HTML representation must retain both the visible text and `data-ux-presentation-state` provenance so the meaning remains available without the styling library.

The Explore trace may use a reserved neutral presentation family to aid scanning, but it must never use eligibility green/red, must not borrow the unaccepted-suggestion treatment, and must not rely on color alone. Its literal text is mandatory. The field is generated only in the `inspect` response projection; it writes no relation, mutates no record, and is prohibited from persisted source records and stored Board trees.

### Reasoning

All five distinctions are decision-bearing. The selected card identifies the comparison anchor. `related` says “consider alongside”; `likely-hit` says “prioritize for probable payoff”; `suggested` says “treat as a proposed lead rather than a conclusion”; and `out-of-scope` records a known exclusion, which is materially different from an absent, not-yet-processed, or unmarked card. Collapsing any of these removes information a steward can act on or audit during exploration.

The existing variant set has insufficient semantic capacity and, more importantly, is the wrong carrier. `emphasis` and `quiet` state visual weight, not a closed five-way exploration result. Overloading either makes a temporary inspect result look like an intrinsic property of the card. `ReferentBridge` is also categorically unavailable: its six required fields define a referent-retention claim, while `likely-hit` and its peers are projection annotations rather than retention claims.

A dedicated transient field makes the distinction explicit, closed, inspect-only, and auditable. The fixed line position creates a stable reading order without competing with the eligibility badge. Direct text supplies degradation and accessibility; presentation tokens can improve scanability but cannot replace the words.

### Rejected alternatives

**A. A `StatusBadge` per card plus variant weight** is rejected. It is economical in catalog terms but visually expensive and semantically overloaded. During exploration, every affected card would gain a badge in a board that already uses a badge for derived eligibility. A decision maker would have to distinguish two small, adjacent badge grammars while also recognizing the unaccepted-machine boundary. Variants would only add imprecise visual weight, not five stable meanings.

**B. Collapse the five states** is rejected. The proposed collapses are not neutral. Treating `related` and `likely-hit` as one state destroys prioritization; treating `out-of-scope` as absence turns a known negative result into an ambiguous no-result; and treating explore-`suggested` as identical to the Question 1 suggestion treatment conflates an inspect result with a card’s acceptance provenance. The collision must be solved through separate carriers, not information loss.

---

## 3. Worst-case card reading

### Scenario

A card is an unaccepted machine suggestion, the active exploration marks it `likely-hit`, and its meaning is not fully clarified. The latter produces the applicable derived Profile 11 **red ineligible** display outcome at request time. This is the hardest case because all three signals are simultaneously visible and each can be mistaken for the other if the Board uses one shared badge/variant grammar.

### Required rendering and reading order

The card appears in the **Machine suggestions — unaccepted** `DataList`, directly beneath that list’s `ContextBanner`. The region, rather than the card styling, tells the decision maker: “this is machine-proposed and not established.” The card title is followed immediately by the separate Explore trace:

> **Explore: likely hit**

The card’s eligibility position then contains the existing red `StatusBadge`, whose visible text must state:

> **Eligibility: not eligible — clarification incomplete**

| Signal | Fixed carrier and location | What the decision maker reads | What it must not imply |
|---|---|---|---|
| Acceptance provenance | The enclosing dedicated `DataList`, headed by its `ContextBanner` | “This is a machine suggestion and has not been accepted.” | It does not mean low priority or ineligibility. |
| Exploration result | The under-title Explore trace, `Explore: likely hit` | “This is a transient, high-priority candidate produced by my current exploration.” | It does not mean accepted, true, retained, or eligible. |
| Eligibility / clarification | The red eligibility `StatusBadge` | “This cannot presently be treated as eligible because clarification is incomplete.” | It does not mean out of scope or rejected as a machine suggestion. |

The card is unambiguous because each signal occupies a different semantic layer and spatial position: **container for provenance, header trace for inspection, badge for eligibility**. The labels remain readable without the style library, and the red/green eligibility channel is never reused. The result is not merely visually differentiated; it is grammatically differentiated.

---

## 4. Unapproved Profile 9 proposal

### Proposal P9-01 — Add `DrillDownCard.presentationState` for transient explore projections

**Status:** Proposed only. This document does not assume approval.

**Change.** Add the optional field `presentationState` to the `DrillDownCard` projection schema. It is valid only in a non-persisted request-time projection produced by `inspect`. Its closed domain is exactly:

```text
selected | related | likely-hit | suggested | out-of-scope
```

The field is absent outside an active `inspect` projection. It is not a relation, is not written to a record, is not serialized into a stored Board tree, and cannot stand in for any of the six mandatory `ReferentBridge` fields.

**Rationale.** The five states cannot be represented truthfully through the nine closed variants, and `StatusBadge` competes with the already load-bearing eligibility badge. A projection-only field supplies a dedicated semantic channel without redefining a component kind, weakening `ReferentBridge`, or overloading `VARIANTS`.

| Blast-radius area | Required consequence if P9-01 is approved |
|---|---|
| Profile 9 schema | Add the optional field with the exact closed domain, projection-only scope, and a prohibition on persistent representation. |
| Validators | Validate the field only on `DrillDownCard` projection output; reject unknown values, non-`inspect` use, persisted-tree use, record mutation, or any attempt to encode it as a `ReferentBridge` relation. |
| Inspection behavior contract | Specify that `inspect` may emit the field but writes no relation and mutates no record. Regression tests must prove this non-mutation rule. |
| Renderer | Render the fixed-position visible Explore trace and the `data-ux-presentation-state` attribute. It must preserve literal text with no styling library. |
| Token set | Add a named, neutral Explore-trace token family, distinct from eligibility green/red and from any suggestion-region reinforcement. Tokens are redundant presentation, not the semantic carrier. |
| Component library | Add the Explore-trace layout and accessible styling rules; do not render it as `StatusBadge` or as a variant-driven card state. |
| Existing trees and stored documents | No stored tree rewrite is authorized or required because the field is forbidden there. Revalidate all existing trees to confirm absence and maintain the closed nineteen/kind constraints. |
| Fixtures and conformance snapshots | Update projection fixtures and renderer/conformance snapshots for all five values, absence outside `inspect`, unstyled fallback, and combinations with eligibility and machine-suggestion provenance. |
| Accessibility and semantic HTML checks | Verify visible text, stable heading order, `data-ux-*` provenance, and that color is never the sole differentiator. |
| Documentation and review guidance | Define the five state meanings and explicitly distinguish explore-`suggested` from the structural unaccepted-machine-suggestion signal. |

No change to `COMPONENT_KINDS`, `VARIANTS`, or `BEHAVIOR_KINDS` is proposed. P9-01 is deliberately narrower than a new visual variant: it adds a closed, transient semantic field exactly where the five-way inspect outcome exists.

## Final decision

Approve the **current-vocabulary structural separation** for unaccepted machine suggestions, and advance **P9-01** for review before any five-state Explore presentation is introduced. These choices preserve the Board’s fundamental distinction between established meaning, request-time eligibility, and transient exploration without pretending that one styling mechanism can safely carry all three.

*Prepared as a decision record from the supplied StewardshipTranslation Board continuity and constraints; no external factual sources were used.*
