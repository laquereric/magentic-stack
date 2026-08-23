# mmg-semantic-editor

An editor for a document that stands for several records, and knows which is
which.

Ordinary editors edit a document. This one takes an ACIA tree whose nodes carry
**canonical ids** and **disclosure tiers**, lets a person rewrite a Frame as
prose, and turns the result back into the set of writes it actually implies —
grouped by target structure, and offered whole or not at all.

That single difference is the point. A person writing a paragraph about a Frame
is editing a frame record, three meaning records and five clarification records
at once. They should not have to hold those boundaries in their head; the ids
are what let the editor put each line back where it came from.

It exists because of what the board is for. A Frame is the apparatus a person
reasons *within*; adjusting it is the act of agency the board is built to
support. That act should feel like writing, not like filling in a form.

The gem is **headless**. It knows about ACIA trees, canonical ids, disclosure
tiers and prose. It knows nothing about the board, HTTP, or any particular
store. The board mounts it as a modal; a different consumer could mount it
anywhere.

## The five modules

| Module | What it is responsible for |
|---|---|
| `Disclosure` | The four visibility tiers — `immediate`, `hover`, `sidebar`, `detail` — and their ordering |
| `CanonicalId` | The seven id shapes, and which underlying structure an edit to each one lands on |
| `Document` | Indexing a tree by canonical id and tier; admissibility; what is hidden beneath the tier being edited |
| `Prose` | The round trip between a Frame's structure and one editable text |
| `Diff` | The default view: an edit shown as `+` / `-` lines |
| `Decompose` | One edit session → several simultaneous edits, whole or not at all |

## Canonical ids

```
X1            Input          frame-independent
Y1            Frame          the apparatus
Y1:M1         Meaning        belongs to the Frame
Y1:M1:C1      Clarification
X1:Y1         Translation    DERIVED — never a write target
X1:Y1:R1      Reference      produced, and settled
X1:Y1:Z1      Stewardship    produced, and decided
```

The two sides of the model are legible in the id itself: what belongs to the
Frame leads with the Frame; what is produced by applying it leads with the Input
it is about.

A **Translation is derived per request and never stored**, so it is never a
write target. An edit addressed to one is refused with `:derived_not_writable`
rather than silently dropped — what the editor means in that case is an edit to
something the Translation was derived *from*.

## Prose mode

The format is deliberately plain. It is not markdown and it is not YAML; it is
the smallest thing that survives a person retyping it by hand.

```
[Y1] Harbour operations
Frames what we are here to look after and what counts as looking after it.

  [Y1:M1] Berth allocation is a duty of care
  A berth is not a slot on a chart. Who gets one, and when, decides whose
  livelihood is interrupted.

    [Y1:M1:C1] A vessel already alongside is not thereby entitled to stay.
```

A line whose id is removed is a new record; a record whose line disappears is a
deletion. Both are decisions the editor **surfaces** rather than guesses at,
which is why `Prose` only reports them and `Decompose` is what acts.

## The default view is a diff

`+` and `-` mean one thing everywhere. On the board they are affordances — add a
card, remove a card. In the editor they are the record of the same acts, already
performed: a line that came into being, a line that went away. A person who has
understood the buttons has already understood the view.

```
 Harbour operations
 Frames what we are here to look after.
   Berth allocation is a duty of care
-  A berth is not a slot on a chart.
+  A berth decides whose livelihood is interrupted.
     Already alongside is not thereby entitled to stay.
-  Tide windows bind everyone equally
-  No vessel is owed a window another loses.
+  Weather is not a party to the agreement
```

This is not decoration. The alternative — rendering the new text and trusting the
reader to notice what moved — hides exactly the thing that matters when one
paragraph is about to land as several simultaneous writes. A diff makes the
**scope** of an edit legible before it is applied, which is the whole reason the
plan is offered whole or not at all.

Three things make it a diff of **records** rather than of characters:

- Blocks match by canonical id, so rewording a meaning reads as one change, not
  as a deletion beside an unrelated addition.
- A changed block is diffed line by line, so an untouched heading stays context.
  Noise in a diff is worse than noise in prose: it trains the reader to skim the
  one view whose entire job is to be read closely.
- A deletion keeps its position — a removed clarification appears under the
  meaning it was removed from, which is the only place it means anything.

`Diff.summary` gives the one-line form (`1 added, 1 changed, 1 removed.`) for a
surface with no room, and `Diff.targets` names the structures the edit reaches.

`VIEWS` is `[:diff, :prose]` and `DEFAULT_VIEW` is `:diff`. Choosing between them
is a consumer setting; the seam is here, and no surface offers the switch yet.

## Usage

```ruby
session = Mmg::SemanticEditor.open(acia: tree, focus: "Y1")

session[:prose]     # => the editable text above
session[:hidden]    # => ["Y1:M1:C1"] — attached, but below the tier on screen
session[:derived]   # => ["X1:Y1"]    — shown, but not writable

plan = Mmg::SemanticEditor.stage(session: session, acia: edited_tree)

plan[:by_target]    # => { frames: [...], clarifications: [...] }
plan[:coherent]     # => false if any edit was refused or would orphan something

Mmg::SemanticEditor.commit(plan) do |target, edits|
  store.write(target, edits)   # returns { ok: true } or { ok: false, because: ... }
end
```

## Two refusals worth knowing about

**Orphaning.** Deleting a Meaning whose Clarifications sit at the `sidebar` tier
is the classic disclosure accident — the person was editing the immediate tier
and never saw them. `plan[:coherent]` goes false and `apply` refuses before the
first write.

**Incoherence.** The edit set is offered whole or not at all. A plan whose parts
land separately can leave a Frame carrying a Meaning that its Clarifications no
longer explain — precisely the incoherence the board exists to make visible.

## Envelopes

Every boundary method returns `{ ok: true, ... }` or
`{ ok: false, reason:, because: }`. Nothing raises. `Dry::Monads` is not a
dependency.

## Tests

```sh
bundle install
bundle exec rspec        # 98 examples
```
