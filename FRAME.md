# One Frame: layer × phase × cost × evidence

Integrating six things that are usually discussed separately:

- **Kent Beck, 3X** (`magentic-market-ai/docs/research/KentBeck3Es.md`) — Explore / Expand / Extract. A *temporal* frame: which phase a product is in dictates which engineering practice is correct.
- **Kent Beck, Futures vs Features** (`KentBeckFutureFeature.png`) — two axes, two curves. The green curve spends futures to buy features (optionality burns down as the feature count rises). The red curve — circled, the one you want — adds features while holding futures high. A *cost* frame: what each move spends.
- **The Magentic Stack** (`magentic-stack/`) — ownership tiers (🟢 OWN / 🔵 OFFICIAL / 🟡 FOLLOW), the `gems/` package layer, and overlays (ADR 0063, ADR 0073). A *spatial* frame: where a change is allowed to land.
- **Perch v2** (`gems/vv-perch`, `docs/architecture/plan_vv-perch.md`, `magentic-market-ai/docs/research/perchv2.md`) — the sized slice, the freeze ladder, the orphan ledger, the outward signal. The *instrument* frame: how a futures spend gets priced, owned, and refused.
- **Orinth / Ornith-1.5** (`gems/vv-orinth`, `docs/architecture/plan_ornith.md`, `docs/architecture/OrinthDistill.md`) — five envelopes, GRPO, and dev→prod distillation over the Bronze/Silver/Gold/Platinum medallion. The *evidence* frame: how a claim earns the standing to justify a commitment, and what you do with an artifact that cannot be un-made.
- **Smart zone / dumb zone** (`magentic-market-ai/docs/research/SmartDumbContext.md`) — the smart part of a context window is ~100K however big the box says; attention is U-shaped; compaction trades length for lossiness. The *reader* frame: who loads this, how much of it fits, and what survives a reset.

They are the same frame seen from six sides. Below is the merge.

---

## The thesis in one sentence

**The red curve is not a discipline you can practice inside one codebase — it is a structure you buy by putting feature velocity in a layer whose futures don't matter, and putting the futures you care about in a layer no feature ever touches.**

The ownership boundary *is* the device that produces the red curve. 3X tells you which phase each layer is in. Futures/features tells you what each layer is allowed to spend. **Perch is the instrument that prices the spend, names who bears it, and refuses the ones that must not be available at all. Orinth says what evidence licenses the spend — and what to do with one that cannot be taken back.**

---

## The merge table

Each layer has a **home phase** and a **currency it may spend**. Every rule in the stack falls out of this.

| Layer | Path | Home phase | May spend | Clock | Freeze rung | Evidence to change it |
|---|---|---|---|---|---|---|
| **Overlay** | application repos, `apps/`, `plugins/` | **Explore** → Expand | futures freely (it has none worth keeping) | days | 0–1 | Bronze — it happened |
| **Runtimes / gems** | `runtimes/`, `gems/` | **Expand** → Extract | futures deliberately, once named | weeks | 2 | Silver — a typed, dated verdict |
| **Grammar** | `grammar/` (OSI-8, CPCP, SHACL) | **Extract** | futures-preserving moves only | quarters, or never | 3–4 | Gold — contracted, with a freshness claim |
| **Upstreams** | `upstreams/` (NOOA, NeMo Switchyard, json-rpc-ld) | *someone else's 3X* | the pin cost | pinned; churns ~90d behind the seam | n/a — pinned | theirs, not ours |

Read across a row and you get the practice. Read down the "may spend" column and you get the architecture's whole argument.

The last two columns are the frame's central claim. **Freeze rung** is Perch's ladder (§6.1) — the same ordering as the layers, expressed as reversal cost. **Evidence** is the medallion tier Orinth runs on — the same ordering again, expressed as what licenses the change. Three independently-designed ladders that turn out to be one ordinal is not a coincidence; §Perch and §Orinth below are the argument.

### Why the tiers say what they say

> *"Own the language and the contracts; follow the runtimes and routers."* — `magentic-stack/README.md`

In 3X terms: **own what is in Extract, follow what is in Explore.** Frontier AI upstreams are in permanent Explore — that is what a ~90-day churn loop *is*. You cannot run Extract discipline on top of a dependency running Explore, so you don't try: you pin it. A pin is a futures-preserving device. It converts someone else's volatility into a number you can read, diff, and choose when to pay.

`gems/` reads as derivative by design — *"a behaviour change starts in `grammar/`, then lands here"* — because a change that starts in `gems/` would be a feature purchased directly out of the substrate's futures. The rule routes the spend through the one place where futures are the unit of account.

---

## Overlays: one word, two senses, one meaning

ADR 0063 and ADR 0073 use "overlay" for different things, and the frame shows they are the same thing on different axes.

- **ADR 0063 — the spatial overlay.** An application builds `FROM` a pinned substrate base image, adds a Rails engine gem and its host, *"and nothing else."* It consumes the substrate; it does not live in it.
- **ADR 0073 — the temporal overlay.** Marketplace delivery ships as numbered OKF overlays 01–06, in order, each done when its acceptance list holds, not when its code merges.

Both are: **a thin, disposable, acceptance-gated layer that consumes a pinned substrate and cannot contaminate it.** One layers in build space, the other in time. In 3X terms both are the same move — *give Explore somewhere to happen that Extract cannot feel.*

ADR 0073's ordering rule is 3X sequencing inside a single layer:

> *"The matcher (05) does not start before 01, 02, and 04 hold. Fit ranking over unverified offers or without vouches and reviews to weight is the exact failure this order exists to prevent."*

A matcher is an Extract artifact — optimization over a solution space you already understand. Built first, it is Extract discipline applied to an Explore problem: expensive, precise, and ranking nothing. The numbered order is a rule against premature Extract, written before the frame had a name for it.

---

## The diagram, redrawn

Beck's green curve is what happens **inside any one layer**: features up, futures down. That is not defeatable. The stack does not defeat it — it *relocates* it.

```
FUTURES
  │
  │   ╭───────────────────────────────╮
  │   │  grammar/ + pinned upstreams  │   ← futures held; feature count ~flat
  │   ╰───────────────────────────────╯      (the red curve, at system scale)
  │            ▲   rung 3–4  · GPU-days, re-signature
  │            │   promotion = rung climb (F2/F3: evidence first)
  │            │   descent  = F6, priced cascade
  │      runtimes/ + gems/                ← futures spent deliberately, in ADRs
  │            ▲   rung 2 · days, cross-team
  │            │
  │        overlays  ●──●──●──●──●        ← green curve, run hard on purpose:
  │            rung 0–1 · minutes/hours      features bought with futures
  └──────────────────────────────────── FEATURES
       nobody intends to keep               (= released slices, and only that)

   crystallization ↗  the one move that goes right AND up:
                      delete the rung instead of climbing it
```

The system-level red curve exists only because the boundary stops overlay feature work from reaching substrate futures. Remove the boundary and the whole picture collapses onto one green curve.

**And it is not free.** ADR 0063 prints the bill:

> *"The base image becomes an interface. Anything the overlay relies on … is now a contract with a consumer, and changing it can break an overlay that this repo cannot see. That is the real cost of this decision."*

So the honest statement of the frame: **you do not escape the futures/features tradeoff — you move it to a seam where it has a price tag.** The price tags are the pins: base image `sha-<commit>` with no `:latest` (*"a mutable tag is not a pin"*), Bundler `glob:` at a SHA, `FLOOR.json` / `FLOOR-FRONT.json`. Every pin is a futures spend made legible and deferrable.

---

## Perch: the futures axis, priced

Everything above says futures should be spent deliberately and named. Perch v2 is the part that makes that operational — and it lands almost exactly on Beck's y-axis.

### The freeze ladder is the futures axis

A freeze is a commitment that removes options. The rung *is* the price.

| Rung | Decision surface | Reversal cost | Who bears it | Layer | Phase |
|---|---|---|---|---|---|
| 0 | docstrings, context blocks, strategy choice, workflow bodies | minutes | building team | overlay | Explore |
| 1 | method signatures, return/argument types | hours; ripples to siblings | team + sibling slices | overlay | Explore→Expand |
| 2 | DataModeling entity version; production model *binding* | days; cross-team process | DataModeling team, consumers | gems / runtimes | Expand |
| 3 | distilled model route (dataset + training + eval) | GPU-days, data rebuild | Fledge / ML team | substrate | Expand→Extract |
| 4 | signed effect envelope | re-signature by humans in other units | responsible humans | grammar / governance | Extract |

**The rung and the layer are the same ordinal.** Reversal cost rises as you climb, and it rises for exactly the reason the tier tax rises: the higher you go, the more people's futures you are spending and the fewer of them are in the room. Climbing a rung *is* promotion, seen from the cost side.

### F1–F6 are the 3X phase rules, restated as cost rules

| Rule | Says | In 3X |
|---|---|---|
| **F1** provisional below the validation line | in discovery everything stays at rungs 0–1 | **Explore is a futures constraint, not an attitude.** "Move fast" means *spend only what reverses in hours* — not "skip the tests" |
| **F2** rung 2 requires the whole | climb only after end-to-end rehearsal (≥5/5) and the owner confirms the signal is observable | Expand starts when the thing survives, not when it compiles |
| **F3** rung 3 requires production evidence | 30 days of outward-signal data, no open orphan over its types. *"Distilling earlier is an orphaned commitment made on a guess."* | **No Extract commitment without Expand evidence** |
| **F4** rung 4 only for the release candidate | envelopes signed for a slice ready to release, never methods in isolation | Extract applies to wholes; per-component Extract is premature by definition |
| **F5** cascading invalidation, priced before acceptance | a change at rung *j* shows the reversal cost for everything above it first. *"The change can still be made; it is just never a surprise."* | **The futures axis, drawn before you move along it** |
| **F6** descending is allowed | if evidence shows a frozen decision is wrong, move it down a rung; the cascade applies | **Futures can be repurchased** — Beck's diagram has no arrow for this; Tidy First is this move |

F5 is the whole diagram as a runtime behavior. Beck draws the tradeoff after the fact; F5 shows it to the author *at the moment of the climb*, which is the only moment the choice is still free. F1 is the answer to the most common misuse of 3X — Explore is licensed to spend futures because in an overlay they are worth little, not because speed excuses cost.

### Two costs, named apart — and why the frame needed this

Perch refuses to store a `reversal_cost_estimate`. It stores two different objects:

| | What it is | Where it lives |
|---|---|---|
| `cost_shown_at_climb` | a **record** of what the climber was shown when they accepted. Never recomputed, never corrected. Write-once, by `Freeze.climb!` only. | column on `perch_freezes` |
| current cascade cost | a **fact about now**, computed over `perch_freeze_edges` when someone proposes a change | no column — `price_now` is a query |

*"Storing one and calling it the other is how F5 turns into a memo."*

This is the distinction the futures ledger below needs and did not have a name for: an ADR's `unenforced_because` is `cost_shown_at_climb` — evidence about a past decision, immutable for the same reason a dated measurement is never rewritten. The live gate state is `price_now`. Conflating them is how a decision record stops describing the system and nobody notices.

### The orphan ledger is a managed futures liability

A freeze you make affects work you don't own. The orphan ledger is where that lands: priced, linked, `rank_together`, converged, **released together**. P3 is the rule — *orphaning is a price payable only if the liability is written down and managed.*

Stage 4's own build note is the sharpest statement of why a ledger alone is insufficient: an entry could be *"open while discharging none of its obligations — the unmanaged liability wearing a ledger entry, which is worse than no entry because it reads as handled."* Seven obligations are now enforced on any open entry and reported as a list, not a judgement.

Convergence dates are **derived from the parties' p85 cycle times and never stored** — same reason as `cost_shown_at_climb` vs `price_now`: *"a stored offset is a plan that quietly stopped describing the work."* And closing keeps *which* of the two ways it closed, because a delivered dependency and an abandoned one mean opposite things about the cut.

`§11.1`'s **boundary to question** is a distinct kind, deliberately exempt from the scheduling obligations — *"managing it harder is the wrong response to a boundary running through the middle of one purpose."* That is the frame's own escape hatch, stated from inside: when the liability keeps recurring, the answer is to move the boundary, not to service the debt better.

### Throughput is the features axis, and the wrong count is made unavailable

> *"Throughput is **released slices per level per period, and only that**. Methods promoted, models distilled, classes compiled, envelopes signed, and crystallizations are tracked as work, never as throughput."*

That is the two axes as a metric. **Released slices are features. Everything else on that list is futures being spent.** Counting the second as the first is how a team on the green curve reports as though it were on the red one.

And it is a schema requirement, not a reporting convention: *"If the method table carries a `released` boolean, something will eventually `SUM` it."* `perch_methods` has a `rung` and a `mode` and **no delivery flag, by construction**.

### A third instrument: refusal by missing affordance

The frame had two ways to price a futures spend. Perch adds a third that does not price it at all.

| Instrument | Prices | Example |
|---|---|---|
| **Pin** | a *spatial* boundary — layer ↔ layer | base image `sha-<commit>`, Bundler `glob:` at a SHA, `FLOOR.json` |
| **Freeze rung** | a *temporal* commitment — now ↔ later | rungs 0–4, `cost_shown_at_climb`, F5 cascade |
| **Refusal** | nothing — it makes the spend **unavailable** | R1–R4: no executor column, no ledger, no `jws`, no `rank` |

Perch's four refusals work by absence, and the design says why that is stronger than a rule:

- *"The column is the affordance."* No `position` / `priority` / `rank` — so Perch cannot start ranking, and P2's one exception cannot become the rule.
- *"The thing you may not mint is the thing you have no minter for."* T1 holds because vv-perch ships no migration that creates an actor and no code path that inserts one — *"T1 enforced by the absence of a writer, which is stronger than a validation."*
- `released_at` is writable in exactly one place (`ReleaseGroup#release!`), because if a slice could stamp itself, *"an early member gets stamped and the group invariant is gone — quietly, and in the direction that flatters the number."*

**Rule for choosing:** pin or price when the spend is legitimate and someone should choose whether to make it. Refuse when the spend would be self-concealing, or would create a second home for an authority that must have one — a second credential store (R1), a second ledger claiming the same truth (R2), a count that flatters (the delivery boolean).

Refusal is strictly stronger and strictly less flexible. It is the only instrument that survives an author who is in a hurry.

*(A fourth instrument — for spends that cannot be reversed at all, where pricing is meaningless and refusing forfeits the capability — arrives with Orinth below.)*

### The outward signal is 3X's missing phase-transition test

Beck's model says each phase demands different practices. It does not say how you know you have moved. Perch answers:

> *A slice is **done** when it is released and its outward signal is instrumented and reporting.* Done is computed from three columns, and is not a column.

With three closed states and a hard rule that a `NULL` is not a failure:

| State | Means |
|---|---|
| `not_instrumented` | no signal definition reaches a source |
| `pending` | instrumented; the declared delay has not elapsed |
| `reporting` | matured — `matured_at` is set, written by the computation, not hand-stamped |

*"A pending outward signal is not a failing one … the wrong reading kills a released slice during its own delay window."* And only **outward** readings can close it — stage 2's build note records the bug where a matured inward verdict (a test pass) finished a slice, *"§12.1 inverted by a missing `WHERE`."*

That is the transition detector the raw 3X model lacks. **Explore does not end when the team feels confident; it ends when the receiver's aim is observed to have been met, outward, after a declared delay.** Inward signals — tests green, evals passing, escalation rate — measure work, and work is the futures axis. Exiting a phase on inward evidence is the same error as counting distillations as throughput.

---

## Orinth: the evidence ladder, and what you do with what cannot be undone

Perch prices commitments. Orinth answers the question one layer beneath that: **what earns a commitment the right to be made.** It is the learning loop — five envelopes, GRPO on a MIND policy, dev→prod distillation — and it runs over the medallion tiers, which turn out to be a second ladder at right angles to the first.

### Two ladders, different axes

| | Asks | Ranges over | Direction of cost |
|---|---|---|---|
| **Freeze rung** (Perch §6) | *how expensive is this to reverse?* | 0 → 4 | climbing spends futures |
| **Medallion tier** (Orinth / medallion memory) | *how much do we know this is true?* | Bronze → Silver → Gold | climbing spends **work**, and earns standing |

Bronze is **observed** — a trajectory, a cell, a run, kept verbatim. Silver is a **typed, timestamped fact about** Bronze — a verdict, human feedback, teacher logprobs. Gold is **contracted** — a dataset version with a SemanticModel and a freshness claim.

The two ladders combine into the rule the frame was missing:

> **Evidence tier gates rung climb. You may not freeze above what your evidence supports.**

Perch's F2 and F3 are this rule in specific form — rung 2 needs end-to-end rehearsal, rung 3 needs 30 days of outward-signal data — and the medallion says why: rehearsal produces Silver, and a distillation route is a Gold-tier commitment. Climbing on Bronze is *"an orphaned commitment made on a guess."* Both plans arrive at it independently, which is the usual sign it is load-bearing.

### Platinum has no tombstone — the fourth instrument

The sharpest futures statement in the corpus is one line:

> *"Platinum has no tombstone. Weights cannot be un-trained."*

A trained model is a freeze with **no F6**. You cannot descend a rung you cannot reverse, and pricing the cascade does not help when the cascade cannot be run. Neither of the frame's first three instruments applies: you cannot pin it, the rung price is infinite, and refusing it outright forfeits the capability.

The answer is a move the frame did not have:

> *Distillation is `Purpose::OPERATE`, distilled **from Silver**, always rebuildable, dropped and rebuilt rather than patched in place, and never cited as Gold.*

**When a thing cannot be un-made, refuse it authority and make it disposable.** Weights are not a fourth Build tier; they are ephemeral inference state (ADR 0057) that MIND may reload. Nothing cites them as truth, so nothing has to be reversed when they are wrong — they are dropped and rebuilt from Silver and Bronze, which *are* reversible. The irreversibility is quarantined rather than priced.

That completes the instrument set:

| Instrument | Move | Use when |
|---|---|---|
| **Pin** | price a spatial boundary | the spend crosses a layer |
| **Freeze rung** | price a temporal commitment | the spend is legitimate and someone should choose |
| **Refusal** | make the spend unavailable | the spend is self-concealing, or would create a second home for one authority |
| **Operate** | strip authority, keep rebuildability | **the spend cannot be reversed at all** |

`plan_ornith.md` applies it to GRPO without hesitation: the policy checkpoint is *"not BACK AR, not Gold"*, it *"must not write `procedure.promote`"*, and a weight file *"is dropped and rebuilt from Silver/Bronze, never patched in place, and never cited as Gold."*

### Approval is a freeze bound to the hashes it was signed against

The cross-product of Perch and Orinth is the property both call the important one:

> *"A distilled model does not inherit the approval given to its teacher."*

A signed envelope binds to the use-case text, the class, the effects library version, the data model, **and the model binding of every method that can reach the effect**. Swap the student and the signature invalidates; the responsible human re-signs with the new eval report in front of them. Perch stage 5 built exactly this — `EffectBinding` records what it was approved against, `drift` compares it to live state, and the refusals are named `approval_not_inherited` and `envelope_invalidated`.

Generalized, it is F5's cascade turned into an authorization property, and it states the rule for every phase transition in an AI system:

> **Performance is not authority.** *"Promotion is not an eval score clearing a bar. The eval report is evidence put in front of a person who signs."*

This is the same shape as the outward signal: **the metric is input to a decision, never the decision.** `plan_ornith.md` names the failure it prevents — *"auto-promote because GRPO loss dropped"* — and OrinthDistill states the version that matters most: Fledge *"can ship a better student on every metric, and the envelope still stops it from silently acquiring authority a human granted to a different model."*

### Crystallization returns futures — the only free move in the frame

The best futures/features sentence in the corpus:

> *"Crystallization is a better outcome than a better student. A distilled SLM is cheaper than a teacher; a deterministic body is cheaper than both and cannot drift."*

An `agent` method whose outputs have become predictable (≥99% held-out agreement over ≥2,000 calls) is replaced by a deterministic body — readable code, reviewed as a diff, never auto-merged. A crystallized method *"needs no model, no eval gate, and no envelope tied to a model version."*

Read that against the ladder: **crystallization moves right through the Xs while moving *down* the freeze ladder.** It deletes the rung-3 route and the rung-4 envelope rather than climbing them. The ordinary Extract move is to optimize the expensive thing (distill: GPU-days, rung 3). The better Extract move is to make the expensive thing unnecessary.

This is the one move that adds a feature and **gives futures back.** Beck's diagram has no arrow for it either; it is what Tidy First is for, arriving here at method granularity. Where a phase transition looks like it needs a climb, the first question is whether it needs the rung at all.

### Stored is not admitted — the frame's most repeated failure

OrinthDistill names the trap in its own loop: a NOOA cell that reaches MIND's SQLite has been *stored*, not *admitted*. Counting stored cells as successful trajectories *"would train a student on everything the LLM ever wrote, weighted equally — which is the confident-junior problem with a dataset attached."*

That is inward evidence wearing an outward signal's clothes, and it is now the third sighting:

| Where | The collapse |
|---|---|
| Perch stage 2 | a matured **inward** verdict (a test pass) closed a slice — *"§12.1 inverted by a missing `WHERE`"* |
| OrinthDistill D2 | a **stored** cell read as a passing trajectory |
| The throughput rule | **work** (distillations, signatures, promotions) counted as released slices |
| Context compaction | a **summary the agent wrote** read as the record it replaced |

One error, three costumes: **something the system did to itself, counted as something the world told it.** It is the frame's dominant failure mode, and it always flatters.

Its twin is the third-state collapse, which the platform refuses in four places at once — Perch's `pending` ≠ failing, Orinth's *"held is not zero"* (`H_human` unknown is held, not 0), the ledger's *absent is not zero*, and vv-code-search's `not_indexed` ≠ `unreachable` ≠ `absent`. Collapsing a third state into zero is a futures spend: it destroys exactly the information you would need to reverse the decision, and it is cheap to keep and expensive to recover.

### Follow the capability, not the topology

OrinthDistill is a 🟡 FOLLOW-tier decision made in full. Fledge — a good design, for a different substrate — wants Kafka, an Iceberg lake and an S3 CAS. The answer is no, and the reasoning is the tier rule:

> *"This platform already has a broker, a durable record, and a content-addressed store — and adding Fledge's three would mean four databases and two answers to 'what happened'."*

NATS, the journal, `vv-blob`. And the closing clause is the general rule:

> *"If throughput ever demands a broker Kafka-shaped, that is an ADR, not a consequence of wanting a dataset."*

**An upstream's architecture is not an upstream's capability.** You follow what it can do; you do not import its topology, because the topology is *its* accumulated futures spend, made under constraints that are not yours. Same shape as owner call O3 refusing the NOOA fork, and the same shape as ADR 0063 keeping application UI out of `gems/`. Content-blindness survives the loop for the same reason: ADR 0019's *"the clue is a header"* holds even in the cascade router, and the escalation record — which does carry content — is a Bronze episode written by MIND, never a routing input.

---

## Smart context — the frame is what you load

Everything above is about building. This section is about *who reads it*, and it
changes what the frame is for.

### The window is not the budget

> *"It doesn't matter how big the context window is. The smart part is still
> around 100K."*

Attention is U-shaped: sharp at the start, sharp at the end, and the middle is
where good information goes to be politely ignored. The number on the box grows;
the smart zone does not. **A bigger window is a bigger dumb zone.**

And what the dumb zone destroys is specific. Not facts — constraints:

> *"The summary papered over half the constraints. The model now confidently
> violates rules it never saw the originals of."*

That sentence names the failure exactly. A constraint that was stated once, in
turn one, and then compacted, is now **absent** — and absent reads as permitted.

### So the question is not how to fit the codebase in

It is: *what has the highest constraint density per token?* Source code is a poor
answer — it states what the system does, and almost never what it may not do.
The decisions are the answer.

**An architecture decision record is a constraint with a name, a path, a gate,
and a citation.** It is the densest form the negative half of knowledge takes.
Seventy-three of them, as concepts, is roughly forty-five thousand tokens — an
entire substrate's constraint set, inside the smart zone, with room left to work.
The codebase does not fit and would not help if it did.

Retrieval is structural, not semantic. `paths:` answers *which decisions govern
the file I am editing*; `enforced_by:` answers *what will catch me*. No
embedding, no relevance score — a prefix match and an ordering by specificity,
which is why the same question twice returns the same answer.

**ADR 0014 is the smart-context thesis, written before the article.** Its
decision is one word:

> *"Decisions are **STATE**: the file is what an agent reads."*

Not documentation. State. The file system is the memory; that ADR already said
so, and everything in `docs/` is the consequence.

### Compaction is `bronze_mutated` applied to a conversation

The corpus already refuses this, for traces, in the strongest terms it has:

> *"Summarising on ingest is refused. A curated trajectory is a new **inferred**
> episode with a generation counter, not a replacement for the turns that were
> observed."*

Compaction does precisely the forbidden thing: it replaces the observed turns
with an inferred summary **and keeps the name**. The result is read as the record
because it sits where the record sat. It is failure mode 5 in its purest form —
something the system did to itself, counted as something it was told — and the
information it destroys is the constraint that would have stopped the next move.

So: **a summary is Bronze that has been mutated, and it should carry a generation
counter or not exist.** A frame served to an agent is served verbatim or by
named section, and a budget that cannot fit a section drops it *by name*. Silent
truncation and compaction are the same defect at different scales.

### The reset is the operate instrument, applied to context

Weights have no tombstone, so the answer was: strip their authority, make them
disposable, rebuild from Silver, never cite them as Gold.

**A conversation has no tombstone either.** You cannot un-say a bad summary back
out of a model's attention; the tokens are still there and still being attended
to. Pricing does not help and refusing forfeits the work. That is the exact
signature of the fourth instrument, and it gets the same answer:

> The conversation is **Operate**. Disposable, rebuildable from the file system,
> and never cited as truth.

The ralph loop — verifiable goal, let it work, blow away the context, let it work
again — is not a prompting trick. It is the operate instrument applied to
context, and ADR 0057's three kinds of state already has the slot for it.

### Context is the fifth currency

It behaves more like futures than like anything else on the board: it burns down
as the session runs, it does not come back within the session, and the burn is
invisible until something breaks. What the frame adds is the same discipline the
other currencies get — **a fresh load is a rebuild, not a repair**, and the thing
you rebuild from has to be on disk, addressable, and small enough to fit in the
sharp part of the window.

That is what the bundle is for.

---

## Trajectory — the shared object

Four parties have to be on the same path: **development-time agents** writing the
code, **production-time agents** running inside the pod, **developers**, and
**users**. No two of them share a context window. What they can share is a file.

A **trajectory** is what survives a context reset *and* crosses party lines. It
has three parts, one from each source in this frame:

| Part | From | Answers |
|---|---|---|
| **Aim + receiver** | the Perch slice | who this is for, and what *done* means outward |
| **Constraints + gates** | the ADR tree | what I may not do, and what will catch me |
| **Placement** | the frame | where this sits, what it costs, what licenses it |

### The ADR tree is the constraint half

It is what guides a development-time agent writing code: path → governing
decisions → gates. This is **negative knowledge** — what not to do — and it has
two properties that make it the right thing to load. It cannot be derived by
reading the code, because the code is the residue of the decision and not the
decision. And it is the half that compaction destroys first.

A tree, not a list: decisions supersede and amend one another, and the
superseding edge is part of the constraint. Reading 0011 without 0032 is reading
a rule without its gate; reading 0003 without 0035 is reading a settled decision
that was explicitly un-settled.

### The slice is the orientation half

Perch's T1 is the load-bearing rule here: **the receiver predates the cut.** It
may not be the building team, the tooling, or another slice of the same use case.

For development-time work, the receiver is **the developer**. And the developer's
own slice has a receiver too — the stakeholder. So orientation is transitive:

```
  development-time agent
        └── receiver: the developer            (aim: this slice, done when released + reporting)
                 └── receiver: the stakeholder (aim: their slice, measured outward)
```

Each link is a slice with its own aim and its own outward signal, and the chain
terminates at someone who is not part of the system. That is what stops an agent
from optimizing for the harness: T1 forbids the receiver being anything the cut
created, which at every level means the aim comes from outside.

### Why both halves, and why neither alone

- **Constraints without an aim** produce a compliant agent that builds the wrong
  thing correctly. Every gate green, nothing anyone wanted.
- **An aim without constraints** produces a fast agent that breaks the substrate
  on the way — the ordinary failure of an eager contributor, at machine speed.

The ADR tree cannot say who the work is for. The slice cannot say what you may
not do. A trajectory is both, plus the placement that says what the step costs.

### Production-time agents read the same object

This is the part worth stating plainly, because it is the reason the trajectory
is one object and not two.

A production-time agent's constraints are **the same decisions** — content-blind
routing, sole writers of domain state, the journal as the only admission truth.
Its aim is **the same slice's outward signal**. A development-time agent writing
admission code and a production-time agent performing admission are reading one
record, which is why a decision taken at design time is legible to the thing
doing the work at runtime.

Users are the far end of the chain and never read it. Their half is the outward
signal — **the only part of the trajectory that is measured on them rather than
declared to them.**

### The requirement, in one line

A trajectory must be **loadable in one pass and re-loadable after a reset**. That
is the whole specification. It is why the bundle is markdown with frontmatter
rather than a database, why retrieval is a path prefix rather than a query, and
why nothing in the reader summarizes: the thing you reload after a reset has to
be the thing itself.

---

## The futures ledger already exists

The stack has an instrument for recording futures debt; it just wasn't called that. ADR frontmatter carries `enforced_by`, `unenforced: true`, `unenforced_because`, and — in 0073 — a **"Chain break, declared"** section:

> *"no automated gate refuses an out-of-order merge … until then the break is here, named, not silent."*

That is a futures liability, booked. An unenforced ADR is a decision whose optionality is being carried on credit: the constraint is stated, the gate that would preserve it is absent, and the difference is the debt. Under this frame, `unenforced_because` is the ledger line and `enforced_by` is the paid entry.

Useful consequence: **the ratio of enforced to declared-broken chains is a futures gauge for the substrate.** Rising declared breaks means the substrate is quietly drifting from Extract back into Expand — which may be fine, but should be a decision rather than a drift.

What the ADR ledger still lacks, and Perch has, is a **price at the moment of the decision**. `unenforced_because` records that a spend happened; F5 shows the author what it will cost *before* they accept. The ADR frontmatter is `cost_shown_at_climb` without a `price_now` — a record with no live query beside it. Closing that would mean a cascade view over the ADR chain: propose a change to a decision, and see which downstream decisions and gates it invalidates, before the edit. `perch_freeze_edges` is the shape of the thing that would do it.

---

## Five failure modes the frame names

The first four are layer/phase mismatches; three of those are visible in the repo today. The fifth is an evidence collapse, and it is the one that recurs.

**1. Premature Extract — Extract discipline applied to Explore work.**
ADR 0063's amendment is the textbook case: six application shapes authored into `shapes-application/` failed **seven** substrate gates at once. Every gate was correct. Satisfying them would have meant the substrate enumerating its consumers in five manifests — *"the thing this ADR exists to prevent, arriving by the back door as bookkeeping."* Moving the shapes into the application repo cleared six of seven with no other change.
**Rule: when a gate fires on Explore work, move the work, not the gate.**

**2. Explore leaking into the substrate — the mirror.**
An experiment that needs "just one" grammar change. That is a feature bought directly with substrate futures, and it is the single most expensive purchase available in this architecture. ADR 0063 also rules out its structural form: the application becoming BACK and inheriting the substrate schema wholesale — *"co-tenancy by another name."*

**3. Extract without Expand — declared floors standing in for evidence.**
The README on FRONT:

> *"FRONT is **swapped but unproven end to end** … Nothing yet proves the wired FRONT reaches a live BACK on the pod network, so 'FRONT serves the pod' is still a claim ahead of the deployment."*

Pins, floors and declared contracts are Extract artifacts. Produced before the Expand phase generated evidence, they document a claim rather than preserve a fact. The README's own hedge is the frame working correctly — the claim is flagged, not asserted.

**4. Mixed-phase tier — one directory, three phases.**
`gems/` is a single 🟢 OWN IT tier governed by one rule (derivative of `grammar/`, path gem, in `bin/load-all`, suite under `bin/spec-all`). But its contents are at visibly different maturities: `vv-graph` (*"the largest suite in the tree"*) is Extract; `vv-figma` / `vv-miro` / `vv-cal-com` are Expand-shaped boundary work; `vv-orinth` is *"v2 Ornith envelopes + GRPO; blocked on v1"*.

`vv-orinth` looks like the mismatch, and reading the gem shows it is the opposite — **it is the frame's third legal answer, and the one neither Perch nor the ADRs demonstrate.** Envelopes are rung 4 and distillation routes are rung 3, so F3 should forbid the gem entirely. Instead the gem ships as *"🟡 CONTRACT ONLY — v2, blocked"* and refuses itself in code: `V1Binding.bind!` will not bind until ProcedureRepo and SelfLearn plants are green, and — the load-bearing clause — *"loading those gems is not a plant."* The README states its own non-capabilities first: *"Does not train. Does not promote Gold."*

So the pattern is: **ship the contract, wire the refusal, let the evidence unblock it.** The gem occupies its substrate slot and cannot act from it. That is a legitimate and underused answer to "what do you do with Explore-shaped work that must eventually be substrate" — it is neither a fork of the substrate's discipline nor a pile of components waiting on each other. It is a declared forward commitment whose own gate holds it at rung 0.

What makes it work rather than a memo is the last line of OrinthDistill's gate list: *"Zero jobs is a fail. A checker that has never been planted is not a gate."* A refusal that has never been proven to fire is a comment. `V1Binding` is the frame's cheapest instrument correctly installed — the gem's futures are held by its own refusal, not by anyone remembering.

**The other legal answer is staged wholes, and `vv-perch` is the worked example.** §15 refuses to build Perch component-by-component — *"it would produce exactly the fragment-heavy flow the design argues against"* — so the plan takes the same medicine: **five stages, each "a whole for a receiver that predates it."** Stage 1's receiver is whoever writes a use case; stage 3's is whoever is about to freeze something; stage 4's is two teams sharing one decision. Each stage is acceptance-shaped and ships, in order, with its gate rules and plants. That is ADR 0073's numbered-overlay procedure applied *inside* a substrate gem.

So the answer to the mismatch is not an incubation flag. It is: **Explore inside the substrate is legal when it ships as staged wholes with named receivers, and illegal when it ships as components waiting on each other.** `vv-orinth` is the second shape; `vv-perch` is the first. The substrate tax is payable per stage because each stage delivered something.

The build notes make this vivid — each stage found the prior stage's tables present but hollow: stage 2, *"`pending` meant nobody stamped a column rather than the window has not closed"*; stage 3, *"`cost_shown_at_climb` and `climbed_at` had no writer at all — columns only specs filled in"*; stage 4, *"the unmanaged liability wearing a ledger entry"*; stage 5, *"until now it was the memo."* Schema without a writer is a component, not a whole. The staging is what kept finding it.

**5. Inward evidence counted as outward — the recurring one.**
Detailed under Orinth and Smart context above. A test pass closing a slice, a stored NOOA cell reading as a passing trajectory, a distillation counted as throughput, **a compaction summary read as the record it replaced**: **something the system did to itself, counted as something the world told it.** Unlike the first four, this one is not about where work lives — it can occur in any layer, at any phase, and it always moves the number in the flattering direction. Its twin is the third-state collapse (`pending` → failing, held → 0, absent → 0), which destroys the information needed to reverse the decision.
**Rule: before trusting any signal, ask who produced it. If the answer is us, it is work, not throughput.**

---

## Movement: promotion, and the priced descent

Work travels **up the layers as it travels right through the Xs**, and every step has a rung price. That diagonal is the frame's operating rule.

```
Explore ─────────────► Expand ─────────────► Extract
overlay              gems / runtimes         grammar
(disposable)         (derivative, pinned)    (closed, conformance-gated)
```

- **Promotion is a rung climb.** Earned, not requested, and the entry toll rises with the layer exactly as reversal cost rises with the rung: an overlay needs an acceptance list; a gem needs a path-gem home, a suite and a `Gemfile` entry; `grammar/` needs closed SHACL, a profile, and conformance tests. F2 and F3 state the general form — **you may not climb on inward evidence.**
- **Demotion exists, and it is priced.** *Corrected by F6:* if evidence shows a frozen decision is wrong, the owner moves it down a rung and the cascade applies. Substrate that stops earning is not stuck. What is forbidden is the *unpriced* descent — quietly relaxing a gate, which converts held futures into nobody's features while the ledger still reads as paid. A descent that prices its cascade and names who bears it is a futures repurchase, and it is the healthiest move in the frame.
- **Deletion of the rung beats the climb.** A third kind of movement, and the only one that adds a feature while *returning* futures: crystallize the method, pin the dependency, make the expensive step unnecessary rather than affordable. Perch and Orinth both reach for it — a crystallized body *"needs no model, no eval gate, and no envelope tied to a model version."* It is the move to look for before every promotion.
- **Fast paths are illegal by construction.** ADR 0063 point 3 and ADR 0038's `glob:` at a SHA mean the overlay can only see the substrate through a pin. There is no route from Explore straight into `grammar/`.
- **`upstreams/` is outside the diagonal.** It is *"pinned, never forked,"* reached only through `gems/adapters/`. You buy their Extract without running your own. Perch tried to argue otherwise — perchv2 §0.1 says *"pin a commit and plan to maintain a fork"* — and owner call **O3** overruled it: *"the pin wins; the fork is refused."* A production binding names a route, never a path into a checkout. That is the frame resolving a direct conflict between a design doc and a tier rule, in the tier rule's favor, and encoding the answer as `Doctrine::NOOA_FORK_REFUSED` rather than leaving it remembered.

---

## The operational test

For any unit of work, eight questions. They take about a minute and they resolve most "where does this go" arguments before they start.

1. **Which layer does it change?** Read the path. `grammar/` · `gems/`+`runtimes/` · overlay repo · `upstreams/`.
2. **Which X is the work actually in?** Do we not yet know what the user wants (Explore) · is something about to break under load (Expand) · is the problem fully understood and now about economics (Extract)?
3. **Do 1 and 2 match the merge table?** If not, the default fix is to **move the work, not the gate** — ADR 0063's amendment is the precedent.
4. **Which rung does it freeze, and who bears the reversal?** If the answer is a rung above the layer's home, you are climbing early. F5: the cascade gets priced and shown before acceptance, not discovered after.
5. **What tier is the evidence — Bronze, Silver, or Gold?** You may not freeze above what the evidence supports. Bronze justifies rung 0–1; a rung-3 route wants Gold.
6. **Which instrument names the spend — pin, rung, refusal, or Operate?** A pin for a boundary, a rung for a commitment, a refusal for what must not be available, Operate for what cannot be undone. Unnamed futures spending is the only thing this frame actually forbids.
7. **Is there an outward signal, and is it instrumented?** If nothing outward will report, this work cannot end a phase — it can only accumulate. And check who produced the signal: inward green is work, not throughput.
8. **Could the rung be deleted instead of climbed?** Crystallization, a pin, a deterministic body — the move that removes the commitment beats the move that affords it. Ask before every climb, because it is the only step that gives futures back.
9. **Which decisions govern the path you are about to edit, and which gates will catch you?** If you cannot name them, you are working from the code, which does not carry the constraints.
10. **Who is the receiver, and is the chain to a stakeholder unbroken?** A receiver the cut created is not a receiver. If the aim ends inside the system, the work is optimizing the harness.

---

## What the frame is for

Beck's 3X says *when*. Futures/features says *what it costs*. The stack's tiers say *where*. Perch says *how much, borne by whom, and what you may not build at all*. Orinth says *what earns the right to spend, and what to do with a spend that cannot be taken back*. The smart zone says *who reads all of it, and how little of it fits*. Alone, each loses an argument it shouldn't:

- 3X alone → "we're in Explore, so skip the tests" applied to `grammar/`.
- Futures/features alone → the tradeoff looks unbeatable, so you either over-engineer everything or nothing.
- Tiers alone → the boundary reads as bureaucracy, because nothing explains why the tax differs by directory.
- Perch alone → fifteen tables and eight wholeness tests read as process, because nothing says which curve they are protecting.
- Orinth alone → medallion tiers read as data hygiene, when Bronze/Silver/Gold is the thing that licenses a freeze.
- Smart zone alone → a prompting tip, when it is really an argument about what a record has to be so that a reader with no memory can pick it up.

Together they say one thing: **the boundary is what makes the red curve purchasable; the phase tells you which side of it you're standing on; the rung tells you what the next step costs and who pays; the tier tells you whether you have earned the step; and the pins, freeze records, refusals and rebuilds are the receipts.**

The frame's one prohibition, in its final form: **no futures may be spent without a price shown to the person spending them, at the moment the choice is still free** — where that price cannot be shown honestly, the affordance is not built; and where the spend cannot be reversed at all, the thing it produces is never allowed to be cited as truth.

And its one preference, which is the whole point of drawing the two curves at once: **the best move is almost never the climb.** Crystallize the method, pin the dependency, delete the rung. A feature that returns futures is the only kind the red curve is actually made of.

What the frame finally is, then, is not a description of how this substrate is built. It is **the trajectory four parties share** — two kinds of agent, the developer, and the user — small enough to load into the sharp part of a window, structured enough to retrieve by path, and durable enough that blowing away a conversation costs nothing.

---

### Sources

- `magentic-market-ai/docs/research/KentBeck3Es.md` — 3X: Explore / Expand / Extract
- `magentic-market-ai/docs/research/KentBeckFutureFeature.png` — futures vs features, the two curves
- `magentic-market-ai/docs/research/SmartDumbContext.md` — smart zone / dumb zone; U-shaped attention; compaction is lossy; the file system is the memory
- `magentic-market-ai/docs/research/perchv2.md` — Perch design v2: freeze ladder §6, orphan ledger §11, outward signals §12, build-as-wholes §15
- `magentic-market-ai/docs/research/Orinth1.md`, `Ornith2.md`, `Ornith3.md`, `ornith15_dev_to_prod_distillation.md` — Ornith-1.0/1.5 and the Fledge distillation design
- `magentic-stack/README.md` — ownership tiers, three grounding constructs, FRONT status
- `magentic-stack/gems/README.md` — the owned package layer, derivative rule, gem inventory
- `magentic-stack/gems/vv-perch/README.md` — schema-only gem, the four refusals, owner calls
- `magentic-stack/gems/vv-orinth/README.md` — contract-only gem, `V1Binding` refuses, "loading those gems is not a plant"
- `magentic-stack/docs/architecture/plan_vv-perch.md` — the contract and the list of things it must refuse to build; five build stages and their notes
- `magentic-stack/docs/architecture/plan_ornith.md` — five envelopes, GRPO on MIND only, the v1/v2 split, non-goals
- `magentic-stack/docs/architecture/OrinthDistill.md` — capture is Bronze, distillation is Operate; envelope binding; crystallization; the Fledge store mapping
- `magentic-stack/docs/adr/0063-application-overlays-consume-the-substrate.md` — spatial overlay, base image as interface, both amendments
- `magentic-stack/docs/adr/0014-adr-as-spec.md` — decisions are state the fleet reads, not documentation
- `magentic-stack/docs/adr/0057-three-kinds-of-state.md` — the slot the disposable conversation goes in
- `magentic-stack/docs/adr/0073-marketplace-overlays-are-the-delivery-surface.md` — temporal overlay, delivery order, declared chain break

### In this repository

- [`docs/`](docs/) — this frame and all 73 decisions as an Open Knowledge Format bundle, cross-linked both ways
- [`vv-frame/`](vv-frame/) — the reader: which decisions govern this path, which gates enforce them, is this placement legal
