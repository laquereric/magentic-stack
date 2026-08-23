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
> **A Reference is "what have we settled this part of the input means".**
>
> **As the Meaning column populates with clarified meanings, the flow to
> Stewardship becomes automated.**

Six consequences drive the revision:

1. **Explore is one verb whose meaning depends on direction.** It is not
   "inspect this card"; it re-roots the entire board on the selected thing.
   From an Input it looks *forward* (which References match, what is suggested);
   from a Reference it looks *backward* (which Inputs land on it).
2. **A Reference is a CONSEQUENTIAL MAPPING of a Span to a Meaning.** "What have
   we settled this part of the input means" carries three things at once.
   *Settled* — a resolved position, not a hunch in flight. *We* — collective and
   attributable, not one reader's private note. *This part of the input* — a
   **Span**, because an Input is never interpreted whole.

   **The mapping is consequential because it affects Stewardship.** That is not
   a remark about importance; it is the mechanism. Span → Reference → Meaning →
   Stewardship is a chain, and a Reference is the link that makes the rest of it
   reachable. Settle a Span onto a Meaning and you have changed what carries may
   be offered; settle it onto a different Meaning and different carries follow.
   This is why a Reference can be *wrong* in a way a lookup cannot be, why it
   must be attributable, and why the machine may only ever propose one.
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

## The layer this is, and the layer it is not

**This is a Human Orientation layer, provided through human↔human orientation.
Nowhere in it does factual truth enter.**

That is not a caveat at the end of the document. It governs everything above and
below it, and most of the ways this product could go wrong are ways of
forgetting it.

A Meaning is not true. It is **settled between people**. A Reference does not
record a fact about an Input; it records what a group has agreed a span of that
Input means. "Clarified" does not mean verified against the world — it means the
clarifications a group asked for have been met. Eligibility is not a claim about
correctness; it is a claim about whether enough has been settled, by enough of
the right people, to act accountably.

So the Board must never present a settlement as a finding. Concretely:

- No scenario in this document may be read as the system determining what an
  Input *really* says. It shows what has been settled and by whom.
- "Wrong", where it appears (UC-18), means **out of step with what was settled**
  or a settlement that does not hold for these people — never factually false.
- The generated response modal (UC-11, UC-16) is furthest from truth-bearing of
  anything here, and its refusals matter most for exactly that reason.
- Two groups may settle the same Input differently and both be legitimate. The
  Board's job is to make each settlement attributable, not to adjudicate them.

The orientation is between humans. The machine's whole role is to carry what
people have settled to the next person who needs it, with its provenance intact.

## Frame is the scope everything but Inputs sits inside

A **Frame** is a way of seeing. Everything interpretive happens *within* one.

```
  Inputs                Frame: Y1
  ┌──────┐   ┌────────────────────────────────────┐
  │ X1   │   │            Translation             │
  │ X2   │   │  ┌─────────┬─────────┬──────────┐ │
  │      │   │  │Reference│ Meaning │Clarificat│ │
  │      │   │  │ X1:Y1:R1│  Y1:M1 │ Y1:M1:C1 │ │
  └──────┘   │  └─────────┴─────────┴──────────┘ │
             └────────────────────────────────────┘
             Stewardship: X1:Y1:Z1
```

**Inputs sit OUTSIDE the Frame.** An Input arrived; that is a fact about the
world and is frame-independent. Everything after it — the spans it is divided
into, what they are settled to mean, what clarification is wanted, what carries
follow — exists only inside a Frame.

The identifiers say the scoping precisely:

| Thing | Identifier | Scoped by |
| --- | --- | --- |
| Input | `X1` | nothing — it is frame-independent |
| Reference | `X1:Y1:R1` | input **and** frame |
| Meaning | `Y1:M1` | **frame only** — a Meaning is not about one Input |
| Clarification | `Y1:M1:C1` | frame and meaning |
| Stewardship | `X1:Y1:Z1` | input **and** frame |

Read that carefully. A Meaning belongs to a Frame, not to an Input — which is
why many Inputs can land on one Meaning, and why the Meaning column is the
Frame's vocabulary rather than a per-Input scratchpad. A Reference is where an
Input meets a Frame. A Stewardship carry is likewise `X1:Y1:Z1`: **a carry is
always about some input, decided within some frame.** There is no frameless
carry.

### A different Frame produces a different everything

**Change the Frame and you change the spans, the References, and the Stewardship
decisions.** Not their labels — the things themselves. A Frame that does not
distinguish a concept will not span an Input where that distinction falls, so
the Reference cannot be made, so the Meaning is never reached, so the carry never
becomes available. The Frame decides what is *seeable*, and everything
downstream inherits that.

This is why the board shows one Frame at a time. Columns 2–5 are a Frame's view;
only column 1 is common ground.

### The machine is a Frame

**This is the crucial distinction.** When a machine proposes a span, a Reference
or a match, it is not an assistant being helpful or an oracle being right. **It
is another Frame speaking.** Its proposals are that Frame's way of seeing, with
that Frame's distinctions and blindnesses.

So "the machine may only ever propose" is not a safety rail bolted on out of
caution. It follows from what the machine is: a Frame cannot make a settlement
inside a Frame it is not. Its output is legitimate *as a proposal from
elsewhere*, and illegitimate as a settlement here.

And "wrong", where it appears in these scenarios, almost never means mistaken.
It means **framed differently** — which is exactly what the layer statement above
would lead you to expect, since there is no frame-independent truth against which
a Frame could be wrong.

### Authentic stewardship requires identifying with the Frame

**To make an authentic stewardship decision, a person must be deciding within a
Frame they identify with at the meaning level.**

Not a frame they have been assigned, are borrowing, or find convenient — one
whose Meanings they hold as their own. A carry decided inside a Frame the decider
does not identify with is inauthentic even when every step is procedurally
correct: the settlements it rests on are not theirs, so the accountability the
carry is supposed to carry has nowhere to land.

This is a demand on the Board. It must make the operative Frame unmistakable at
the moment of decision, and it must not let a person drift into carrying
something forward in a Frame they were merely looking at.

### Many Frames, including several held by one person

**Many Frames exist, and one person may hold several.** A steward may hold a
regulatory frame, a community frame and a clinical frame, and move between them
legitimately. That is not inconsistency — it is what having more than one way of
seeing means.

So the Board cannot treat frame as an attribute of a user. It is the scope a
person is *currently working within*, chosen deliberately and visible at all
times.

## Spans, and why marking one is a decision

A **Span** is a part of a document. Spans are the units that get settled, and
deciding where they fall is **span selection**.

> **Note on vocabulary:** "chunk" and "chunking" are **reserved for the RAG
> context** and are deliberately not used here. A RAG chunk is a retrieval unit
> chosen for embedding; a Span is a part of a document that a group settles the
> meaning of. Borrowing the word would suggest the two are the same operation,
> and they are not — one is an indexing convenience, the other is a decision
> with consequences for what may be done.

Span selection is **a decision, and it has consequences.**

It is not tokenisation and not a parsing detail. Where the span boundaries fall
determines what can be settled, what counts as settled, and therefore what an
Input can be found to mean. Two readers who span the same Input differently are
not disagreeing about the wording — they are disagreeing about what the units of
meaning are, which is an earlier and deeper disagreement than any Reference.

**Span selection is reflexive: the meanings already made affect the span selection.** A
reader who holds a settled meaning sees an Input in terms of it, and spans
accordingly. This is not a defect to correct. It is how orientation works, and
it is why the Meaning column growing changes not just what matches but *what
there is to match*.

### The two directions, and what each one does

The directionality of Explore is not merely a UI convenience. The two directions
are different epistemic acts with different failure modes:

| Direction | The move | What it finds | What it risks |
| --- | --- | --- | --- |
| **Meaning → Inputs** | You hold a Meaning and go looking for evidence | You will find it in the Inputs | You are looking for what you already believe. The span selection bends toward the meaning, and the evidence found confirms it. |
| **Inputs → Meanings** | You hold Inputs and a stock of clarified Meanings | You will find the Inputs match the Meanings | The match is against what has been settled, not against the world. An Input with nothing new to say to this group looks like a clean match. |

Both directions work. Neither yields truth. The first is confirmation-shaped by
construction and the second is closure-shaped by construction, and a steward is
entitled to know which one produced what is in front of them.

**Therefore the Board must show which direction produced a result.** A match
surfaced by searching from a Meaning and a match surfaced by settling an Input
are not the same claim, and displaying them identically would hide the one thing
a reader needs in order to discount them properly.

## Reading these scenarios

Each scenario is anchored in explicit **THEN** clauses. "Highlight" means a
request-time inspection projection: an outlined or otherwise emphasized existing
card grounded by referent/evidence links. It does not mean a stored relation,
status, or workflow movement. Band labels are likewise derived/request-time
display values, not editable card states.

| Term | Intended interpretation |
| --- | --- |
| **Input** | Something that arrived — an email, a report, an interview note. Receiving it establishes nothing. |
| **Frame** | A way of seeing. Everything interpretive is scoped to one. Many exist; one person may hold several. `Y1` |
| **Translation** | The work done inside a Frame: Reference, Meaning, Clarification. What the app is named for. |
| **Span** | A part of a document. The unit that gets settled; an Input is settled span by span, never whole. Where the spans fall is frame-dependent. |
| **Span selection** | Deciding where the span boundaries fall. A consequential decision, not preprocessing — and reflexive, since existing meanings shape it. |
| **Consequential mapping** | What a Reference *is*: it maps a Span to a Meaning, and that mapping has consequence — it is what reaches Stewardship. |
| **Settled between people** | The only sense in which anything here is established. Not verified, not true — agreed, by identifiable people, on recorded grounds. |
| **Reference** | **"What have we settled this part of the input means."** A settled, collective, attributable interpretation of ONE part of an Input, which lands it on a Meaning. Its substance is the interpretation; the connection is a consequence. It can be *wrong* — which a lookup cannot be. |
| **Clarified meaning** | A Meaning whose clarifications are satisfied. The stock of these is what makes later mapping automatic. |
| **Automated flow** | Routing done without asking a person to find the mapping. Never authorization without the governing test. |
| **Accepted meaning** | A meaning already present in the governed record. Its Profile 11 band may be derived for the current request. |
| **Suggested** | A machine-proposed, unaccepted candidate — visually and semantically distinct, with no band claim. |
| **Fully mapped (Input)** | Every *part* of the Input is carried by a Reference to a Meaning, with no part left unsettled. |
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
| — | **New: UC-19** | Span selection is shaped by the meanings already made, and is re-doable. |
| — | **New: UC-20** | Which direction produced a result — Meaning→Inputs or Inputs→Meanings. |

---

## UC-01 — Settle a Reference: what have we settled this part of the input means

**Actor:** Maya, community liaison.
**Precondition:** The Board holds an Input, "Email — Harbour alert wording
concerns." It contains several distinguishable concerns. One of them — the
phrase read as an instruction to leave immediately — has no Reference.

Maya selects **Add reference point** in the Reference column header.

**THEN** the Board routes Maya to the existing governed collection surface with
the Input and case scope in context. She **spans** — marks the unit she is
settling — and then answers the question the column exists for: *what have we
settled this span means?* She gives the interpretation and its grounds, and
names the Meaning it lands on: existing, or one she is proposing.

**THEN** the span selection is itself recorded as a decision, with its author. Where
Maya drew the boundary determines what can be settled about this Input at all,
so a later reader must be able to see that she drew it and disagree with the
boundary rather than only with the reading inside it.

**THEN** the Reference is scoped to **that span**, not to the Input as a whole.
The rest of the Input remains unsettled and visibly so. This is what makes
partial settlement (UC-05) a real state rather than a formality: an Input divided into four spans
with one Reference is one quarter settled, and the Board says which
quarter.

**THEN** the Reference is recorded as a **settlement**, not a note: it carries
who settled it, on what grounds, and when. "We settled" is collective and
attributable — a later reader can disagree with this specific settlement rather
than with the board in general, and can see who they are disagreeing with.

**THEN** settling a Reference creates no band, no clarification and no
stewardship carry. It records that this Span has been given a settled reading.
Whether the Meaning it lands on is adequate for planning or effect is derived
separately and later.

**THEN** the mapping is nonetheless **consequential**: which Meaning this Span
lands on determines which carries become reachable once the Input is fully
settled (UC-07). Maya is not filing a note — she is deciding, for this Span, what
the downstream stewardship options will be. The Board makes that consequence
visible at the moment of settling rather than letting it surface only later in
the Stewardship column.

**THEN** a Reference may later be judged wrong. The Board keeps it visible and
attributed rather than deleting it, because a settlement that was acted on and
later withdrawn is part of the account of what happened.

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
**Precondition:** An Input has three distinguishable parts. Two are settled by
existing References. The third is settled by nothing.

Priya explores the Input.

**THEN** the Board shows the Input as **partially settled** and names the
unsettled part specifically — not "incomplete", but *which* part has no agreed
reading. Partial is a first-class display state, not the absence of a "complete"
badge, because an unsettled part is exactly the thing a steward must not
overlook.

**THEN** because a Reference is scoped to a part, completeness is countable: the
Board can say two of three parts settled, and show the third. An Input-level
"mapped / not mapped" flag could not carry that, which is why the granularity is
load-bearing rather than cosmetic.

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

## UC-21 — The operative Frame is always visible, and chosen

**Actor:** Amina, steward, who holds a regulatory Frame and a community Frame.
**Precondition:** She opens the Board on a case with Inputs already present.

**THEN** the Board requires an operative Frame before showing columns 2–5. Inputs
are frame-independent and shown regardless; Reference, Meaning, Clarification and
Stewardship are a Frame's view and cannot be rendered without one. There is no
default Frame and no "no frame" state that still shows meanings.

**THEN** the operative Frame is displayed persistently, not buried in a setting.
Everything Amina sees in columns 2–5 is `Y1`'s, and the Board says so where she
is looking rather than where she configured it.

**THEN** Amina may switch Frame. The Inputs do not change — they are the same
Inputs — but the spans, References, Meanings, Clarifications and available
carries all do, because they are different objects in the other Frame, not the
same objects relabelled.

**THEN** the Board does not merge Frames into a combined view. A union of two
ways of seeing is a third way of seeing that nobody holds, and presenting it
would offer meanings no Frame actually settles.

## UC-22 — An authentic carry requires identifying with the Frame

**Actor:** Noor, stewardship lead.
**Precondition:** A fully settled Input in Frame `Y1` offers a carry `X1:Y1:Z1`.
Noor has been reviewing in `Y1` but holds `Y2` as her own.

Noor moves to make the carry.

**THEN** the Board makes the operative Frame unmissable at the point of decision:
this carry is about `X1`, decided within `Y1`, resting on `Y1`'s settlements.
A carry always names its Frame because there is no frameless carry.

**THEN** the Board asks Noor to affirm that she is deciding **within a Frame she
identifies with at the meaning level** — not that she has permission, which is a
separate and already-tested question, but that these Meanings are ones she holds.

**THEN** if she does not, the honest options are to switch to a Frame she does
hold and see what that Frame offers (which may be nothing, or something else), or
to hand the decision to someone who holds `Y1`. Deciding anyway is possible only
as an explicitly recorded act, marked as decided in a Frame the decider does not
identify with, because a carry whose settlements are not the decider's own has
nowhere for its accountability to land.

**THEN** the Board never treats procedural correctness as sufficiency here. Every
step may be valid, the authority test may pass, and the carry may still be
inauthentic — and that is a distinct failure from a refusal (UC-08).

## UC-19 — Span selection is shaped by the meanings already made

**Actor:** Daniel, terminology steward, in a case with a mature Meaning column.
**Precondition:** An Input arrives. Daniel holds several settled meanings about
emergency wording, and reads the Input through them.

Daniel spans the Input and settles the spans.

**THEN** the Board does not pretend the span selection was neutral. Where a span
boundary follows an existing Meaning — where Daniel divided the Input the way his
settled meanings divide the world — that is the ordinary case and is not a
defect. It is how orientation works.

**THEN** the Board records the span selection **alongside the Meaning stock that was
in play**, so a later reader can see the frame Daniel was reading through. A
span selection made against twelve settled meanings is a different act from the same
span selection made against none, and the difference is recoverable only if it was
recorded at the time.

**THEN** a span that no existing Meaning suggests is displayed as such. The
residue an established frame does not carve out is the most interesting thing on
the board: it is where this Input says something the group has not yet settled
how to hear.

**THEN** the Board offers re-spanning as a first-class move, not an edit. Coming
back to an Input and dividing it differently is a legitimate response to having
learned something, and the earlier span selection stays visible — because what a group
once thought the units were is part of the account of how it came to think what
it now thinks.

## UC-20 — Which direction produced this result

**Actor:** Leila, review authority.
**Precondition:** An exploration shows a Meaning with several Inputs attached as
evidence.

Leila asks how those Inputs came to be attached.

**THEN** the Board distinguishes, per attachment, whether it arose from
**Meaning → Inputs** (someone held the meaning and went looking for evidence) or
from **Inputs → Meanings** (an Input was spanned and settled, and landed here).
The two are different claims and are never displayed identically.

**THEN** for a Meaning → Inputs result the Board is explicit that the search was
conducted from the meaning. Evidence found by looking for confirmation is still
evidence, and it is not discredited by its provenance — but a reviewer is
entitled to weigh it knowing how it was found.

**THEN** for an Inputs → Meanings result the Board is explicit that the match was
against the stock of settled meanings. A clean match may mean the Input said
nothing this group has not already settled how to hear, which is a fact about the
group as much as about the Input.

**THEN** neither direction is presented as verification. Nothing in either path
checks a settlement against the world, and the Board makes no claim that it did.

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

**THEN** where the automation **spans** as well as matches, it is doing
something of a different order and the Board treats it as such. Proposing a
reading is a proposal a steward can weigh; proposing where the boundaries fall
decides what readings are available to weigh at all. An automated span selection is
always shown as a proposal, never applied silently, and the steward can re-span
(UC-19) without arguing with a boundary the machine has already treated as
settled.

**THEN** the automation propagates what the group has settled, not what is so.
A mature case that matches everything cleanly may have learned a great deal, or
may have stopped being able to hear anything it has not already settled. The
Board cannot tell these apart and does not claim to.

## UC-18 — The machine proposes from another Frame

**Actor:** Daniel, terminology steward, working in Frame `Y1`.
**Precondition:** A mature case. An arriving Input resembles a clarified meaning
in `Y1` by wording, but the machine's proposal comes from its own Frame, whose
distinctions are not `Y1`'s.

The Board matches it automatically and offers the carry.

**THEN** the proposal is labelled as coming **from another Frame**, not as an
uncertain answer from this one. Daniel is not being told "this might be wrong";
he is being told "this is how a different way of seeing divides and reads this
input." Those are different things and the Board says the second.

**THEN** the machine's Frame is **identifiable and inspectable**. Daniel can ask
what distinctions it draws and what it does not, because a proposal from an
unexamined Frame cannot be weighed — only accepted or refused on faith.

**THEN** Daniel rejects it and settles the Span as `Y1` sees it. The Board does
not record his settlement as a *correction* of the machine's, because the
machine's was not an error in `Y1`; it was a reading in another Frame. Both stay
attributable, each to its Frame.

**THEN** the Board never lets a proposal from another Frame **close** a mapping
in this one. A settlement in `Y1` can only be made by someone working in `Y1`.
Settled-by-inference and settled-in-frame are different states, and only the
latter may reach a carry without confirmation — which is not a caution about
machine reliability but a consequence of what a Frame is.

**THEN** where the machine's Frame turns out to draw a distinction `Y1` lacks and
Daniel finds it useful, adopting it is a change to `Y1` — a governed act with its
own consequences — not a matter of accepting a suggestion. Frames are extended
deliberately or not at all.

---

## Open questions the model raises

These are unresolved. Each affects scenarios above and is worth settling before
implementation.

**OQ-1 — CLOSED.** `brd-col-orientation` carried
`purpose: "Interview points that make the situation intelligible."`, which
described orientation context rather than meaning-making. It now reads
**"What have we settled this part of the input means?"** — the operator's
phrasing, arrived at in two steps (an intermediate *"What meaning am I making
about this input?"* was replaced once the settled/per-part sense was stated).
Board digest moved `642fbc2d882cd` → `734cca5d1d1fb` → `b6c3f182713a3`. Note
that `purpose` is carried in the ACIA document but is **not currently rendered**,
so the page is visually unchanged; the fix corrects what the document says about
itself. If these column questions are meant to appear as framing text under each
heading, that is a separate gap — the strings exist and are simply not displayed.

**OQ-2 — RESOLVED, and it opened a larger question.** A Reference settles *this
span of the input*, so "fully settled" means every span is settled and the
partial state is countable. **Span selection** is the term of art, it is a decision
with consequences, and existing meanings shape it (UC-19).

So "fully settled" is **relative to a span selection**, and two stewards can each
believe an Input complete while having divided it differently. That is not a bug
to engineer away — it follows from span selection being interpretive — but it means
the Board must never present completeness as absolute. See OQ-11.

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

**OQ-10 — CLOSED.** The two questions were briefly near-identical. The operator
settled it by making Reference *"What have we settled this part of the input
means?"*, which separates them on two axes at once:

| Column | purpose | reads as |
| --- | --- | --- |
| Inputs | *Stuff that happens.* | what arrived |
| Reference | *What have we settled this part of the input means?* | **settled**, **per span**, collective |
| Meaning | *What am I making of this?* | **in flight**, **whole**, first-person |
| Clarification | *What clarification do I need?* | what is missing |
| Stewardship | *What is required to carry the meaning forward into action?* | what it takes to act |

Reference is now the settled register and Meaning the working one. Note this is
the **opposite** of the arrangement an earlier draft of this document assumed
(Reference as the in-flight act, Meaning as the settled entity). The board reads
left to right as: something arrived → we have settled what its parts mean → I am
working out what to make of it → here is what I still need → here is what acting
would require.

**OQ-11 — How is a span selection governed?** UC-19 records who marked the spans and against
what Meaning stock, and allows re-spanning. Unsettled: whether a span selection can be
*disputed* the way a Meaning can (UC-10); whether two span selections of one Input can
coexist or one must win; and whether a Reference survives a re-spanning that
moves its boundary. The last is the sharp one — a settlement about a span that
no longer exists is neither valid nor safely discardable.

**OQ-12 — Should the Board ever counteract the reflexive loop?** Meanings shape
span selection, span selection produces References, References feed Meanings. Nothing in the
model breaks that circle, and per the layer statement nothing outside it can:
there is no factual check available. The open question is whether the Board
should do anything about it — surface how long since a span resisted the
existing frame, show the residue rate, invite a differently-framed reader — or
whether that is a facilitation practice rather than a product feature.

**OQ-13 — The board as built has no Frame.** The rendered board shows five
columns with no operative Frame, no Frame selector and no Frame on any card.
UC-21 and UC-22 cannot be satisfied by it as it stands. The identifiers make the
gap concrete: nothing on the board carries a `Y1`, so a Reference cannot be
distinguished from the same Reference in another Frame. **This is the largest
known gap between these scenarios and the artifact.**

**OQ-14 — Where do Frames come from, and who may hold one?** A Frame is holdable,
identifiable-with, extendable (UC-18) and inspectable. Unsettled: whether a Frame
is authored, inherited, institutional, or emergent from a body of settlements;
whether two people can hold the same Frame or only congruent ones; and what it
means for the machine's Frame, which nobody identifies with, to be one at all.

**OQ-15 — Can a settlement be carried between Frames?** UC-18 says adopting
another Frame's distinction changes the Frame. Unsettled whether a Reference can
be *translated* into another Frame — which is what the app is named for — or
whether every Frame must settle every Span for itself. This is the question the
StewardshipTranslation name implies an answer to.

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
| Frame scopes everything except Inputs | UC-21, UC-22 |
| A different Frame produces different spans, References, carries | UC-21, UC-18 |
| The machine is a Frame, not an oracle | UC-18, UC-11 |
| Authentic stewardship requires identifying with the Frame | UC-22 |
| Many Frames exist; one person may hold several | UC-21, UC-22 |
| A Reference is a consequential mapping of a Span to a Meaning | UC-01, UC-07, UC-18 |
| The mapping's consequence is that it affects Stewardship | UC-01, UC-07 |
| Span selection is a consequential decision, recorded and re-doable | UC-01, UC-19 |
| Existing meanings shape the span selection (reflexive) | UC-19, UC-17 |
| Which direction produced a result is visible | UC-20 |
| Nothing here is a claim about factual truth | layer statement, UC-16, UC-20 |
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
