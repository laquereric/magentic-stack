# Translation Board domain model - DRAFT, derived from the board

Status: **draft for correction.** Nothing is built against this yet.

Derived from `app-oriented-translation`: the seven rendered board pages under
`docs/board/page/` (R2), the canonical `translation-board.acia.json` (R1), and
the rules stated in `docs/board/ACIA.md`.

## The problem this draft has to solve

There is no stored model. ACIA.md says the board is *one request-time
projection ... not a stored board*, and *writes no relation, mutates no record*.
Entities are UI components; their kind is **positional** - which panel or list
they sit in - not declared. Everything below is inferred from position, compose
action, and the words on the cards.

**Read the rendered pages, not the JSON.** `translation-board.acia.json` is R1
with five lists. Every rendered page is R2 with seven: `meaning` and
`stewardship` each split into `-accepted` and `-suggestions`. ACIA.md records
the change - unaccepted machine suggestions get their own list rather than a
`quiet` variant, because *quiet does not mean unaccepted*.

## 1. Six entities

The count comes from the compose actions, which are the board's own statement
of what can be created:
`add-input`, `add-frame`, `add-reference`, `add-meaning`, `add-clarification`,
`add-carry`.

| Kind | Lives in | Composes | Observed fields |
|---|---|---|---|
| `Input` | `listKey: inputs` | `add-input` | title, source, observed_at |
| `ContextFrame` | `panelKey: frame-choice` | `add-frame` | title, **canonicalId** |
| `TranslationReference` | `listKey: orientation` | `add-reference` | title, excerpt, **provenance** (cid) |
| `Meaning` | `meaning-accepted` / `meaning-suggestions` | `add-meaning` | title, excerpt, **dispute_open** |
| `Clarification` | `listKey: clarification` | `add-clarification` | title, source, source_at |
| `StewardshipCarry` | `stewardship-accepted` / `stewardship-suggestions` | `add-carry` | title, authority, status |

### Two naming traps, both resolved by evidence

**`orientation` is not the ContextFrame.** The panel keyed `orientation` carries
`action: add-reference`, titled *Add a reference*, navigating to
`compose=reference`, with `contentRole: observation`. The page heads that column
**Translation Reference**. Its cards are evidence-backed observations with
provenance cids. The listKey is a legacy wire name; the kind is
`TranslationReference`.

**The ContextFrame is Y1/Y2/Y3.** `panelKey: frame-choices` (titled *Frames*)
holds three `frame-choice` panels with `canonicalId` Y1, Y2, Y3 - Harbour
operations, Community liaison, Regulatory duty. The trace page names Y1 the
*Operative frame* and offers *Read this input through Y2*. Reading an input
through a lens is ContextFrame semantics; an observation with a provenance cid
is not.

`ContextFrame` is therefore a **small closed set with canonical IDs**, not a
free-growing list - the only entity here with a stable external identifier.

## 2. The one stored relation

`ReferentBridge` is the only edge on the board. Six **mandatory** fields;
missing any one refuses:

    sourceConcept             https://ex/concept/evacuate-immediate-removal
    sourceDefinitionRevision  https://ex/revision/interview-04
    targetExpression          Evacuation notice is an immediate direction to leave
    mappingArtifact           https://ex/map/orientation-to-meaning
    mappingProof              https://ex/proof/orientation-to-meaning
    sourceToTargetScope       https://ex/scope/harbour-resilience/orientation-to-meaning

**It runs TranslationReference -> Meaning, not ContextFrame -> Meaning.**
`sourceDefinitionRevision` is `revision/interview-04`; `cid:interview:04` is the
provenance of the reference card *Residents hear 'evacuate' as immediate
removal*. `targetExpression` is the accepted meaning verbatim.

There is exactly **one** bridge on a board of 14 cards. ACIA.md is explicit that
cards without a mapping *do not get a fabricated bridge*, and that pushing
relation marks into `valueJson` would validate but would **bend the kind**.

### ContextFrame has no stored edge

Y1/Y2/Y3 are `PanelFrame` with `behaviorKind: static`, `contentRole:
navigation`. *Operative frame* is a selection, and *read this input through Y2*
is a read-time lens. Nothing on the board records a frame attached to an input,
a reference or a meaning. **The frame conditions how the board is read, not what
is stored** - so `context_frames` has no foreign key into anything, and the
chain ContextFrame -> Meaning -> Clarification is not a stored path today.

## 3. What must NOT become a column

The board states these in the card text. Storing any would make the record claim
something the board refuses to claim.

| Not stored | The board's words |
|---|---|
| `displayBandLabel` (Effect-eligible / Explorable) | *Display band is a request-time derivation, not a stored field.* |
| Meaning band from clarification | *Completing this card does not itself change a Meaning band.* |
| Meaning band from evidence | *Evidence cue is not a Meaning band.* |
| Band on an unaccepted suggestion | *Machine-proposed, unaccepted. No eligibility band is claimed.* |
| Authorization from display | *Display is not authorization.* |
| Refusal overridden by eligibility | *Meaning eligibility does not override this refusal.* |

**Eligibility is derived, never written.** A `meanings.band` column would be the
first thing to get this wrong, and it would look reasonable.

The trace (FULL / HALF / off) is also derived: what a press reaches through the
bridge plus membership, computed per request.

## 4. Stored state

| Field | On | Observed |
|---|---|---|
| `acceptance` | Meaning, StewardshipCarry | `accepted` \| `suggested` |
| `dispute_open` | Meaning | `true` on *Protective action may mean staying or leaving* |
| `provenance_cid` | TranslationReference | `cid:interview:04`, `cid:interview:05` |
| `canonical_id` | ContextFrame | `Y1`, `Y2`, `Y3` |
| `authority`, `status` | StewardshipCarry | `Harbour Master`, `Pending` |

`acceptance` is a real record distinction, not a rendering: R2 gives accepted and
suggested their own lists precisely so a variant cannot be mistaken for it. An
accepted meaning and a machine candidate are different records.

## 5. Refusals are records, not error paths

Three `RefusalNotice`s, each with `operation`, `reason`, `failedCriteria[]`,
`evidenceRefs[]`, `remediation`, `overridePolicy`. Both observed policies are
`none`.

    operation       claim-plan-eligible
    reason          meaning.actability-insufficient
    failedCriteria  agreement-not-evidenced-for-planning,
                    binding-not-verified,
                    dispute-open
    overridePolicy  none

`dispute-open` is a stored field. The other two criteria have no observed
backing field, so a refusal is **partly** derivable from state and partly not.
That gap is a modelling decision, not an oversight to paper over.

## 6. Proposed AR schema

    inputs                 title, source, observed_at, excerpt
    context_frames         canonical_id (unique), title
    translation_references title, excerpt, provenance_cid
    meanings               title, excerpt, dispute_open:bool, acceptance:enum
    clarifications         title, source, source_at, excerpt,
                           referent_bridge_id -- nullable (owner), see 6a
    stewardship_carries    title, authority, status, acceptance:enum, excerpt

    referent_bridges       translation_reference_id, meaning_id,
                           source_concept, source_definition_revision,
                           target_expression, mapping_artifact,
                           mapping_proof, source_to_target_scope
                           -- all six NOT NULL; a partial bridge must refuse

No `band` column anywhere (section 3). No foreign key on `context_frames`
(section 2). No clarification -> meaning foreign key: a clarification attaches
to the **bridge** (owner, 2026-09-04), which says a clarification is about a
*mapping*, not about a meaning in the abstract.

### 6a. Why that FK is nullable

The board has one bridge and three clarifications, and they do not line up:

| Clarification | About | Bridge exists? |
|---|---|---|
| Duty officer wording agreement signed | the mapped meaning | yes |
| **Test families' interpretation of protective action** | *Protective action may mean staying or leaving* | **no** |
| Formalize local terminology reference | unattached | no |

The meaning that most needs clarifying is the one with no bridge. *Protective
action* is the disputed meaning - `dispute_open: true`, *Agreement and binding
not met* - and the refusal `claim-plan-eligible` sends it to the
productive-refusal wall precisely because it is not yet mapped.

So a NOT NULL bridge FK would make an observed card unrepresentable, and would
assert that **you may only clarify what is already mapped** - inverting the
workflow, since clarification is how a mapping is reached. Nullable keeps the
owner's rule (a clarification, when attached, attaches to a bridge) without
claiming a bridge must pre-exist.

If the intent is the stronger rule, that is a real decision and it makes two of
the three fixture clarifications invalid rather than merely unattached.

`context_frames.canonical_id` is unique - Y1/Y2/Y3 are stable external names.
Every other kind is identified by row id alone; the board gives them no stable
identifier, which is worth confirming before this is built.

## 7. Open questions for the owner

1. ~~Bridge FK nullable or required?~~ **SETTLED (owner, 2026-09-04):
   nullable.** A clarification attaches to a bridge when it has one; a bridge is
   not a precondition for clarifying. Section 6a records why - two of three
   observed clarifications have no bridge, including the disputed meaning that
   most needs one.
2. **Do `binding-not-verified` and `agreement-not-evidenced-for-planning` get
   backing fields?** Storing them makes refusals derivable and auditable;
   leaving them out keeps eligibility wholly a read-time judgement. Both are
   defensible; the board does not decide it.
3. **Is a bridgeless Meaning permanently legitimate?** 13 of 14 cards have no
   bridge. If every accepted Meaning must eventually carry one, that is a
   validation rule; if not, the bridge is an enrichment and most meanings are
   free-standing forever.
4. **Does ContextFrame ever become a stored relation?** Today it is a read-time
   lens with no FK. If a meaning is ever *asserted under* a frame, that is a new
   edge and a contract change, not a column added quietly.
5. **Stable identifiers.** Only ContextFrame has one. If references and meanings
   need external identity - and the bridge's `sourceConcept` IRIs suggest they
   might - that belongs in the schema rather than in a later migration.
