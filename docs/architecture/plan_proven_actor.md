# The proven actor — closing G13 as the substrate's next move

**Origin.** `stewardship-intelligence-cloud/docs/generated/overlay-gap-analysis.md`
recast twelve product capabilities against this substrate and found the set
blocked on one substrate gap: **G13, identity so "who did what" is true.** Its
conclusion is that an overlay cannot route around G13 without inventing the
second identity plane that G13's own move and ADR 0063 both forbid.

That conclusion is correct, and this plan does not re-argue it. What this plan
does is the part an overlay analysis cannot: state what is actually wrong in the
substrate, measured rather than restated, and order the work.

---

## 1. Two of its inputs have already moved

The analysis reads `CANONICAL_GAPS.md` as measured **2026-09-14** and says so —
"G11 has since closed … so other gaps may have moved too." Two have, and both
shorten this plan rather than lengthen it.

| Gap | As read | Today |
|---|---|---|
| **G1** — no FRONT base image | blocking P3 | **CLOSED.** `runtimes/front-base` exists, is pinned by `FLOOR-FRONT.json`, and is published to GHCR by `publish-images` |
| **G0** — doctrine says Rails, code says Bun | open conflict | **Resolved in doctrine.** `docs/adr/0072-front-is-bun.md` exists; `tooling/compose/language_rule.json` records the Bun FRONT as reached |

This matters for sequencing. The ordered path in `CANONICAL_GAPS.md` puts the
FRONT base at **P3** and "bind required" at **P6**, with G13 effectively last.
With P3 shipped, the thing standing between here and a proven actor is smaller
than the path implies.

---

## 2. What is actually wrong — measured, not restated

G13's "Today" line reads *"ADR 0040 unenforced (no proven actor)"*, which is
true but describes an absence. The substrate's problem is worse than an absence,
and it is visible in two facts.

**Fact one: reads refuse an unknown actor; writes do not.**

`profile9/pulls.rb:22` — to LIST a journey you must prove who you are, and the
actor must resolve in the graph:

```ruby
actor_cid = Request.require_cid!(params, "actorCid")
Request.unresolved!("actor", actor_cid) unless Graph.actor(actor_cid)
```

`profile9/mutations.rb` — to WRITE a `ui.action` into the ledger, `actorCid` is
not in the required set at all. `predecessorCid`, `predecessorDigest`,
`eventKind`, `aciaDocumentDigest` and `tokenSetDigest` are each
`require_cid!`'d. The actor is not.

**You must say who you are to read, but not to write.** For a substrate whose
claim is accountability, that is exactly backwards.

**Fact two: the field is never absent, so nothing ever looks wrong.**

`profile9/mutations.rb:193`:

```ruby
"actorCid" => params["actorCid"].to_s.empty? ? Graph.j1_actor_cid : params["actorCid"],
```

and `profile9/graph.rb:8`:

```ruby
ACTOR_CID = "cid:actor:governance-steward"
```

An action arriving with no actor is recorded as having been taken by
`cid:actor:governance-steward` — a seed constant. The ledger row is
well-formed. It passes shape validation. It is indistinguishable from a row
where a real steward acted.

This is the defect in its sharpest form: **G13 is not a missing field, it is a
defaulted one.** A missing actor is visible and refusable. A defaulted actor is
a false statement in a governance ledger, and it is the substrate that writes
it. `pageCid` on the line above has the same shape and the same problem.

**Nothing gates this.** `git grep actorCid -- tooling/ .github/` returns one
incidental hit in `shape_constraint_ledger.json` and no checker. ADR 0070
carries a literal `enforced_by: []`.

---

## 3. Why this is the substrate's to fix

ADR 0063 makes the base image an interface. An overlay that shipped its own
actor model would produce the second identity plane G13 forbids, and would
break the moment the substrate grew a real one. The overlay analysis reaches
the same place from the other side. There is no disagreement to resolve — only
work to order.

---

## 4. The plan

Five moves. Each is observable, each fails closed, and each is small enough to
land on its own.

### S1 — Stop lying by default *(smallest, highest value)*

Remove the `actorCid` default in `mutations.rb`. An action with no actor is
**refused**, not attributed to `cid:actor:governance-steward`.

- Refusal reason: `actor_unproven`, in the existing envelope vocabulary
- `require_cid!` for `actorCid` on the PUSH path, matching the PULL path
- `Request.unresolved!("actor", …)` when the CID does not resolve in the graph

**Observable:** a `ui.action` without `actorCid` returns a refusal envelope
instead of a written ledger row. **Cost, stated plainly:** this will break every
caller that currently relies on the default, which is the point — those callers
are producing false rows today. Expect the mind-pod demo and any probe that
posts `#taskSlot` without an actor to start refusing.

### S2 — A gate, so it cannot come back

`tooling/cpcp/check_actor_provenance.py` plus `plant_actor_provenance.py`.

The gate holds two things:
1. **No defaulting.** No `actorCid` (or `pageCid`) assignment whose right-hand
   side falls back to a constant when the parameter is empty — the literal
   pattern above, held as a source rule.
2. **Symmetry.** Every mutation that writes an actor-bearing ledger row
   `require_cid!`s the actor, so the read/write asymmetry cannot reappear.

The plant reverts S1 in a sandbox and must go red. Both are auto-discovered by
`bin/sweep`, so they run in `gate-main-green` on every push and PR with no new
workflow — and `bin/ci-local` runs them on Linux over a clean clone before the
push.

**Observable:** re-introducing the default fails the sweep, naming the line.

### S3 — Make ADR 0040's claim checkable

ADR 0040 — *One Session across human and agent actors, and it is not
authorization* — is `accepted` and unenforced. It is also, as the overlay
analysis notes, already framed for **human and agent** actors: the substrate
named the participation claim before the product vision did.

Give it an `enforced_by` that points at S2's gate, and give ADR 0070 the same
once its own blocker clears. An ADR whose `enforced_by` is `[]` is a decision
nobody can be held to.

**Observable:** `check_enforced_by.py` (exists) stops treating 0040 as
unenforced.

### S4 — Bind is where the actor comes from

`front-base` already refuses with `front_bind_refused`
(`src/skeleton.js:104`, `src/core/core.js:9`). G13's move says the FRONT base
must fail closed **without** bind, not merely be able to. With P3 shipped this
is now a small change in a published image rather than a new image.

Core pairing is how an Actor row is created — per G13, *do not invent a second
identity plane*.

**Observable:** a FRONT served without a bound actor renders the refusal, and
`ui.action` from it carries a real `actorCid` that resolves.

### S5 — Then, and only then, the overlay

With S1–S4 landed, the overlay analysis's SI-G1 is unblocked and its archetypes
2, 4, 7 and 8 become buildable. The seventh `shapes-application` slot it
describes is a slot and no substrate code, exactly as ADR 0063 says.

---

## 5. Where this sits against the existing path

`CANONICAL_GAPS.md` §8 orders P0–P6 with bind at **P6**. This plan proposes
**pulling S1 and S2 forward, out of order**, and the justification is narrow:

P1–P5 are about the FRONT surface — skeleton, widget catalog, A2UI coverage,
overlay thinness. **S1 is not a FRONT change.** It is a BACK refusal, and every
day it does not land, the ledger accumulates rows attributing actions to a
constant. Those rows do not improve when the FRONT settles; they are wrong now
and stay wrong.

The rest of the path is untouched. S4 is P6, unchanged in content and cheaper
than it was because P3 has shipped.

---

## 6. What this plan does not do

- **It does not build an identity provider.** S1 refuses unproven actors; it
  does not decide how an actor is proven. That is S4 and Core pairing.
- **It does not touch authorization.** ADR 0040's title is explicit that the
  Session *is not* authorization, and nothing here changes who may do what.
- **It does not promise the overlay.** S5 is a consequence, not a commitment.
- **It does not close G12.** Consequence routing (SI-G2) still needs Journey /
  Flow / FlowStep rows, and that is overlay work on an open substrate gap.

---

## 7. Standing

The substrate facts in §1 and §2 are measured from this repository at
`58b4680` and are checkable: file and line are given for each. The **ordering**
in §4 and the argument in §5 for pulling S1 forward are a proposal, not a
decision — no ADR says the ledger must refuse rather than default, which is
itself part of the finding. `CANONICAL_GAPS.md` was last measured 2026-09-15
and §1 shows two of its entries have already moved; others may have.

The overlay analysis's own standing section applies here too: nothing in it had
been put to this substrate's maintainers. This document is the first half of
doing that.
