# Meaning activations — weighted joins, not a stored tree

> ## BUILT 2026-09-11
>
> Migration, five models, the SHACL amendment and two gates. The contract
> below is kept; what follows is what it cost.
>
> **The weight bound is a database trigger, not only a validation.** A
> model validation is bypassed by `update_column`, an import, and the
> console, and this file calls the check constraint "the contract". SQLite
> takes no CHECK on an existing column here, so the bound is four triggers
> raising `weight_out_of_range`. Verified against the live pod: both
> `update_column(5.0)` and a raw `INSERT ... 9.9` were refused by the
> database.
>
> **Gap 107's gate was amended with the shape, not after it.**
> `check_contextframe_containment` asserted `cf:inContextFrame` minCount 1
> AND maxCount 1. The half that changed is the cap; the half it was written
> to defend -- a meaning that names no frame is unanchored -- is unchanged
> and still enforced, now on `cf:frameActivation`. Its planter grew a
> second case: putting `maxCount 1` back on an activation must fail, or the
> amendment could be reverted silently.
>
> **Measured in the pod, not asserted here:** `±1.1` refuses;
> a duplicate pair refuses `activation_not_unique`; a frame with `+1`, `0`
> and `-1` activations walks to exactly the `+1` child while all three rows
> stay visible on inspect; and a never-linked pair returns zero rows rather
> than a zero weight.
>
> Undecided still undecided: two-hop weight algebra, `user_id` per
> activation, bridge-vs-meaning, the `> 0` threshold, float vs decimal.

Companion to gap 107 (`contextframe.shacl.ttl`: containment, not three
peers), [`TRANSLATION_BOARD_MODEL.md`](TRANSLATION_BOARD_MODEL.md)
(board storage), and the strict-tree ORM sketch that this **replaces**.

---

## What this is

ContextFrame, Meaning, and Clarification stay three records. What
changes is the **edge**.

A simple hierarchy (`Meaning belongs_to ContextFrame`,
`Clarification belongs_to Meaning`) stores membership as a foreign
key: in or out. That is too coarse. A meaning is not owned by one
frame; it is **activated** under frames with a signed weight. A
clarification is not owned by one meaning; it is activated under
meanings the same way.

```
ContextFrame  has_many Meanings
              through: ContextFrameMeaningWeight   weight ∈ [-1, +1]

Meaning       has_many Clarifications
              through: MeaningClarificationWeight  weight ∈ [-1, +1]
```

The path ContextFrame → Meaning → Clarification is still how you
*walk* the structure. It is no longer how you *store* parenthood.
There is no `meanings.context_frame_id`. There is no
`clarifications.meaning_id`.

---

## What is actually there (so this is not a wish)

| Thing | Measured |
|---|---|
| AR models for the three | **none.** |
| Join tables | **none.** |
| SHACL | **strict tree.** `cf:inContextFrame` and `cf:inMeaning` are minCount 1 maxCount 1. "A Meaning belongs to exactly one ContextFrame." |
| Board sketch | **no FKs at all.** Frame is a read-time lens; clarification was aimed at a bridge, not a meaning. |

This plan **amends gap 107's maxCount 1**. A meaning may carry
activations to many frames; a clarification to many meanings. minCount
1 on the *shape of a message* can remain (a payload that names a
meaning must name at least one activation). Persistence is the join
row, not a parent id.

It also **does not** store eligibility/`band` (board §3). Weight is
not a band.

---

## Weight

Closed interval **[-1, +1]**, stored as numeric (not enum, not bool).
Out of range is a refusal (`weight_out_of_range`), not a clamp.

| Weight | Means |
|---|---|
| `+1` | full activation |
| `(0, 1)` | partial activation |
| `0` | **present and inert** — the pair is known, it does not fire |
| `(-1, 0)` | partial inhibition |
| `-1` | full inhibition |

**No row is not zero.** Absence means the pair is not in the model.
Zero means it is, and contributes nothing. Collapsing those two makes
"we considered this and rejected it" indistinguishable from "we never
looked."

One row per pair: unique `(context_frame_id, meaning_id)` and
`(meaning_id, clarification_id)`. A second weight for the same pair
is `activation_not_unique`, not a second line to average.

Sign is first-class. Inhibition is not "delete the join."

---

## ORM (target)

```ruby
# frozen_string_literal: true

class ContextFrame < ApplicationRecord
  has_many :context_frame_meaning_weights, inverse_of: :context_frame,
           dependent: :restrict_with_error
  has_many :meanings, through: :context_frame_meaning_weights
end

class Meaning < ApplicationRecord
  has_many :context_frame_meaning_weights, inverse_of: :meaning,
           dependent: :restrict_with_error
  has_many :context_frames, through: :context_frame_meaning_weights

  has_many :meaning_clarification_weights, inverse_of: :meaning,
           dependent: :restrict_with_error
  has_many :clarifications, through: :meaning_clarification_weights
end

class Clarification < ApplicationRecord
  has_many :meaning_clarification_weights, inverse_of: :clarification,
           dependent: :restrict_with_error
  has_many :meanings, through: :meaning_clarification_weights
end

class ContextFrameMeaningWeight < ApplicationRecord
  belongs_to :context_frame, inverse_of: :context_frame_meaning_weights, optional: false
  belongs_to :meaning,       inverse_of: :context_frame_meaning_weights, optional: false

  validates :context_frame_id, uniqueness: { scope: :meaning_id }
  validates :weight, numericality: { greater_than_or_equal_to: -1, less_than_or_equal_to: 1 }
end

class MeaningClarificationWeight < ApplicationRecord
  belongs_to :meaning,        inverse_of: :meaning_clarification_weights, optional: false
  belongs_to :clarification,  inverse_of: :meaning_clarification_weights, optional: false

  validates :meaning_id, uniqueness: { scope: :clarification_id }
  validates :weight, numericality: { greater_than_or_equal_to: -1, less_than_or_equal_to: 1 }
end
```

Tables:

```
context_frames                 id, canonical_id unique, title, user_id
meanings                       id, title, excerpt, dispute_open, acceptance
clarifications                 id, title, source, source_at, excerpt

context_frame_meaning_weights
  id
  context_frame_id  not null  fk
  meaning_id        not null  fk
  weight            numeric not null  check (-1 <= weight and weight <= 1)
  unique (context_frame_id, meaning_id)

meaning_clarification_weights
  id
  meaning_id        not null  fk
  clarification_id  not null  fk
  weight            numeric not null  check (-1 <= weight and weight <= 1)
  unique (meaning_id, clarification_id)
```

`restrict_with_error` on the `has_many` of weights: deleting a frame
that still activates meanings is a refusal, not a cascade that
rewrites the net.

No `clarifications.context_frame_id`. A clarification reaches a frame
only as Meaning through the two joins. Storing a shortcut FK would let
a clarification inhibit under a frame its meaning does not activate.

---

## Read-time tree

The **operative** tree is derived per request from the joins, not
stored. A default walk (until an ADR says otherwise):

- From a frame: meanings whose join weight is **> 0**, ordered by
  weight descending.
- From a meaning: clarifications whose join weight is **> 0**, same
  order.
- Inhibitions (`weight < 0`) are visible on inspect; they do not
  appear as children in the default walk.
- `weight = 0` joins are visible on inspect; they do not fire.

FULL / HALF / off traces stay derived (board §3). Do not cache them
as a column on the join.

---

## SHACL / CPCP

Gap 107 shapes must change with this, not after:

- Replace `cf:inContextFrame` maxCount 1 with a list of activations
  (`cf:frameActivation` → node with `cf:frame` + `cf:weight`).
- Same for `cf:inMeaning` → `cf:meaningActivation`.
- `cf:weight` datatype decimal, minInclusive -1, maxInclusive 1.
- A message that names a meaning still needs **at least one** frame
  activation (minCount 1 on the list), or it is unanchored.

CPCP payloads carry the join, not a parent id. SparqlFun's
standard-form frame still requires `userId` on the **frame record**.
That id is not a weight.

---

## What this document will not decide

| Decision | Why it is not mine |
|---|---|
| How competing +/− weights combine when walking two hops | algebra; default is "positive children only" until an ADR |
| Whether `user_id` on ContextFrame is per-activation | SparqlFun principal is the frame, not the join |
| Bridge vs meaning as clarification target | board 6a; this plan only covers the three-node path |
| Threshold other than `> 0` for the default walk | product |
| Float vs decimal precision | storage; check constraint is the contract |

---

## Gates — built

- `meanings.context_frame_id` / `clarifications.meaning_id` must not
  exist. Plant: adding either column fails.
- Weight `-1.1` or `1.1` refuses. Plant both ends.
- Two join rows for the same pair refuse. Plant duplicate.
- Missing join ≠ weight 0. Plant: query for a never-linked pair
  returns absence, not `0`.
- Default children walk excludes `weight <= 0`. Plant: a `-1` join
  does not appear in `frame.meanings` used as the operative list
  (inspect still sees it).
- Zero jobs is a fail. A checker that has never been planted is not
  a gate.

All of the above are `tooling/cpcp/check_meaning_activations.py`, and all
six plants fire: a parent FK on `meanings`, a shortcut FK on
`clarifications`, a bound that lives only in the model, a non-unique pair
index, a walk that admits `weight <= 0`, and a refusal that stops naming
itself.
