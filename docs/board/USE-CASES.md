# StewardshipTranslation Workbench — Board Page Use Cases

**Status:** Design scenarios only. They describe intended, governed behavior for the Board page and reuse the existing journeys rather than specifying implementation.

## Reading these scenarios

Each scenario is anchored in the operator’s stated **THEN** clauses. “Highlight” means a request-time inspection projection: an outlined or otherwise emphasized existing `DrillDownCard` grounded by referent/evidence links. It does not mean a stored relation, status, or workflow movement. Green, amber, and red labels are likewise derived/request-time display values, not editable card states.

| Term used below | Intended interpretation |
| --- | --- |
| **Accepted meaning** | A meaning already present in the governed record. Its Profile 11 eligibility band may be derived for the current request. |
| **Suggested meaning** | A machine-proposed, unaccepted candidate. It is visually and semantically distinct from an accepted meaning and has no eligibility-band claim. |
| **Eligibility Explanation** | The Profile 11 request-time projection that identifies the relevant criteria, pass/fail values, and IRI references. |
| **Productive-refusal wall** | The existing Journey D treatment for a condition that cannot responsibly be carried forward. |

## UC-01 — Add an orientation point from the Orientation column

**Actor:** Maya, a community liaison conducting the personal interview.  
**Precondition:** Maya is in a valid workbench case and is gathering context with the person or group affected by emergency-message wording. The Board may already contain inputs, but it has no orientation point for this concern.

Maya opens the Board and reads the Orientation column’s framing sentence: **“Interview points that make the situation intelligible.”** She selects **Add orientation point** in the Orientation header.

**THEN** the Board routes Maya to the existing Journey A collection surface with the case scope and personal-interview context already supplied. It does not open a generic task composer. Maya records the elicited point, “Residents hear ‘evacuate’ as immediate removal,” including the interview provenance and referent. After the governed collection action is completed, the Board’s next request-time projection displays the orientation point as an Orientation card.

**THEN** no Meaning, band, green/red color, or stewardship action is automatically created. The new point only makes a specific interview-derived context available for later exploration.

## UC-02 — Explore an Orientation card to reveal related and suggested meanings

**Actor:** Maya, community liaison.  
**Precondition:** The Board contains Maya’s orientation point, “Residents hear ‘evacuate’ as immediate removal,” a set of accepted meanings, and machine proposals that may be relevant to that point.

Maya selects **Explore** on the Orientation card.

**THEN** the Board performs an `inspect` request and re-renders as an **active exploration** rooted in that orientation point. The selected Orientation card has an active outline. The Meaning column highlights accepted meanings with referent/evidence links judged relevant in the request-time projection. The Board also renders separately labeled **Suggested — unaccepted** meaning cards where a machine has proposed a possible account.

**THEN** an accepted Meaning card that derives as `effect-eligible` is rendered with the green label **Effect-eligible**. An accepted Meaning card that derives only as `explorable` is rendered with the red label **Explorable**, not “failed” or “not clarified.” An amber `plan-eligible` card remains distinguishable from both. A machine suggestion has no green, amber, or red band label.

**THEN** Maya can select `Inspect eligibility` on a red/Explorable card and see the Profile 11 Eligibility Explanation: criterion identifiers, their passing/failing values, and IRI references. The Board never stores the highlight or the red label as a property of the Meaning.

## UC-03 — Explore a Meaning to reveal likely Clarification work

**Actor:** Daniel, terminology steward.  
**Precondition:** Daniel is viewing an accepted Meaning, “Protective action may mean staying or leaving,” which has a current derived band of `explorable` because material agreement and binding are not met.

Daniel selects **Explore** on the Meaning card.

**THEN** the Board performs `inspect` and renders related Clarification cards as likely hits in the Clarification column. It emphasizes “Test families’ interpretation of protective action” and “Formalize local terminology reference,” while preserving the Meaning’s current red **Explorable** display.

**THEN** the Clarification cards expose their own evidence condition, separately labeled from the Meaning band. “Duty officer wording agreement signed” can be marked **Evidence complete** in green when the relevant record supports it; “Test families’ interpretation…” can be marked **Evidence missing** in red when the evidence has not been obtained. Neither cue itself changes the Meaning’s eligibility band.

**THEN** Daniel selects **Continue clarification** and enters the established clarification journey. The Board does not accept a drag gesture, does not treat the Clarification column as a status lane, and does not claim that a completed-looking card makes the Meaning plan-eligible or effect-eligible without a new Profile 11 derivation.

## UC-04 — Explore a raw input and surface supported downstream suggestions

**Actor:** Priya, operations analyst.  
**Precondition:** An email arrives titled “Harbour alert wording concerns.” It has been captured as an Input, and the case contains interview-derived Orientation points plus some established meanings and clarification evidence.

Priya selects **Explore** on the email Input card.

**THEN** the Board produces an active inspection projection with the email as the selected origin. It highlights likely Orientation hits and shows related accepted Meaning cards. It may also show visibly differentiated machine-proposed meaning suggestions, each with source/evidence provenance and `Consider`/`Decline` actions.

**THEN** established related Meaning cards retain their derived display: green only for `effect-eligible`, amber for `plan-eligible`, red for `explorable`, and neutral where calculation is unavailable. The raw email itself remains neutral because receiving an event does not establish a meaning.

**THEN** if the inspection finds a relevant Input, an accepted Meaning, and sufficient clarification evidence to support a downstream carry, it renders a **Suggested — contingent** Stewardship proposal. The proposal states its dependency, such as “Only after effect-eligible meaning and authority review.” Its presence is not authorization to act.

## UC-05 — Consider or decline a machine-proposed meaning without masquerade

**Actor:** Daniel, terminology steward.  
**Precondition:** Daniel’s active exploration shows a dashed card labeled **Suggested — unaccepted**: “Candidate: protective action as locally specified response.”

Daniel reads the proposal’s evidence/referent links and selects **Consider**.

**THEN** the Board routes Daniel into the existing governed Meaning/Clarification flow. A decision surface identifies the proposal as machine-proposed, displays the evidence that led to it, and allows the appropriate authorized outcome. The Board does not convert the proposal to an accepted Meaning on selection alone.

**THEN** only after the governing collection/decision action records an authorized candidate or acceptance can a later Board projection display an accepted Meaning card. Its eligibility is still derived afresh; acceptance alone does not produce green.

Alternatively, Daniel selects **Decline**.

**THEN** the Board acknowledges the proposal for this exploration and removes it from the active suggestion set, subject to the existing retention/review policy. It does not delete or reclassify any accepted Meaning and does not conceal the proposal’s provenance from authorized inspection.

## UC-06 — First-run Board invites the first interview

**Actor:** Amina, a newly authorized steward.  
**Precondition:** Amina has opened a new case. No Orientation points, accepted Meanings, Clarification records, or Stewardship carries exist. There may be no Inputs.

Amina opens the Board.

**THEN** all five columns remain visible in the fixed order: Inputs, Orientation, Meaning, Clarification, Stewardship. The Orientation column contains an EmptyState with the copy: **“No orientation points yet. Begin a personal interview to make the current semantic situation intelligible.”** It offers **Begin personal interview**.

**THEN** Meaning, Clarification, and Stewardship display neutral explanatory EmptyStates rather than fake zero-state tasks. The Board does not pre-populate suggested meanings, does not show any green/red band treatment, and does not invite Amina to manufacture a meaning without orientation.

**THEN** selecting **Begin personal interview** routes Amina to existing Journey A. She may return to the Board after an accountable orientation point has been collected.

## UC-07 — An explorable Meaning cannot presently be clarified

**Actor:** Daniel, terminology steward.  
**Precondition:** The Meaning “Protective action may mean staying or leaving” derives only as `explorable`. Its Eligibility Explanation shows failures for agreement and binding. The available evidence cannot responsibly resolve those criteria at present.

Daniel selects **Inspect eligibility** and then **Enter productive-refusal wall**.

**THEN** the Evidence Panel lists the criterion identifiers and their pass/fail values with IRI references. The Board visibly labels the Meaning **Explorable** in red, which means it may be examined but is not adequate for accountable planning or effect. It does not call the meaning “rejected,” “bad,” or “a red status.”

**THEN** the page routes Daniel to the existing Journey D productive-refusal treatment with the selected meaning, eligibility explanation, and evidence context in scope. The refusal notice explains that accountable planning/effect cannot be claimed now and names the next legitimate response, if any.

**THEN** no user action can drag the card into Clarification, Planning, or Stewardship to bypass the failed criteria. No derived band is persisted; an attempt to persist one remains refused as `MEANING_BAND_FORBIDDEN`.

## UC-08 — A disputed Meaning remains visible and accountable

**Actor:** Leila, review authority.  
**Precondition:** Two accountable parties dispute whether “evacuate” should be understood as immediate departure in the current context. The dispute is part of the Profile 11 source dimensions and prevents the required agreement from being satisfied.

Leila opens the relevant Meaning from a Board exploration.

**THEN** the Board uses its existing Evidence Panel to display the dispute material and its effect on the Eligibility Explanation. The Board renders the currently derived band—red/Explorable or amber/Plan-eligible as warranted—rather than an invented generic “conflicted” status.

**THEN** Leila may inspect the two positions and navigate to the existing Journey D productive-refusal wall. The refusal treatment does not erase the Meaning, hide the dissent, or compress the dispute into an unexplained red card.

**THEN** if later governed work resolves the dispute, the Board receives a new request-time derivation. It may display a different band, but it does not retain a prior color or a manual “resolved” board status.

## UC-09 — A proposed stewardship action is refused

**Actor:** Noor, stewardship lead.  
**Precondition:** An active exploration contains an effect-eligible Meaning and a proposed stewardship carry, “Draft bilingual alert guidance.” The relevant authority refuses the action because the required authority sign-off has not been granted.

Noor selects **Enter stewardship flow** and receives the refusal outcome from the governing process.

**THEN** the Board renders a `RefusalNotice` within the Stewardship column that states the refused carry, authority/scope, reason, and the available accountable response. Example: **“Refusal: Do not issue unverified action language.”** The item remains inspectable; the Board does not silently remove it or represent refusal as completion.

**THEN** Noor can select **Inspect refusal** or continue through the existing Journey D productive-refusal treatment. The underlying Meaning may remain green/Effect-eligible as a Meaning; that band does not override a distinct stewardship authorization refusal.

**THEN** the Board does not display a “Done” lane and does not create an actionable effect merely because the input, meaning, and clarification context are all present.

## UC-10 — A user expects drag-to-status but is offered an honest alternative

**Actor:** Evan, an experienced project manager new to the Workbench.  
**Precondition:** Evan sees the five-column visual arrangement and assumes it behaves like a conventional Kanban board.

Evan attempts to drag an Explorable Meaning card toward the Clarification or Stewardship column.

**THEN** the page does not expose draggable handles or drop targets. Its persistent Context Banner states: **“Eligibility is derived at request time — board position does not change it.”** If the host surface detects the attempted gesture, the existing disclosure/refusal pattern reiterates: **“Eligibility is derived from evidence and criteria; board position cannot change it.”**

**THEN** Evan is offered `Inspect eligibility` and `Continue clarification`. The former reveals the Profile 11 explanation; the latter routes to the relevant existing journey. Evan can see why the card is red/Explorable and what accountable work may be appropriate, but he cannot turn it green through board interaction.

---

## Scenario coverage matrix

| Operator requirement | Covered by |
| --- | --- |
| Click `+` on Orientation header, then add an orientation point | UC-01 |
| Explore Orientation, then related Meaning + suggested Meaning highlights | UC-02 |
| Green/red meaning treatment | UC-02, UC-04, UC-07 |
| Explore Meaning, then clarification likely-hit highlights and green/red clarification evidence | UC-03 |
| Explore raw Input, then Orientation/Meaning suggestions, and conditional Stewardship proposal | UC-04 |
| Suggestions differ and can be accepted/rejected | UC-05 |
| Empty / first-run state and first interview invitation | UC-06 |
| Term cannot be clarified | UC-07 |
| Disputed meaning | UC-08 |
| Stewardship action refused | UC-09 |
| Kanban expectation without dishonest drag behavior | UC-10 |

---

## References

These scenarios are grounded solely in the operator specification supplied with this request. No external factual sources are used.
