# StewardshipTranslation Workbench — Board Page Use Cases

**Status:** Design scenarios only. They describe intended, governed behavior for
the Board page and reuse the existing journeys rather than specifying
implementation.

**Revision:** rewritten against the operator's stated interaction model for
**Explore**. The previous list (UC-01…UC-10) was written before Explore had a
stated meaning, and several of its scenarios described the *surface* rather than
the *model*. The reconciliation table below says what happened to each.

## The interaction model these scenarios encode

> **Explore** means: set up the board to focus on THIS thing.
>
> - If it is an **Input**, the input is mapped against existing **References**.
>   Matches are found and/or suggestions are made.
> - If a **Reference** is clicked, all matching **Inputs** are shown.
> - The **References map Input to Meaning**.
> - **Meanings have clarifications.**
> - Fully mapped Inputs and fully mapped Meanings map to existing and/or new
>   **Stewardship** cards.
> - **Buttons other than `Explore` open a modal with an AI-generated,
>   context-based response.**
>
> **A Reference is "what meaning am I making about this input".**
>
> **As the Meaning column populates with clarified meanings, the flow to
> Stewardship becomes automated.**

Six consequences drive the revision:

1. **Explore is one verb whose meaning depends on direction.** It is not
   "inspect this card"; it re-roots the entire board on the selected thing.
   From an Input it looks *forward* (which References match, what is suggested);
   from a Reference it looks *backward* (which Inputs land on it).
2. **A Reference is an interpretive ACT, not an edge.** "What meaning am I
   making about this input" is a claim somebody makes and is answerable for. It
   happens to connect an Input to a Meaning, but its substance is the
   interpretation, not the connection. This is why a Reference has an author and
   grounds, why it can be wrong in a way a lookup cannot, and why the machine may
   only ever *propose* one.
3. **Mapping has a completeness state.** "Fully mapped" is a real condition for
   both Inputs and Meanings, and it is the gate to Stewardship.
4. **The board gets more automatic as it learns.** Early on, every Reference is
   authored by hand. As the Meaning column fills with *clarified* meanings, an
   arriving Input increasingly matches interpretations already made and
   clarified, and the path Input → Reference → Meaning → Stewardship needs less
   human routing. The corpus of clarified meanings *is* the automation.
5. **Automation moves the ROUTING, never the AUTHORITY.** "Automated" here means
   the board stops asking a person to find the mapping. It does not mean a carry
   is authorized without the governing test, and it does not mean a band is
   asserted without derivation. See UC-17 and OQ-5.
6. **Every non-Explore button shares one shape**: open a modal, show an
   AI-generated response grounded in the current context. They are not ten
   bespoke destinations.

## Reading these scenarios

Each scenario is anchored in explicit **THEN** clauses. "Highlight" means a
request-time inspection projection: an outlined or otherwise emphasized existing
card grounded by referent/evidence links. It does not mean a stored relation,
status, or workflow movement. Band labels are likewise derived/request-time
display values, not editable card states.

| Term | Intended interpretation |
| --- | --- |
| **Input** | Something that arrived — an email, a report, an interview note. Receiving it establishes nothing. |
| **Reference** | **"What meaning am I making about this input."** An interpretive act by an accountable author, which connects an Input to a Meaning. Its substance is the interpretation; the connection is a consequence. It has an author and grounds, and it can be *wrong* — which a lookup cannot be. |
| **Clarified meaning** | A Meaning whose clarifications are satisfied. The stock of these is what makes later mapping automatic. |
| **Automated flow** | Routing done without asking a person to find the mapping. Never authorization without the governing test. |
| **Accepted meaning** | A meaning already present in the governed record. Its Profile 11 band may be derived for the current request. |
| **Suggested** | A machine-proposed, unaccepted candidate — visually and semantically distinct, with no band claim. |
| **Fully mapped (Input)** | Every element the Input asserts is carried by at least one Reference to an accepted Meaning, with no unresolved residue. |
| **Fully mapped (Meaning)** | Every clarification the Meaning depends on is satisfied by evidence, so nothing outstanding blocks a carry. |
| **Eligibility Explanation** | The Profile 11 request-time projection: criteria, pass/fail values, IRI references. |
| **Response modal** | The shared surface behind every non-Explore button: an AI-generated, context-grounded response. Advisory. Never a determination. |
| **Productive-refusal wall** | The existing Journey D treatment for a condition that cannot responsibly be carried forward. |

## Reconciliation with the previous list

| Previous | Disposition | Why |
| --- | --- | --- |
| UC-01 Add an orientation point | **Revised → UC-01** | The column is now Reference. Adding a reference point asserts a *mapping*, not an interview note. See OQ-1: the column's stored `purpose` still describes interview context and now contradicts the column. |
| UC-02 Explore an Orientation card → meanings | **Revised → UC-03** | The model says clicking a Reference shows all matching **Inputs** (backward), not meanings (forward). The old scenario had the direction wrong. |
| UC-03 Explore a Meaning → clarifications | **Kept → UC-04** | Matches "Meanings have clarifications" directly. Modal wording updated. |
| UC-04 Explore a raw input | **Revised → UC-02** | Promoted to the primary Explore case and rewritten as forward mapping to References, with matches *and* suggestions. |
| UC-05 Consider / Decline a suggestion | **Revised → UC-06** | These are now response modals, not bespoke routes. |
| UC-06 First-run Board | **Revised → UC-12** | Column renamed; empty-state copy must describe mapping, not interviewing. |
| UC-07 Explorable Meaning cannot be clarified | **Kept → UC-09** | Still correct. `Inspect eligibility` and `Enter productive-refusal wall` reframed as modals. |
| UC-08 Disputed Meaning | **Kept → UC-10** | Unchanged in substance. |
| UC-09 Stewardship action refused | **Revised → UC-08** | Reaching Stewardship now requires *fully mapped*; the refusal scenario sits after that gate. |
| UC-10 Drag-to-status expectation | **Kept → UC-13** | Still the honest-affordance scenario. |
| — | **New: UC-05** | Partial vs. fully mapped — the condition the old list had no notion of. |
| — | **New: UC-07** | Reaching Stewardship: existing vs. new card. |
| — | **New: UC-11** | The response modal's shared shape and its limits. |
| — | **New: UC-14** | Explore finds nothing — neither match nor suggestion. |
| — | **New: UC-15** | Leaving an exploration / the unrooted board. |
| — | **New: UC-16** | The modal cannot answer, or must refuse. |
| — | **New: UC-17** | The automation gradient — the flow to Stewardship becomes automated as clarified meanings accumulate. |
| — | **New: UC-18** | Automation proposes a wrong interpretation, and what stops it closing a mapping. |

---

## UC-01 — Make a Reference: what meaning am I making about this input

**Actor:** Maya, community liaison.
**Precondition:** The Board holds an Input, "Email — Harbour alert wording
concerns." Maya has read it and formed a view about what it means here.

Maya selects **Add reference point** in the Reference column header.

**THEN** the Board routes Maya to the existing governed collection surface with
the Input and case scope in context. The question it asks her is the one the
column exists for: *what meaning are you making about this input?* She answers
with an interpretation and the grounds for it, and names the Meaning it lands on
— existing, or one she is proposing.

**THEN** the Reference is recorded as an **authored act**: it carries her
identity, her grounds, and the time she made it. A Reference is not an anonymous
edge. It is answerable, which is what allows a later reader to disagree with it
specifically rather than with the board in general.

**THEN** making a Reference creates no band, no clarification and no stewardship
carry. It records that someone accountable read this Input and made this meaning
of it. Whether that meaning is adequate for planning or effect is derived
separately and later.

**THEN** a Reference may later be judged wrong. The Board keeps it visible and
attributed rather than deleting it, because an interpretation that was acted on
and later withdrawn is part of the account of what happened.

## UC-02 — Explore an Input: forward to References

**Actor:** Priya, operations analyst.
**Precondition:** The Input "Email — Harbour alert wording concerns" is on the
Board. The case holds accepted Meanings and existing References.

Priya selects **Explore** on the Input card.

**THEN** the Board re-roots on that Input. The Input card carries the *Selected
— active exploration* badge. The Reference column shows every existing Reference
whose mapping matches this Input, and the Meaning column shows the Meanings
those References carry it to.

**THEN** where no existing Reference matches, the Board may render **Suggested —
unaccepted** Reference candidates, each with the provenance that produced it.
A suggestion is visually and semantically distinct from an asserted Reference
and makes no claim that the mapping holds.

**THEN** matched Meanings retain their derived display — the band is re-derived
for this request and is not inherited from the exploration. The Input itself
stays neutral: receiving an email establishes no meaning.

**THEN** the exploration is projection only. No Reference is created, no mapping
is recorded, and leaving the exploration leaves the record untouched.

## UC-03 — Explore a Reference: backward to Inputs

**Actor:** Daniel, terminology steward.
**Precondition:** A Reference carries "wording implies immediate departure" to
the Meaning "evacuate." Daniel wants to know what else lands there.

Daniel selects **Explore** on the Reference card.

**THEN** the Board re-roots on the Reference and shows **all matching Inputs** —
every Input this Reference carries — in the Inputs column. This is the backward
view and it is the point of exploring a Reference: a mapping is only as good as
the body of Inputs it actually covers.

**THEN** the Meaning the Reference carries to is shown with its derived band.
The Reference itself carries no band: a mapping is not eligible or ineligible,
it either holds or does not.

**THEN** an Input that this Reference *nearly* matches may appear as a suggested
extension of the mapping, distinctly labeled. Extending a Reference to cover a
new Input is a governed assertion, not a side effect of looking.

## UC-04 — Explore a Meaning: its clarifications

**Actor:** Daniel, terminology steward.
**Precondition:** The accepted Meaning "Protective action may mean staying or
leaving" derives as `explorable`; agreement and binding are unmet.

Daniel selects **Explore** on the Meaning card.

**THEN** the Board re-roots on the Meaning and renders its Clarifications —
the work the Meaning depends on — in the Clarification column, alongside the
References that carry Inputs to it.

**THEN** each Clarification exposes its own evidence condition, labeled
separately from the Meaning's band: *Evidence complete* or *Evidence missing*,
each carrying a shape glyph so the state is readable without colour. Neither cue
changes the Meaning's band.

**THEN** the Board does not treat the Clarification column as a status lane and
does not claim that a complete-looking clarification makes the Meaning
plan-eligible or effect-eligible without a fresh Profile 11 derivation.

## UC-05 — Partial mapping is visible as partial

**Actor:** Priya, operations analyst.
**Precondition:** An Input asserts three distinct concerns. Two are carried by
existing References to accepted Meanings. The third is carried by nothing.

Priya explores the Input.

**THEN** the Board shows the Input as **partially mapped** and names the
residue — the element no Reference carries. Partial is a first-class display
state, not the absence of a "complete" badge, because an unmapped residue is
exactly the thing a steward must not overlook.

**THEN** the same treatment applies to a Meaning: a Meaning with an outstanding
clarification shows as partially mapped, and the outstanding clarification is
named.

**THEN** partial mapping is **derived per request**, like a band. It is not
stored, not editable, and not advanced by any board gesture. Adding a Reference
or satisfying a clarification is what moves it, through the governed flow.

**THEN** the Stewardship column offers no carry for a partially mapped Input or
Meaning. It states what remains, rather than presenting an action that would be
refused downstream.

## UC-06 — Consider or decline a suggestion without masquerade

**Actor:** Daniel, terminology steward.
**Precondition:** An exploration shows a suggested Reference: *"Candidate:
protective action as locally specified response."*

Daniel selects **Consider**.

**THEN** a response modal opens (see UC-11) showing the evidence that produced
the suggestion, the mapping it proposes, and what accepting it would and would
not establish. The modal is advisory. Reading it accepts nothing.

**THEN** acting on the suggestion routes Daniel into the existing governed
Meaning/Reference flow, which identifies the candidate as machine-proposed. The
Board does not convert a suggestion into an asserted Reference on selection
alone, and an accepted Reference still yields no band by itself.

Alternatively Daniel selects **Decline**.

**THEN** the Board drops the suggestion from the active exploration under the
existing retention policy. It deletes no accepted Meaning, reclassifies nothing,
and conceals the suggestion's provenance from no authorized inspection.

## UC-07 — A fully mapped Input reaches Stewardship

**Actor:** Noor, stewardship lead.
**Precondition:** An Input is fully mapped: every element it asserts is carried
by a Reference to an accepted Meaning, with no residue.

Noor explores the Input.

**THEN** the Stewardship column offers the carries this mapping reaches — both
**existing** Stewardship cards the mapping lands on, and **new** carries it would
create. The two are visibly distinguished: joining an existing carry and opening
a new one are different acts with different consequences.

**THEN** a fully mapped Meaning reaches Stewardship the same way, by the same
test. The two routes may land on the same Stewardship card; the Board shows that
they have converged rather than silently duplicating it.

**THEN** "fully mapped" is a *precondition* for a carry being offered, never an
authorization to make one. The carry still passes through the governing
authority flow, and may be refused there (UC-08).

## UC-08 — A stewardship carry is refused

**Actor:** Noor, stewardship lead.
**Precondition:** A fully mapped Meaning offers the carry "Draft bilingual alert
guidance." The governing authority refuses: sign-off has not been granted.

Noor proceeds and receives the refusal.

**THEN** the Board renders a `RefusalNotice` inline in the Stewardship column,
naming the refused carry, the authority and scope, the reason, and the available
accountable response. It sits in the journey, not in an error channel beside it.

**THEN** the underlying Meaning may remain effect-eligible. A Meaning's band and
a stewardship authorization are different determinations, and neither overrides
the other.

**THEN** the Board shows no "Done" lane and creates no effect merely because
Input, Reference, Meaning and Clarification are all present. Full mapping earns
the offer, not the outcome.

## UC-09 — An explorable Meaning cannot presently be clarified

**Actor:** Daniel, terminology steward.
**Precondition:** A Meaning derives only as `explorable`; its Eligibility
Explanation shows agreement and binding failing, and available evidence cannot
responsibly resolve them now.

Daniel selects **Inspect eligibility**, then **Enter productive-refusal wall**.

**THEN** the response modal lists criterion identifiers with pass/fail values and
IRI references. The Meaning is labeled *Explorable* — it may be examined but is
not adequate for accountable planning or effect. It is not "rejected," "bad," or
"a red status."

**THEN** the Board routes to the existing Journey D treatment with the meaning,
explanation and evidence in scope. The refusal names why accountable planning
cannot be claimed now, and the next legitimate response if there is one.

**THEN** no gesture moves the card into Clarification or Stewardship to bypass
the failed criteria. No derived band is persisted; an attempt is refused as
`MEANING_BAND_FORBIDDEN`.

## UC-10 — A disputed Meaning stays visible and accountable

**Actor:** Leila, review authority.
**Precondition:** Two accountable parties dispute whether "evacuate" means
immediate departure here. The dispute is a Profile 11 source dimension and
prevents agreement being satisfied.

Leila opens the Meaning from an exploration.

**THEN** the Evidence Panel shows the dispute material and its effect on the
Eligibility Explanation. The Board renders the currently derived band rather
than inventing a generic "conflicted" status.

**THEN** Leila may inspect both positions and enter the productive-refusal wall.
The treatment does not erase the Meaning, hide the dissent, or compress the
dispute into an unexplained card.

**THEN** if later governed work resolves the dispute, a new derivation may show
a different band. No prior colour and no manual "resolved" status is retained.

## UC-11 — Every non-Explore button opens the same kind of surface

**Actor:** any authorized user.
**Precondition:** An exploration is active. The visible controls include
`Inspect eligibility`, `Continue clarification`, `Enter productive-refusal wall`,
`Consider`, `Decline` and `View evidence`.

The user selects any of them.

**THEN** a **response modal** opens containing an AI-generated response grounded
in the current context: the rooted thing, its mapping state, the evidence in
scope, and the specific question the button asks. The shape is the same for every
such button; only the question differs.

**THEN** the modal is **advisory and clearly marked as generated**. It is not a
Profile 11 derivation, not an authority decision, and not a governed record. It
sits beside the Eligibility Explanation — which *is* a derivation — and the two
are never presented as the same kind of thing.

**THEN** the modal creates nothing. Any governed act it discusses is reached by
leaving the modal and entering the existing journey, where the authority test is
applied. Closing the modal leaves the record untouched.

**THEN** the modal cites what it drew on. A response that cannot show its
grounds is a response a steward cannot weigh.

## UC-12 — First-run Board invites the first mapping

**Actor:** Amina, newly authorized steward.
**Precondition:** A new case. No References, Meanings, Clarifications or carries.
There may be no Inputs.

Amina opens the Board.

**THEN** all five columns remain visible in fixed order: Inputs, Reference,
Meaning, Clarification, Stewardship. Each shows a neutral explanatory EmptyState
rather than a fabricated zero-state task.

**THEN** the Board does not pre-populate suggested Meanings, shows no band
treatment, and does not invite Amina to manufacture a Meaning with nothing to
map from.

**THEN** with Inputs present but no References, the Reference column invites the
first mapping and explains what a Reference is: the thing that carries an Input
to a Meaning. With no Inputs either, it says so plainly instead of offering a
mapping with nothing to map.

## UC-13 — A user expects drag-to-status and is offered an honest alternative

**Actor:** Evan, an experienced project manager new to the Workbench.
**Precondition:** Evan sees five columns and assumes conventional Kanban.

Evan attempts to drag a card toward Clarification or Stewardship.

**THEN** the page exposes no drag handles and no drop targets. The Context
Banner states: **"Eligibility is derived at request time — board position does
not change it."**

**THEN** Evan is offered `Inspect eligibility` and `Continue clarification`. He
can see why a card is Explorable and what accountable work may follow, but he
cannot change it by moving it.

**THEN** the same holds for mapping completeness: dragging a partially mapped
Input into Stewardship does nothing. Mapping is earned by References and
evidence, not by position.

## UC-14 — Explore finds neither match nor suggestion

**Actor:** Priya, operations analyst.
**Precondition:** A newly arrived Input bears on nothing the case has seen.

Priya explores it.

**THEN** the Board says so directly: no Reference matches, and no suggestion
reached the threshold to propose. It does not present an empty Reference column
as though the exploration had not run.

**THEN** the Board distinguishes *no match found* from *matching unavailable*.
The first is a finding about the case; the second is a failure of the machinery,
and a steward must not read one as the other.

**THEN** the offered next step is to assert a Reference by hand (UC-01), which
is the accountable response to an Input the case cannot yet place.

## UC-15 — Leaving an exploration

**Actor:** any authorized user.
**Precondition:** An exploration is rooted on some card.

The user clears the exploration, or explores something else.

**THEN** the Board returns to its unrooted projection: all five columns, no
selection badge, no highlight, nothing emphasized. The unrooted board is a real
state, not the residue of the last exploration.

**THEN** nothing about the record changed. Highlights, matches, suggestions and
mapping states were all request-time projection, and none of them survive the
exploration that produced them.

**THEN** exploring a second thing replaces the first rooting rather than
accumulating. There is one rooted thing at a time, which is what makes "focus on
THIS thing" mean anything.

## UC-16 — The generated response is inadequate, unavailable, or must refuse

**Actor:** Daniel, terminology steward.
**Precondition:** Daniel opens a response modal on a Meaning whose evidence is
thin, contested, or absent.

**THEN** where the generator has too little to work with, the modal says so and
names what is missing. It does not produce a fluent answer that reads as
authoritative and is grounded in nothing — which is the specific failure mode
that would do the most damage on this surface.

**THEN** where the generator is unavailable, the modal reports unavailability.
The Board does not silently fall back to a stale or generic response, and the
absence of a response is never rendered as a determination.

**THEN** where the question asked would require asserting something the record
does not support — that a Meaning is eligible, that a mapping holds, that a
carry is authorized — the modal refuses and names the governed path that could
establish it. A generated response may never stand in for a Profile 11
derivation or an authority decision.

## UC-17 — The flow to Stewardship automates as clarified meanings accumulate

**Actor:** Priya, operations analyst, months into a mature case.
**Precondition:** The Meaning column now holds a substantial stock of
**clarified** meanings — meanings whose clarifications are satisfied. Many
References have been authored against them over time. A new Input arrives that
resembles ones seen before.

Priya explores the new Input.

**THEN** the Board matches it against the meanings already made and clarified.
Where the match is strong, it presents the interpretation as already available
rather than asking Priya to author it from nothing. The work she does is
**confirming or rejecting an interpretation**, not constructing one.

**THEN** where the Input is fully mapped by that matching and the Meanings it
reaches are clarified, the Board carries the routing all the way to Stewardship
and shows the reachable carries directly — existing and new, distinguished as in
UC-07. The path Input → Reference → Meaning → Stewardship required no human
routing.

**THEN** **automation moved the routing, not the authority.** The carry is
offered, not authorized. The governing authority test still applies and may
refuse (UC-08). No band was asserted without derivation; eligibility is still
computed for this request.

**THEN** the Board makes the automated step **visible and attributable**. An
automatically matched Reference is labeled as machine-matched against a named
prior interpretation, with its author and grounds reachable. It is never
presented as though Priya made it. A steward must always be able to see which
interpretations in front of her were made by a person and which were inferred.

**THEN** Priya can reject the automated interpretation. Rejecting it returns her
to UC-01 — authoring the meaning she is actually making — and the rejection is
itself recorded, because a matching rule that keeps being rejected is a fact
about the corpus.

**THEN** an early-stage case behaves differently from a mature one, and the
Board does not pretend otherwise. With few clarified meanings the same Input
yields little or nothing automatic (UC-14), and the honest display is that the
case has not yet learned enough to place it.

## UC-18 — Automation proposes an interpretation that is wrong

**Actor:** Daniel, terminology steward.
**Precondition:** A mature case. An arriving Input superficially resembles a
clarified meaning but is materially different — same wording, different referent.

The Board matches it automatically and offers the carry.

**THEN** the automated Reference is distinguishable at a glance from an authored
one, so Daniel can tell that no person has yet made this meaning of this Input.
The distinction is not a footnote in a modal; it is on the card.

**THEN** Daniel rejects it and authors the correct interpretation. The Board does
not silently substitute his Reference for the machine's: the rejected match stays
attributable, because the fact that the system proposed this reading is part of
the account.

**THEN** the Board never lets automated matching *close* a mapping without a
person having at some point made that meaning. Fully-mapped-by-inference and
fully-mapped-by-authorship are different states, and only the latter may reach a
carry without confirmation. Automation removes the labour of finding the mapping;
it does not remove the requirement that somebody made it.

---

## Open questions the model raises

These are unresolved. Each affects scenarios above and is worth settling before
implementation.

**OQ-1 — CLOSED.** `brd-col-orientation` carried
`purpose: "Interview points that make the situation intelligible."`, which
described orientation context rather than meaning-making. It now reads
**"What meaning am I making about this input?"** — the operator's own phrasing.
Board digest moved `642fbc2d882cd` → `734cca5d1d1fb`. Note that `purpose` is
carried in the ACIA document but is **not currently rendered**, so the page is
visually unchanged; the fix corrects what the document says about itself.

**OQ-10 — Reference and Meaning now ask nearly the same question.** Fixing OQ-1
surfaced a collision. The five columns state their purposes as:

| Column | purpose |
| --- | --- |
| Inputs | *Stuff that happens.* |
| Reference | *What meaning am I making about this input?* |
| Meaning | *What am I making of this?* |
| Clarification | *What clarification do I need?* |
| Stewardship | *What is required to carry the meaning forward into action?* |

Reference and Meaning are now almost the same sentence. That is a real ambiguity,
not a wording nit: if a reader cannot tell the two questions apart, the
distinction the model rests on — an authored interpretation *about one input*
versus the settled meaning it lands on, shared across inputs — is invisible on
the board itself.

The distinction to encode is per-input-and-authored versus settled-and-shared.
One candidate: leave Reference as the operator stated it and move Meaning toward
something like *"What have we settled this means?"*. **Not changed here** —
Meaning's purpose was not in scope, and picking its wording is a decision about
the product's vocabulary rather than a defect to repair.

**OQ-2 — What exactly makes an Input fully mapped?** UC-05 and UC-07 assume an
Input decomposes into elements, each of which is or is not carried. If an Input
is atomic, "fully mapped" collapses to "has at least one Reference" and the
partial state largely disappears.

**OQ-3 — Can one Reference carry an Input to more than one Meaning?** Now
probably NO. If a Reference is *the* meaning someone is making about an input,
it is one interpretation, so an Input carrying several readings needs several
References — which is right, since each is separately authored and separately
rejectable. Worth confirming, because it makes UC-03's backward view denser.

**OQ-4 — Is a Reference directional?** Now clearer: as an ACT it is directional
— authored from an Input toward a Meaning — but it is *explorable* from either
end, which is what UC-02 and UC-03 do. One object, two views. What remains open
is whether a Reference authored about one Input can later be found to cover a
second Input without being re-authored (UC-03's suggested extension), or whether
that is always a new interpretive act.

**OQ-5 — Can the response modal propose a governed action?** UC-11 and UC-16
assume advisory-only. If a modal may propose an action a user can then take,
every generated response becomes a potential route into the governed flow and
needs its own authority treatment.

**OQ-6 — Does exploration have history?** UC-15 assumes one rooted thing at a
time with no accumulation. Following Input → Reference → Meaning → Clarification
is a natural path, and whether a user can walk back along it is unspecified.

**OQ-7 — What is the suggestion threshold, and who sets it?** UC-02 and UC-14
turn on whether a candidate "reached the threshold to propose." An unstated
threshold is a policy decision hidden in an implementation detail.


**OQ-8 — What is the automation threshold, and who owns it?** UC-17 turns on a
match being "strong" enough to present an interpretation as available. That
threshold decides how much interpretive work the system does on a steward's
behalf, which makes it a governance decision, not a tuning parameter. Related to
OQ-7 but sharper: OQ-7 asks when to *suggest*, OQ-8 asks when to stop asking.

**OQ-9 — Can a mapping be closed by inference alone?** UC-18 asserts not: some
person must at some point have made the meaning. If that is too strict for a
mature case, the alternative needs stating explicitly, because "nobody ever made
this interpretation but the system acted on it" is exactly the outcome the
product exists to prevent.

---

## Scenario coverage matrix

| Model element | Covered by |
| --- | --- |
| Explore an Input — forward to References, matches and suggestions | UC-02 |
| Explore a Reference — backward to all matching Inputs | UC-03 |
| Explore a Meaning — its clarifications | UC-04 |
| References map Input to Meaning | UC-01, UC-02, UC-03 |
| Meanings have clarifications | UC-04, UC-09 |
| Partial vs. fully mapped | UC-05 |
| Fully mapped reaches Stewardship, existing and new | UC-07 |
| Non-Explore buttons open a generated response modal | UC-06, UC-09, UC-11 |
| The modal's limits — inadequate, unavailable, must refuse | UC-16 |
| Suggestions are distinct and can be considered or declined | UC-06 |
| Refusal as inline journey content | UC-08, UC-09, UC-10 |
| Derived bands never stored or set by gesture | UC-04, UC-05, UC-09, UC-13 |
| Empty / first-run state | UC-12 |
| Explore finds nothing | UC-14 |
| Leaving an exploration / the unrooted board | UC-15 |
| Kanban expectation without dishonest drag behavior | UC-13 |
| A Reference is an authored interpretation, not an edge | UC-01, UC-18 |
| Flow to Stewardship automates as clarified meanings accumulate | UC-17 |
| Automation moves routing, never authority | UC-17, UC-18 |
| Automated interpretation is visibly distinct from an authored one | UC-17, UC-18 |
| An early-stage case behaves differently from a mature one | UC-14, UC-17 |

---

## Provenance

Revised from the operator's stated interaction model. The previous list was
authored by Manus; this revision was written in-session while Manus was
unavailable, against the same constraints: actability derived and never stored,
highlighting and eligibility as request-time projection, refusals inline in the
journey, suggestions distinct from acceptances, and colour never carrying
meaning alone.
