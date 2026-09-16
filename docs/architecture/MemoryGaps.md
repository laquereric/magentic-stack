# Memory gaps

Measured 2026-09-15 against `magentic-stack` and `magentic-market-ai`.
This is an inventory of what the memory product does not yet do, and
where the work that *does* exist actually lives. It is not a plan to
close every row.

Companions: [`plan_vv_medallion_memory.md`](plan_vv_medallion_memory.md)
(product contract, S0–S8, M1–M10),
[`MeaningActivations.md`](MeaningActivations.md) (serving weights),
[`RagContainer.md`](RagContainer.md) (vector index).
Research that named four new primitives:
`magentic-market-ai/docs/research/ThreeNewMemoryPrimitives.md`.

One-line: **the contract is real, M-home is decided, the engine and
the four primitives are not.** `EngineBinding.bind!` refuses
`engine_not_landed`. That is the honest reason.

---

## Where the work is

Two repos. Code is in **magentic-stack**. Research that started the
primitive slice is in **magentic-market-ai**. The engine used to live
only as a gitignored nested repo in MM; it has been copied into stack
(53 tracked files under `gems/mmg-medallion/`).

### magentic-stack (implementation home)

| Path | What it is | Built? |
|---|---|---|
| `gems/vv-medallion_memory/` | Memory product contract, `Vv::MedallionMemory` v0.1.0 | **contract only** |
| `gems/mmg-medallion/` | Build engine, `Mmg::Medallion` 0.2.0 | **scaffold** — writes not armed |
| `Gemfile` | path gems for both | yes |
| `docs/architecture/plan_vv_medallion_memory.md` | Product contract S0–S8, M1–M10 | yes; 09-11 banner superseded in part 09-15 |
| `docs/plans/medallion-memory-primitives.md` | Saved copy of a grok integration plan | record only, not verified |
| `tooling/medallion/check_medallion_memory.py` | Three tiers, no fork, distill blocked | yes |
| `tooling/medallion/plant_medallion_memory.py` | Puts the failures back | yes |
| `docs/architecture/MeaningActivations.md` | Serving weights `[-1, +1]` | models in mind-pod; not wired to `memory.serve` |
| `docs/architecture/RagContainer.md` | Vector index | search live, writes `rag_write_undecided` |
| `gems/mmg-graph/` | Oxigraph SPARQL wrapper | live; medallion does not call it |
| `runtimes/mind-pod/app/` | ContextFrame / Meaning / Clarification activations | built; `user_id` per activation still undecided |

`vv-medallion_memory` lib files today: `tier.rb`, `purpose.rb`,
`refusal.rb`, `provenance.rb`, `flow.rb`, `engine_binding.rb`,
`version.rb`. There is no `fact.rb`, `branch.rb`, `assemble.rb`,
`derivation.rb`, `serve.rb`, or `store.rb`.

### magentic-market-ai (research + old engine copy)

| Path | What it is |
|---|---|
| `docs/research/ThreeNewMemoryPrimitives.md` | Branch-and-merge, bi-temporal split, budgeted traversal, derivation index |
| `docs/research/SemanticMedallion.md` | Original lakehouse mapping |
| `docs/research/Semantic-Medallion-for-LLM-Memory.pdf` | Manus PDF the stack plan cites |
| `docs/research/AgentMemory.md` | Kumar: capture / resolve / persist-or-decay / retrieve |
| `gems/mmg-medallion/` | Nested git repo, parent-gitignored. **Stale home.** Do not keep committing here. |

---

## Contract vs engine vs product

```
  vv-medallion_memory     CONTRACT (built)
                          three Build tiers; Platinum refused by name
                          Purpose as sibling, not rank
                          closed refusals; six Flows; Bronze Provenance
                          EngineBinding: home :stack, bind! waits on audit!

  mmg-medallion           ENGINE (scaffold, 0.2.0, now in stack gems/)
                          Conformer / Curator / Flow / GraphProjection
                          dry_run default; armed write not wired
                          pragmatic_shacl_v0; no audit!; no cascade

  four primitives         NOT STARTED
                          Fact, Branch, Assemble, Derivation

  CPCP memory.*           NOT STARTED
                          land / conform / promote / read / lookup / forget / stat
```

The memory gem **must not** grow a Conformer, Curator, or
GraphProjection. The checker asserts that against the source tree.
Dependency direction, when it exists: memory gem → engine. Never the
other way.

---

## M1–M10 (engine modifications)

From `plan_vv_medallion_memory.md` §Modifications. `EngineBinding.landed`
today only *probes* M3 (`audit!`) and M9 (`cascade`). Completing a
partial means the engine half matches the contract half.

| # | Change | Status | Gap |
|---|---|---|---|
| **M-home** | stack `gems/mmg-medallion` vs MM pin | **done** | `HOME = :stack`. `mm_pin` refused as re-opening a closed question. |
| **M1** | Arm SPARQL writes | **not landed** | `dry_run: false` → `"armed write not wired to store in 0.2.0 (CAS pointer only)"`. Out of the M4/M7 slice. |
| **M2** | Real SHACL gate | **not landed** | Still `engine: "pragmatic_shacl_v0"` (empty set / blank lines). Out of the M4/M7 slice. |
| **M3** | Implement `audit!` | **not landed** | No method on `Mmg::Medallion`. This is the precondition for `bind!` going green. |
| **M4** | Bronze provenance stamps | **landed 2026-09-15** | Engine `Provenance` stamp; `dry_run: false` requires it; derived-as-observed is `bronze_mutated`. Memory gem envelope unchanged. `EngineBinding` probes `provenance_required_on_land?`. |
| **M5** | Silver temporal validity | **not landed** | No `validFrom`/`validTo`/`txFrom`/`txTo`. Conformer copies triples. Research wants two independent axes (supersession vs correction). |
| **M6** | Gold requires SemanticModel + Contract | **not landed** | Curator: `"curation link optional"`. No model/contract check on `dry_run: false`. |
| **M7** | Purpose carried on Flow/Tier | **landed 2026-09-15** | Engine `Flow` carries `purpose` (default build). Consume/Operate targeting a Build tier is `audit_rejected`. Platinum as a Build target is `platinum_not_a_tier`. `EngineBinding` probes `Flow#purpose`. |
| **M8** | Per-tier decay | **not landed** | `Layer.retention_hint` is slogans (`ephemeral_candidate` / `review_extend` / `retain_unless_governed`). No evidence binding. |
| **M9** | Deletion cascades | **not landed** | No `cascade`. `memory.distill` still blocked on M5+M9 (correct: a weight matrix has no tombstone). |
| **M10** | Confidence is a stamp | **not landed** | No `confidence=L1\|L2\|L3`. No refusal of a confidence-named rank. |

---

## Four primitives (research, not in code)

From `ThreeNewMemoryPrimitives.md`. None of these files exist.

| Primitive | Layer | Replaces | Gap |
|---|---|---|---|
| **1 Branch-and-merge** | Bronze→Silver, Silver→Gold | Unenforced promotion policy | Agents can still write to canonical (there is no branch). Vector index has no merge gate because there are no writes. |
| **2 Bi-temporal split** | Silver (sharpens M5) | Single-axis validity | One clock (or none). Cannot tell supersession from correction; cascade would over- or under-invalidate. `tx_from` is not engine-stamped because there is no fact table. |
| **3 Budgeted traversal** | Gold serving (Consume) | Host-side BFS + truncation | `memory.serve` is a Flow declaration. MeaningActivations exist in mind-pod and are not called. No `assemble(cue, seeds, node_budget, token_ceiling, as_of_tx)`. |
| **4 Derivation index** | Cross-cutting (sharpens M9) | Best-effort deletion sweeps | No `derivation` rows. Forget cannot walk Gold artefacts. Platinum stays correctly blocked. |

Research build order: **bi-temporal → derivation → traversal → branch.**
Do not implement branch first.

Owner decisions already locked for when this work starts:

- Journal admits; Fact is the Silver projection; graph is topology; rag embeds only after merge.
- `assemble()` then MeaningActivations (compose, do not replace).
- All four fully implemented in-gem (working, not types-only), without forking Conformer into the memory gem.

---

## Product stages (S0–S8)

From `plan_vv_medallion_memory.md`.

| Stage | Ships | Status |
|---|---|---|
| **S0** | Platinum/Serving/Working refused by name; plants | **half** — substrate/contract yes; engine `audit!` (M3) no |
| **S1** | `memory.land` on BACK; M1+M4 | **not started** |
| **S2** | `memory.conform`; M2+M5; entity resolution | **not started** (graph-side Silver does not need rag) |
| **S3** | `memory.promote`; first Semantic Gold model | **not started** (persona vs failure-lessons still an open question) |
| **S4** | `memory.read` + activations serving pack | **not started** |
| **S5** | M8+M9 + `memory.forget` cascade plant | **not started** |
| **S6** | first captured PySparqlFun | blocked on SparqlFun existing |
| **S7** | botdataengine overlay | not started |
| **S8** | Platinum Operate job | refused until S5 |

CPCP methods `memory.land|conform|promote|read|lookup|forget|stat` do
not exist. BACK does not own them yet.

---

## Doc drift

| File | Drift |
|---|---|
| `gems/vv-medallion_memory/README.md` | Still says `EngineBinding` refuses `medallion_home_undecided` and that M-home is open. Code: `HOME = :stack`, `undecided?` is false, `bind!` refuses `engine_not_landed`. |
| `plan_vv_medallion_memory.md` | 09-11 banner left as written; a 09-15 "SUPERSEDED IN PART" note already records that M-home is named. Open-questions list still leads with M-home. |
| `docs/plans/medallion-memory-primitives.md` | Snapshot of an earlier grok plan (M1–M9, then revised). Header says not independently verified. |

Closing doc drift is part of making the gap list itself not become a
third stale home.

---

## What is *not* a gap (do not "fix")

- Platinum is not a Build tier. A weight matrix has no tombstone.
- Summarising on ingest is `bronze_mutated`. `derive()` is the only escape hatch.
- Serving and Working are not tiers. Serving is Consume; the live window is volatile Bronze.
- No Conformer in `vv-medallion_memory`. That is the fork the plants exist to catch.
- `memory.distill` blocked until a tombstone can cascade (and until S8).
- `rag_write_undecided` still correctly refuses vector upserts.
- `userId` does not come from a model argument (`principal_override_refused`).

---

## Close order

1. **This file** — written 2026-09-15.
2. **M4 + M7** — **done 2026-09-15.** Provenance stamps on land; `purpose` on engine `Flow`; probes on `EngineBinding.landed`. `bind!` stays red (still needs M3).
3. **M3 `audit!`** — `bind!` goes green; pending M1, M2, M5, M6, M8, M9, M10.
4. **M5 then M9** (bi-temporal Fact + derivation cascade). Distill stays blocked on S8.
5. **M6, M8, M10.**
6. **Primitives 3 then 1** (assemble+serve, then branch-and-merge).
7. **M1, M2** when writes and a real SHACL gate are the blocker, not before.
8. S1–S5 CPCP / BACK wiring.

Each step leaves the tree spec-green. The memory gem still has no
Conformer when this list is done.
