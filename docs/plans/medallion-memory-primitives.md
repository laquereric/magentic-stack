# Integrate Three New Memory Primitives into `vv-medallion_memory`

**Saved into this repo 2026-09-15.** Body is verbatim from the source
below; only the two links were changed, because both were relative to
`magentic-market-ai` and would have resolved to nothing here.

| | |
|---|---|
| Source | `~/.grok/sessions/…/01a0a65f-466c-7460-8bf5-6f096f8ee546/plan.md` |
| Authored against | `magentic-market-ai`, in a grok session |
| Status here | **Not independently verified**, per this directory's README. Saved as a record of the decisions, not as a merged commitment. |
| Owner | unclaimed — the "Owner decisions (locked)" table below is the source's own claim, not one this repo can vouch for |

**Phase 1 was in flight when this was saved, and had left the tree red.**
`gems/mmg-medallion/` exists on disk with 53 untracked files and no
`path: "gems/mmg-medallion"` entry in the root `Gemfile`, so
`tooling/boundary/check_closed.py` fails `every-gem-is-built`. The
directory reads as promoted and is not: `git ls-files gems/mmg-medallion`
returns nothing. Anyone picking up phase 1 should land the gem and the
Gemfile entry in one commit — a Gemfile entry pointing at an uncommitted
path breaks a clean checkout, and a gemspec on disk is enough to fail the
gate whether or not it is tracked.

---

Source: `magentic-market-ai/docs/research/ThreeNewMemoryPrimitives.md` (another repo; not linkable from here)
Target gem: `magentic-stack/gems/vv-medallion_memory` (contract today, v0.1.0)
Engine: `mmg-medallion` 0.2.0, to be **promoted** into `magentic-stack/gems/mmg-medallion`
Existing contract: [`docs/architecture/plan_vv_medallion_memory.md`](../architecture/plan_vv_medallion_memory.md)

This is an implementation plan, not a rewrite of the medallion. The four primitives fill holes the original plan named as policy (promotion, temporal validity, serving, deletion) and makes them **structural**.

---

## Owner decisions (locked)

| Question | Decision |
|---|---|
| Slice shape | Contract in `vv-medallion_memory` **and** start engine work in `mmg-medallion` |
| Primitive scope | **All four, fully implemented in-gem** (working merge, cascade, assemble, derivation — not types-only) |
| Silver system of record | **Journal admits; Fact is the Silver projection.** Graph holds resolved topology. Rag embeds only after merge. `tx_from` is engine-stamped from the journal position, never from the client |
| Serving | **Compose:** `assemble()` expands subjects; MeaningActivations weight/filter injection |
| M-home | **Promote `mmg-medallion` into `magentic-stack/gems/`** |
| Engine depth this slice | **M1–M9 in `mmg-medallion`**, implemented autonomously with the four primitives. M10 (confidence-as-stamp) stays pending. S3 Gold model, S6–S8, CPCP `memory.*`, and real Milvus writes stay follow-on |

`memory.distill` stays blocked on `S8-platinum-operate`. M5+M9 landing is not permission to fold facts into weights.

---

## What already exists (do not re-litigate)

`vv-medallion_memory` is the contract half and it is load-bearing:

- Exactly three Build tiers; Platinum / Serving / Working refused **by name**
- Purpose is carried (Build / Consume / Operate are siblings)
- Closed refusal vocabulary, never-raise envelopes
- Six Flows declared; `memory.distill` blocked on M5+M9
- Bronze `Provenance` with `observed|inferred` and `MAX_GENERATION = 3`
- `EngineBinding.bind!` refuses `medallion_home_undecided`
- Spec + `tooling/medallion/check_medallion_memory.py` **assert there is no Conformer / Curator / GraphProjection in this gem**

The research does not reopen Platinum, summarising-on-ingest, or M-home. It sharpens two existing jobs and adds two gates the plan described as policy.

| Primitive | Layer | Relation to existing plan |
|---|---|---|
| 1 Branch-and-merge | Bronze→Silver, Silver→Gold | **New gate.** Replaces unenforced promotion policy. `Promotion` in the engine is the merge receipt, not a direct write |
| 2 Bi-temporal split | Silver | **Sharpens M5.** Plan has one axis (`validFrom`/`validTo`, journal as clock). Research needs two independent axes |
| 3 Budgeted traversal | Gold serving (Consume) | **Sharpens `memory.serve`.** Plan already says budget-capped ContextFrame + MeaningActivations. Traversal is the expansion; activations remain the injection weights |
| 4 Derivation index | Cross-cutting | **Sharpens M9.** Plan has tombstone cascade; research says the walk is a maintained index, not a sweep |

Build order stays the research order, because retrofitting time axes is the painful migration and branch-and-merge only pays off once more than one writer exists — but all four ship in this slice, in that order.

---

## Non-negotiable split (this is how we avoid the fork)

```
  mmg-medallion              GENERIC BUILD ENGINE
                             named graphs, Flow registry, Conformer, Curator
                             M5: Silver triples are append-and-close, two time axes
                             M9: cascade API given a set of IRIs (SPARQL later)
                             does NOT depend on vv-medallion_memory

  vv-medallion_memory        MEMORY PRODUCT
                             Fact, Branch, Assemble, Derivation, Serve
                             in-memory Store that tests run against
                             JournalPort / GraphPort / VectorPort / ActivationsPort
                             MAY depend on mmg-medallion once promoted
                             MUST NOT define Conformer, Curator, or GraphProjection
```

The checker that forbids those three class names in the memory gem **stays**. The primitives are not a private Conformer. They are the memory-shaped jobs the original plan already said belong in this gem (temporal facts, serving blocks, decay/cascade, observed-vs-inferred).

Dependency direction: `vv-medallion_memory` → `mmg-medallion`. Never the other way.

---

## Architecture of the four primitives

### Shared ports (so the in-gem engine is not a second store)

The in-memory implementations are the default and the test surface. Persistence is behind ports so ADR 0052 is expressible without oxigraph/Milvus in this slice.

```
JournalPort     admit(operation_id, payload) -> journal_position
                A write that never journals is not landed.

GraphPort       upsert_edge(branch_id, subject, predicate, object, merged_at)
                neighbors(subject, as_of_tx)   # merged-only unless branch_id given
                drop_branch(branch_id)

VectorPort      embed(subject)                 # ONLY called from merge
                search(cue)                    # merged subjects only

ActivationsPort weight_for(subject_iri)        # -1.0..+1.0 or nil
                nil  = not in the model (absent ≠ zero)
                0.0  = considered, not injected, still inspectable
                > 0  = injected
```

`tx_from` is the journal position returned by `admit`. The Fact / Branch APIs do not accept `tx_from` or `tx_to` as caller arguments. A caller that passes them is `tx_time_client_set`.

### Primitive 2 — `Fact` (first; everything else assumes it)

Append-only. Never `UPDATE` a fact row. Close and write a successor.

```
fact_id, subject_iri, predicate, object_value, object_iri,
valid_from, valid_to,            # world time; valid_to nil = still true
tx_from, tx_to,                  # engine time; tx_to nil = still believed
supersedes_fact_id,              # set on supersession
corrects_fact_id,                # set on correction
evidence_ref, extractor_version, confidence,
branch_id
```

Four queries, named as methods not comments:

| Method | Predicate |
|---|---|
| `Fact.current` | `valid_to` nil AND `tx_to` nil, merged |
| `Fact.true_on(d)` | valid interval contains `d`, at current belief |
| `Fact.believed_on(t)` | tx interval contains `t` |
| `Fact.believed_on_about(t, d)` | both |

Cascade (this is the payoff, and it is why derivation is built immediately after):

- **Supersession** — close `valid_to`, write successor, re-embed the subject. Gold consumers **stale**, not invalidated. Refresh on next consolidation.
- **Correction** — close `tx_to`, write corrected fact, walk derivation, **invalidate** every Gold artefact that consumed the wrong fact, flag `extractor_version`.

Conflict on the same subject: higher `confidence` / evidence, then later `valid_from`. Last-writer-wins is refused.

### Primitive 4 — `Derivation` (cheap while Gold is small)

```
artefact_id, artefact_kind, fact_id, weight, derived_at, derivation_run_id
```

`Derivation.record` on every Gold write. `Derivation.cascade(fact_id, kind:)` is the only forget/correct/supersede walk. Subject-deletion at Bronze calls this rather than scanning the store.

Platinum stays out: a distilled adapter has no derivation rows. `memory.distill` remains blocked.

### Primitive 3 — `Assemble` then activations

```
Assemble.call(cue:, seeds:, node_budget:, token_ceiling:, as_of_tx:, branch_id: nil)
  -> { ok: true, subjects:, tokens:, truncated: }
```

1. **Seed.** Fuse vector ANN + keyword + pinned subjects with Reciprocal Rank Fusion (no score calibration).
2. **Expand.** Priority queue by cost = hop distance + edge-type weight + recency + confidence. Budget is **distinct subjects**, not tokens.
3. **Diversify.** Maximal Marginal Relevance, then serialise until `token_ceiling`.
4. **Inject.** `Serve.call` runs assemble, then drops `weight <= 0` from the injected pack while keeping them on an `inspectable:` list.

`as_of_tx` is required for audit replay. Same seeds + budget + `as_of_tx` → byte-identical context. Halving `node_budget` yields a strict prefix-by-priority of the larger result.

Default cost weights live in the gem and are overridable. No universal setting; the knob is explicit.

MeaningActivations stay in mind-pod. The memory gem talks to them only through `ActivationsPort`. This gem does not take a Rails dependency.

### Primitive 1 — `Branch` (last of the four, still in this slice)

```
branch     (branch_id, parent_branch, agent_id, task_id, created_at,
            status)                 # open | merged | rejected | abandoned
proposal   (proposal_id, branch_id, op, subject_iri, predicate, object,
            valid_from, valid_to, evidence_ref, confidence)
merge_record (merge_id, branch_id, reviewer, decision, decided_at,
              rationale, conflicts_resolved)
```

An agent never writes to canonical Silver/Gold. `Fact.append` without a `branch_id` is `canonical_write_refused`. Reads default to `merged_at IS NOT NULL`. An agent reading its own branch sees main ∪ branch.

Merge sets `merged_at`, flips the branch row, **then** enqueues affected subjects for `VectorPort.embed`. Embed of an unmerged subject is `unmerged_embed`.

Merge policy (blast radius), as data, not a comment:

| Change | Gate |
|---|---|
| New fact, subject unreferenced elsewhere | Auto-merge on schema + policy pass |
| Update that supersedes cleanly | Auto-merge |
| Contradiction | Review |
| Deletion / retraction | Always review |
| High-sensitivity subject | Always review |
| Writer rejection-rate above threshold | Always review |

Rejection rate per `agent_id` is maintained on merge/reject. That is the poisoning detector. Abandoned branches get `Branch.reap(older_than:)`.

Reject must leave **no residue**: no embedding, no dangling graph edge, no fact with `tx_to` nil on that branch.

---

## Engine work in this slice (promoted `mmg-medallion`)

### Promote (M-home)

Copy `magentic-market-ai/gems/mmg-medallion` into `magentic-stack/gems/mmg-medallion` **without** the nested `.git`. `tooling/boundary/check_closed.py` fails a nested git dir and requires every gemspec to name `magentic-stack` as home.

- Add `gem "mmg-medallion", path: "gems/mmg-medallion"` to the stack root `Gemfile`
- Point the gemspec homepage / `source_code_uri` at this repo
- List it in `gems/README.md`
- Do **not** rewrite Conformer/Curator into the memory gem
- Leave the MM nested copy in place; it is gitignored by the parent and becomes stale. Stack is now home. MM later consumes the stack gem the way it consumes other stack gems — not this slice

This is a file promotion, not a history-preserving subtree, unless the operator asks for `git subtree` at commit time.

### M1–M9 in the promoted engine

| # | Land as |
|---|---|
| **M1** | `dry_run: false` writes N-Triples into `GraphProjection` (always) and, when `MM_OXIGRAPH_URL` is set, `INSERT DATA` via `Mmg::Graph::Execute.update` into `urn:mm:medallion/{flow}/{tier}/{revision}`. Tests inject a sink; live oxigraph is not required to go green. CAS pointer stays. |
| **M2** | Replace `pragmatic_shacl_v0` with `mmg_shacl_v1`: named `ShapeSet` of class/property constraints, persisted report on the conform result, `engine: "mmg_shacl_v1"`. Not full W3C SPARQL-SHACL; a blank-line check is no longer the gate. |
| **M3** | `Mmg::Medallion.audit!(proposal)` never-raise. Rejects (a) a fourth Build tier, (b) Bronze that transforms, (c) Silver that only copies, (d) Gold without SemanticModel + Contract + SHACL report + CAS. |
| **M4** | Conformer requires a Bronze provenance envelope (`observed\|inferred`, generation, source digest, session, actor, wall-clock). Derived-as-observed is `bronze_mutated`. |
| **M5** | Silver facts are append-and-close with `validFrom`/`validTo`/`txFrom`/`txTo`. `txFrom` is engine-stamped (journal position or monotonic commit id). Caller-supplied `txFrom` is refused. |
| **M6** | `Curator.promote(..., dry_run: false)` requires a published `SemanticModel` + `Contract`. Optional remains optional on `dry_run: true`. |
| **M7** | `Flow` carries `purpose`. `audit!` rejects a Consume/Operate flow that targets a Build tier. |
| **M8** | `Decay.policy(tier)` binds the slogans: Bronze legal-retention clock, Silver contradiction/supersession, Gold utility. Forget evidence must match the clock. |
| **M9** | `Mmg::Medallion.cascade(iris:, kind:)` walks Silver then Gold (in-process graph; SPARQL delete when the M1 sink is live). Memory-gem `Derivation.cascade` is the index that computes `iris`. |

### `EngineBinding`

Once `mmg-medallion` is loadable from `gems/` and `audit!` exists:

```
EngineBinding.bind!                # auto-selects :stack
EngineBinding.bind!(home: :stack)  # { ok: true, home: :stack, landed: M1..M9, pending: {M10: ...} }
EngineBinding.undecided?           # false
```

`medallion_home_undecided` stays in the vocabulary (`home: :mm_pin` still hits it). Checker: `bind!(home: :stack)` succeeds; M1–M9 listed as landed; M10 still pending.

---

## Memory-gem surface (what lands in `vv-medallion_memory`)

New files, all under `lib/vv/medallion_memory/`:

| File | Role |
|---|---|
| `fact.rb` | Append-only bi-temporal Fact; four queries; refuse client `tx_*` |
| `branch.rb` | Branch / proposal / merge_record; auto vs review policy; reaper |
| `assemble.rb` | RRF seed, cost-ordered expansion, MMR, token serialise |
| `derivation.rb` | artefact↔fact index; invalidate vs stale |
| `serve.rb` | `assemble` then `ActivationsPort` |
| `store.rb` | In-memory Store implementing the four tables + ports |
| `journal_port.rb` | Admit interface; `InMemoryJournal` stamps monotonic positions |
| `vector_port.rb` | Embed-on-merge only; `InMemoryVector` |
| `activations_port.rb` | Weight lookup; `NullActivations` injects all assembled |

Keep existing: `tier.rb`, `purpose.rb`, `provenance.rb`, `flow.rb`, `refusal.rb`, `engine_binding.rb`.

`flow.rb` notes change, names do not. Still six Flows. Branch is a **mechanism inside** `memory.conform` / `memory.curate` / `memory.promote`, not a seventh Flow. `memory.serve` notes: "assemble under node_budget, then MeaningActivations; `as_of_tx` for audit replay."

### New closed refusals

Add to `Refusal::WHEN` (closed set grows on purpose; callers branch on reason):

| reason | when |
|---|---|
| `tx_time_client_set` | caller passed `tx_from` / `tx_to` |
| `canonical_write_refused` | Fact/graph write with no `branch_id` |
| `unmerged_embed` | `VectorPort.embed` on a subject whose `merged_at` is null |
| `as_of_tx_required` | `Assemble.call` used for audit replay without `as_of_tx` (ordinary serve defaults to current tx) |

Existing reasons stay. `rag_write_undecided` still fires if someone tries a real Milvus upsert; in-memory vector is not that ADR.

### Public API (envelope-shaped)

```ruby
Vv::MedallionMemory::Store.new(journal:, graph:, vector:, activations:)

Fact.append(...)          # -> {ok: true, fact_id:, tx_from:} | refusal
Fact.supersede(...)
Fact.correct(...)
Fact.current / true_on / believed_on / believed_on_about

Branch.open(...)
Branch.propose(...)
Branch.merge(...)         # embed happens here
Branch.reject(...)        # residue-free
Branch.reap(...)

Assemble.call(...)
Serve.call(...)           # assemble + activations
Derivation.record(...)
Derivation.cascade(...)
```

`Vv::MedallionMemory.may_land?` stays the Bronze gate. Silver/Gold writes go through Branch.

---

## Tests (the research named these; they are the acceptance)

New specs, not comments:

**`spec/fact_spec.rb`**
- Client `tx_from` is refused; engine stamp is present
- Supersession closes `valid_to`, leaves `tx_to` nil on the old row
- Correction closes `tx_to`, leaves `valid_*` unchanged
- The four queries return the documented sets

**`spec/derivation_spec.rb`** (the independence test)
- Correct a fact that three Gold artefacts consumed → all three **invalidated**
- Supersede a different fact with the same three consumers → none invalidated, all **stale**
- If both cases behave the same, the axes are not independent — fail the spec

**`spec/assemble_spec.rb`**
- Same cue twice → byte-identical `subjects` + serialisation
- Half `node_budget` → strict prefix-by-priority of the larger result
- `as_of_tx` reconstructs a past belief, not current facts

**`spec/branch_spec.rb`**
- Poisoned fact on agent A's branch is invisible to agent B's `Fact.current`, `Assemble`, and `VectorPort.search`
- `Branch.reject` leaves no embedding, no graph edge, no live fact
- Direct canonical write refuses `canonical_write_refused`
- Embed before merge refuses `unmerged_embed`
- Writer with rejection-rate above threshold cannot auto-merge

**`spec/serve_spec.rb`**
- `weight == 0` is listed under `inspectable` and absent from injected pack
- `weight > 0` is injected in assemble order
- Absent activation (`nil`) is not treated as zero

**`spec/medallion_memory_spec.rb`** keeps Platinum, cardinal sin, distill-blocked, no-engine-fork. Binding examples change as above.

**Plants** in `tooling/medallion/plant_medallion_memory.py` grow cases that put back:

- a client-settable `tx_from`
- an embed inside `Fact.append`
- correction and supersession sharing one cascade path
- `EngineBinding.bind!(home: :stack)` refusing after the gem is promoted (the old "naming is not landing" plant becomes "pending M-items vanished")

`check_medallion_memory.py` updates: still forbids Conformer/Curator/GraphProjection in this gem; no longer requires `bind!` to refuse; requires the four new reasons; requires distill still blocked.

---

## Phasing inside the slice (implementation order)

Do not implement branch-and-merge first. The research order is the migration order.

1. **Promote `mmg-medallion`** into stack `gems/`, Gemfile, README. Point `EngineBinding` at `:stack` with a pending list. Specs/checker updated so the blocker is no longer "undecided".
2. **`Fact` + `JournalPort` + in-memory Store.** Four queries. `tx_time_client_set`. Engine Conformer grows append-and-close + two time axes (M5).
3. **`Derivation` + cascade.** Independence test. Engine `cascade` hook (M9). Distill stays blocked.
4. **`Assemble` + `Serve` + `ActivationsPort`.** Determinism + prefix tests. `memory.serve` notes updated.
5. **`Branch` + `VectorPort`.** Poison-isolation and residue-free reject. Embed-on-merge only. Auto vs review policy. Reaper.
6. **Docs + plants.** Update `plan_vv_medallion_memory.md` (M-home named, S0/S2/S4/S5 notes, primitives table). README of the memory gem stops saying "contract only". Version bump `0.1.0` → `0.2.0`.

Each phase is independently spec-green. Phase 1 is a large copy; phases 2–5 are the product.

---

## Out of scope (follow-on, named so they do not sneak in)

- M10 confidence-as-stamp (the one pending item on `EngineBinding`)
- Full W3C SPARQL-SHACL (M2 is `mmg_shacl_v1` class/property constraints)
- `Execute.publish` Entry grounding for medallion graphs (M1 uses `Execute.update` + in-process projection)
- S3 first Gold SemanticModel (persona vs failure-lessons still an open question)
- S6 PySparqlFun, S7 botdataengine overlay, S8 Platinum job
- Real Milvus writes (`rag_write_undecided` still fires)
- `user_id` on MeaningActivations (still undecided there)
- CPCP `memory.*` on BACK / NATS
- LLM extractors, Letta block packing, LoRA
- Host-side BFS loops in application code — `Assemble.call` is the one call

---

## Risks

- **Promotion copy vs two homes.** After copy, MM's nested repo will drift if anyone keeps committing there. Call that out in the plan file and in `EngineBinding` comments. Stack is canonical.
- **In-gem Store looking like an engine fork.** Mitigated by the class-name checker, the dependency arrow, and keeping Conformer/Curator in `mmg-medallion`.
- **Activations live in mind-pod, assemble lives in the gem.** The port is the seam. Do not require Rails in the gem spec.
- **Journal position as `tx_from`.** In-memory journal uses a monotonic integer. A later real journal must keep that type stable (integer position, not wall-clock). Wall-clock is `valid_*` and `observed_at` only.
- **Cost function is the highest-leverage knob** and has no universal setting. Ship defaults plus an override hash; do not pretend the defaults are science.
- **Slice size.** Four working primitives plus a gem promotion is large. The phase list is the brake: stop after any phase and the tree is still coherent.

---

## Docs to edit when implementing

- `magentic-stack/docs/architecture/plan_vv_medallion_memory.md` — M-home answered; primitives table; S2/S4/S5 acceptance lines; EngineBinding behaviour
- `magentic-stack/gems/vv-medallion_memory/README.md` — no longer "contract only"
- `magentic-stack/gems/README.md` — add `mmg-medallion`
- `magentic-stack/Gemfile` — path gem
- Do not edit `docs/research/ThreeNewMemoryPrimitives.md` except optionally a one-line "lands in vv-medallion_memory 0.2 / mmg-medallion (stack)" pointer at the top
