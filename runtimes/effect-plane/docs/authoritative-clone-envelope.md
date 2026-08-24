# `host_volume` + `clone_evidence` vs `:authoritative`

Status: **judgement accepted; proposal IMPLEMENTED.**
Branch: `grok/effect-plane-authoritative-clone` from `898893a`.
Pin: `spec/classifier_spec.rb` example
`host_volume + clone_evidence is compensable EVEN FOR role :authoritative`.

## Exact call

```ruby
p = Mmg::EffectPlane::Placement.declare(
  effect_id: "e1", target: "/data/x",
  topology_evidence: { stage: :host_volume },
  mount_inventory: [{ path: "/data", writable: true, disposition: :excluded }]
)
Mmg::EffectPlane::Classifier.classify(
  effect: "e1", placement: p,
  authority: { role: :authoritative, clone_evidence: "snap-1" },
  external_effects: []
)
# today:
# { ok: true, classification: :compensable, rollback: :declared_volume_clone,
#   conditions_required: [], ... }
```

`host_volume_verdict` returns on `clone_evidence` **before** it reads `role`.
`:sole_authority_store` lives only in `snapshot_verdict`. A05 already covers
the un-roled clone; it does not name `:authoritative`.

## Intended or oversight?

**Intended as a compensating volume restore. Oversight in the envelope.**

The design table for `:host_volume` says there is **no image rollback**; the
only restore is “a separately declared, consistent volume snapshot/clone plus
a fork event.” Classification `:compensable` / rollback `:declared_volume_clone`
matches that. It does **not** claim `:fork_and_activate`, and
`conditions_required` is empty, so it is already not a C1–C9 materialization.

Refusing the clone would collapse a real compensating action (copy Plane B
onto a named volume) into the same refusal as “fork the sole authority as if
it were derived state.” That would be the wrong plane.

The defect is that `{ ok: true, classification: :compensable }` can be read as
“we now have a rollback story / a first-class materialization.” Phase 2b did
exactly that risk: supply `clone_evidence` and the classifier goes green on
the truth store. The rollback class is honest; the envelope does not name
**what was cloned**.

## Smallest change (implemented)

Do **not** refuse. Add two keys to the `ok: true` verdict, populated from
the authority already in hand:

| key | value for this call |
|---|---|
| `authority_role` | `:authoritative` (or the declared role, else `nil`) |
| `materialization` | `true` iff `classification == :fork_reversible` |

Callers who meant “is this a Plane C materialization?” read `materialization`.
Callers who meant “did we clone the truth store?” read `authority_role`.
Existing keys stay. Additive; A05 and A08 keep their meaning.

Not in this change: moving `:sole_authority_store` onto `host_volume`, or
making `clone_evidence` consult `REPLAYABLE_ROLES`. Those would refuse a
declared volume clone of Plane B, which the design still wants as compensation.

## Outcome

Implemented in `Classifier.verdict`, which now carries the declared role through
from every call site. `materialization` reuses the predicate
`conditions_required` was already computing, so it names an existing rule rather
than inventing one. No classification changed; nothing new is refused.

The motivating case now reads:

| exhibit | ok | classification | authority_role | materialization |
|---|---|---|---|---|
| authoritative volume, excluded | true | `irreversible` | `authoritative` | **false** |
| authoritative volume + `clone_evidence` | true | `compensable` | `authoritative` | **false** |
| Phase 2b lie: projection of the absent graph | true | `compensable` | `projection` | **false** |

All three were `ok: true` before and still are, because all three are honestly
classified. What changed is that a caller can now tell them apart without
reading `rollback` and knowing the doctrine: row two says it cloned the truth
store, and no row claims to be a Plane C materialization.

76 examples, 0 failures.
