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
bundle exec rspec        # 78 examples
```
