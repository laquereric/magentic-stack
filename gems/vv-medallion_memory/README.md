# vv-medallion_memory 🟡 CONTRACT ONLY

A bot's **yesterday**. Not a document index, not a bigger context
window. Private gem — not on rubygems.org (ADR 0038).

Design: [`docs/architecture/plan_vv_medallion_memory.md`](../../docs/architecture/plan_vv_medallion_memory.md).

## What is built, and what is deliberately not

**Built: the contract half.**

| Piece | What it fixes |
|---|---|
| `Tier` | Exactly three Build tiers. Platinum, Serving and Working refused **by name, with reasons**. |
| `Purpose` | Build / Consume / Operate as **siblings**, so neither Consume nor Operate ever needs to become a rank. |
| `Refusal` | The ten named reasons, closed. The plan requires they exist *before* a happy path is claimed. |
| `Provenance` | `observed \| inferred`, a bounded generation counter, and the cardinal sin as a refusal. |
| `Flows` | The six memory Flows, declared as data. `memory.distill` blocked by name. |
| `EngineBinding` | Refuses `medallion_home_undecided`. |

**Not built: the engine.** No Conformer, no Curator, no projection —
and `spec/medallion_memory_spec.rb` asserts that against the source
tree rather than trusting it. The plan names *"forking `mmg-medallion`
into this gem"* as a non-goal, and a small private Conformer "just to
get going" is how that fork arrives.

## Why it stops here

The plan blocks itself, twice, on one owner decision:

> **M-home.** Stack `gems/mmg-medallion` vs MM nested repo + pin.
> **The rest of M1–M10 does not start until this is named.**

Measured 2026-09-11: `mmg-medallion` 0.2.0 is its own git repo nested at
`magentic-market-ai/gems/mmg-medallion`, and the parent gitignores
`gems/`. A gitignored nested repo cannot be pinned as a closed-substrate
dependency, which is why the question is open rather than merely unasked.

A blocker that lives only in a paragraph is one nobody trips over. So
`EngineBinding.bind!` **refuses**, and names what is waiting:

```ruby
Vv::MedallionMemory::EngineBinding.bind!
# => {ok: false, reason: "medallion_home_undecided",
#     because: "M1-M10 do not start until the owner names where mmg-medallion
#               lives… Waiting on: M1 (arm SPARQL writes); M2 (real SHACL gate); …"}
```

It keeps refusing even when a home *is* named, because naming is not
landing:

```ruby
EngineBinding.bind!(home: :stack)
# => {ok: false, … "home stack is a valid choice … but no engine change has landed"}
```

Everything in this gem was written to be true under **either** answer.
None of it has to be renegotiated once the home is named.

## The cardinal sin

Summarising on ingest — and the form it actually arrives in is not an
overwrite, it is a **laundering**: derived text wearing an `observed`
stamp. After that lands, nothing can tell what was said from what a
model said about it.

```ruby
envelope.refusal
# => {ok: false, reason: "bronze_mutated",
#     because: "…is derived from urn:mm:episode/1 but is stamped observed.
#               A summary may be LANDED as new inferred Bronze; it may not
#               enter the floor as source"}
```

The escape hatch, and the only one, is `derive` — which always bumps the
generation, always stamps `inferred`, and always names its parent, so
the three rules cannot be satisfied by accident:

```ruby
derived = envelope.derive(actor: "agent:reflector", derived_from: "urn:mm:episode/1", observed_at: t)
derived.kind        # => "inferred"
derived.generation  # => 1
```

Past `MAX_GENERATION` (3) it is `inferred_unbounded`. The loop **is**
circular by design — Gold reflections become new Bronze — and a flag plus
a finite bound is all that stands between that and a system that eats its
own output forever.

## Why Platinum is not a tier

A weight matrix has **no tombstone**. A fact cannot be deleted from it
the way a row is dropped, and a weight update leaves no audit trail for
the provenance of the shift. So Platinum is `Purpose::OPERATE` — an
optional, rebuildable cache distilled from **Silver**, never from
Gold-as-weights — and `memory.distill` stays blocked until temporal
validity (M5) and deletion cascades (M9) exist. Distilling before a
tombstone can cascade means a forgotten fact can be resurrected from
weights with nothing downstream able to tell.

The live context window is **volatile Bronze**, not Platinum. Confusing
the two is how a session cache becomes a weight update with no receipt.
