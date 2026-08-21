# Translation Board — ACIA expression (Q9)

Live tree: `RailsOsiLevel8::Profile9::Acia.translation_board_document`
JSON copy: `translation-board.acia.json` (this directory) and
`interfaces/rails-osi-level-8/data/osi-level-8/fixtures/translation-board.json`.

This is one **request-time projection**: the mockup’s active Orientation
exploration (UC-02) plus the three walls (UC-07, UC-08, UC-09) and the
Kanban-honesty refusal (UC-10). It is not a stored board, not a fifth
journey, and not a first-run empty state (UC-06 is a different projection
of the same page).

Both `Acia.validate` and `Contract.check` accept it.

## 1. The four structural claims

| # | Design claim | Held? |
|---|---|---|
| 1 | A column is an existing `PanelFrame` | **Holds.** Five column `PanelFrame`s inside a board `PanelFrame` (`layoutKind: grid`). No `Column` kind. |
| 2 | A card is an existing `DrillDownCard` inside a `DataList` | **Holds.** No `Card` kind. |
| 3 | Cross-column highlight is `ActionControl` `behaviorKind: inspect`, producing a request-time projection whose **ReferentBridge data** marks selected / related / likely-hit / suggested / out-of-scope | **Does not hold as written.** See below. |
| 4 | Writes no relation, mutates no record, creates no drag behaviour | **Holds.** No drag control, no drop target, no `behaviorKind` invented. UC-10 names the blocked act `drag-card-to-column` on a `RefusalNotice` and offers `inspect-eligibility` / `continue-clarification` instead. |

### Claim 3, precisely

- **`Explore` as `inspect` holds.** Every Explore control is `ActionControl` with `action: explore` and `behaviorKind: inspect`.
- **A request-time projection document holds.** This file *is* that snapshot. Selected origin uses `variant: emphasis` plus `StatusBadge` “Selected — active exploration”. Likely hits use `emphasis`. Suggestions use `variant: quiet` plus `StatusBadge` “Suggested — unaccepted” and **carry no band label**.
- **`ReferentBridge` as the carrier of those five marks does not hold.** `ReferentBridge` is a six-field referent-retention claim (`sourceConcept`, `sourceDefinitionRevision`, `targetExpression`, `mappingArtifact`, `mappingProof`, `sourceToTargetScope`). Missing any field refuses. The five inspect marks are not those fields. Stuffing `relationClass: likely-hit` into `valueJson` would *validate* (unknown interior keys are opaque) and would **bend the kind**. This document does not do that.
- **One real `ReferentBridge`** is present: orientation “evacuate as immediate removal” → meaning “Evacuation notice is an immediate direction to leave”, with actual mapping IRIs. Cards without a mapping (raw inputs, suggestions, most clarification items) do **not** get a fabricated bridge.
- **Same-page inspect as an operation *result*** is still P9-BRD-02, not assumed approved. We authored the projection; we did not extend the inspect contract.

## 2. Q8 rule on this page

Every `ActionControl.action` is kebab naming **what that button does**:
`explore`, `add-orientation-point`, `inspect-eligibility`,
`continue-clarification`, `consider-suggestion`, `decline-suggestion`,
`view-evidence`, `view-proposal`, `view-authority`, `inspect-refusal`,
`enter-productive-refusal-wall`, `inspect-dispute`.

`RefusalNotice.operation` names the **blocked** act and is **not** published
on a control:

| Wall | Blocked `operation` | Offered control |
|---|---|---|
| UC-09 stewardship refused | `issue-unverified-action-language` | `inspect-refusal` |
| UC-07 cannot claim planning/effect | `claim-plan-eligible` | `enter-productive-refusal-wall` |
| UC-10 expected drag-to-status | `drag-card-to-column` | `inspect-eligibility` / `continue-clarification` |

No dummy unavailable control is added to make those operations “published”.

Green/red is a `StatusBadge` **label** on a projection (`Effect-eligible`,
`Explorable`). It is not `actabilityBand` on a stored Meaning.
`MEANING_BAND_FORBIDDEN` is the UC-10 reason. Suggestions have no band.

## 3. Profile 9 / 11 proposals (not assumed approved)

### P9-BRD-01 — No new component or behavior kind

**Status:** Confirmed by this tree. Nineteen kinds suffice for columns, cards,
explore, suggestions, and walls.

**Blast radius:** None to the catalog. One new Page document.

### P9-BRD-02 — Conditional `inspect` projection clarification

**Status:** Still **not approved**. Unchanged from DESIGN.md §10. Required only
if `inspect` must *return* a same-page scoped projection rather than the
client requesting a new Board PULL with a selected referent (which this
document models).

**Blast radius:** Profile 9 behavior-result validation; renderer emphasis
tokens. Existing pages stay valid if fields are optional.

### P9-BRD-03 — Do not extend `ReferentBridge` with inspect marks

**Proposal:** Reject selected / related / likely-hit / suggested /
out-of-scope as `ReferentBridge` properties. Those are request-time
presentation marks. Use `StatusBadge` + `variant` (`emphasis` / `quiet`).
Keep `ReferentBridge` as the retention claim only.

**Approval status:** **Not approved; this is a recommendation against a
design claim, not a schema change.**

**Blast radius:** None if rejected (current validator). If later accepted
as extra ReferentBridge fields: Profile 9 closed props for that kind, the
five-region card renderer, and every existing ReferentBridge fixture.

### P9-BRD-04 — Suggestion visual (dashed/double border) is not a variant

**Trigger:** Closed `VARIANTS` are `default compact expanded quiet emphasis
warning danger disabled readonly`. There is no `dashed` / `suggested`.

**Proposal:** Either (a) treat dashed border as a renderer convention keyed
off a `StatusBadge` label / `valueJson.suggestion=true` (no catalog change),
or (b) add a `suggested` variant to the closed set.

**Approval status:** **Not approved.** This document uses (a): `quiet` +
badge “Suggested — unaccepted”.

**Blast radius:** (a) renderer only. (b) variant catalog, SHACL if variants
are shaped, every renderer.

### P11-BRD-01 — No stored Board status or Meaning band

**Status:** Confirmed. No `boardStatus`, no stored band. Display labels live
on `StatusBadge` in this projection only.

### P11-BRD-02 — Display-label convention

**Status:** Still **not approved**. Board labels Effect-eligible / Plan-eligible
/ Explorable / Eligibility unavailable remain a presentation convention.

## 4. What the closed vocabulary cannot express

- **Connector lines** between a selected card and likely hits (the mockup’s
  navy traces). Not a kind. Renderer decoration of an inspect projection.
- **Dashed/double border** as a first-class variant (P9-BRD-04).
- **Inspect marks on ReferentBridge** without bending the kind (P9-BRD-03).
- **Drag-gesture detection.** Host chrome. ACIA can only refuse the *named
  blocked act* after the fact (UC-10 notice).
- **Five-column Kanban-as-workflow.** Expressible as composition; not
  expressible as movement. That is intended.
- **First-run EmptyState** in *this* snapshot. UC-06 is a different
  projection (`EmptyState` + `begin-personal-interview`). Same page, other
  request. Not missing a kind.
- **FilterBar actually filtering.** Kind and `behaviorKind: filter` exist;
  this snapshot does not execute filters.

Quietly inventing `Board`, `Column`, `Card`, or a drag `behaviorKind` was
not done.
