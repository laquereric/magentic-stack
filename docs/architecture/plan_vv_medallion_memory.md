# Plan — `vv-medallion_memory` (private gem)

> ## PARTIALLY BUILT 2026-09-11 — the contract half, and only that
>
> `gems/vv-medallion_memory`. Tiers, purposes, the refusal vocabulary,
> the six Flow declarations, and the Bronze provenance envelope. Plus
> `tooling/medallion/` with 10 plants firing. **No engine.** No
> Conformer, no Curator, no projection — and the spec asserts that
> against the source tree rather than trusting it.
>
> **It stops there because this file stops it there, twice.** Open
> question 1 and stage S0 both reserve M-home to the owner, and the
> text is unambiguous: *"The rest of M1–M10 does not start until this
> is named."* Confirmed by measurement — `mmg-medallion` 0.2.0 is its
> own git repo nested at `magentic-market-ai/gems/mmg-medallion` with
> the parent gitignoring `gems/`, so it cannot be pinned as a
> closed-substrate dependency (ADR 0038). The question is open, not
> merely unasked.
>
> **The blocker is executable, not a paragraph.**
> `EngineBinding.bind!` refuses `medallion_home_undecided` and names
> all ten pending changes. A blocker that lives only in a document is
> one nobody trips over: someone needs a Conformer, does not recall
> which file reserved the decision, and writes "a small one, just for
> memory" — which is the fork §Modifications names as a non-goal, and
> the next Flow forks it again. It keeps refusing even when a home *is*
> passed, because naming is not landing.
>
> **The cardinal sin is caught in the form it actually arrives.** Not
> an overwrite — a *laundering*: derived text wearing an `observed`
> stamp. `bronze_mutated` fires on that, and `derive()` is the only
> escape hatch, always bumping the generation, always stamping
> `inferred`, always naming its parent, so the three rules cannot be
> satisfied by accident.
>
> **Everything here was written to be true under either answer to
> M-home.** None of it has to be renegotiated once the home is named.

**Design only for the engine and S1–S8.** No compose role, no CPCP
`memory.*`, no Gold product, no Platinum job. This file is the contract
an implementation has to keep.

Companion to [`RagContainer.md`](RagContainer.md) (vectors are one
Silver index, not the memory), [`SparqlFun.md`](SparqlFun.md) (named
Gold retrieval, not re-derived), [`TowardsSlms.md`](TowardsSlms.md)
(selector after capture), [`MeaningActivations.md`](MeaningActivations.md)
(serving Gold is weighted, not a tree), [`LogContainer.md`](LogContainer.md)
(floor vs aggregation), and ADR
[0052](../adr/0052-the-journal-is-the-only-admission-truth.md)
(the journal is admission; graph and rag are projections).

Product surface: **botdataengine.ai**. Substrate: this repo.
Projection engine: `mmg-medallion` (modify in place; do not silently
fork). Spelling is **medallion** (two L's) everywhere except the
owner's original typing of the gem name.

Sources read for this file:

- `magentic-market-ai/docs/research/SemanticMedallion.md` — Modern
  Data 101 / Perez: Bronze raw, Silver IRIs, Gold connected knowledge.
- `magentic-market-ai/docs/research/Semantic-Medallion-for-LLM-Memory.pdf`
  — Manus, September 2026. The write → manage → read mapping, and the
  Platinum warning.
- `magentic-market-ai/gems/mmg-medallion` @ `0.2.0` — Build-layer
  engine. Conformer / Curator / Flow / named-graph contracts.
  Writes are not armed. `audit!` is doctrine, not code.
- `magentic-market-ai/docs/products/ProductMap.rb` — L2 split:
  `vv-memory` is storage, `vv-medallion` is the projection plane.
- `magentic-market-ai/gems/app-botdataengine` — landing skeleton.
  The Manus marketplace elaboration is **not** this product.
- `magentic-market-ai/docs/research/AgentMemory.md` — Kumar, Sep 2026:
  capture / resolve / persist-or-decay / retrieve. Anything discarded
  on the write path is unrecoverable at read time.

---

## The problem the PDF names, and the part we take

The 2026 memory field has a write–manage–read loop and almost no
discipline about which step is allowed to destroy the one beneath it.
The medallion is that discipline: **each layer adds meaning without
overwriting the layer it came from.**

| Layer | Memory equivalent | Loop stage | What it guarantees |
|---|---|---|---|
| **Bronze** | Raw episodic log | Write | Immutability, replay, full provenance. Nothing overwritten. |
| **Silver** | Resolved entities + timestamped facts | Manage | Stable identity, typing, temporal validity, dedup, contradiction. |
| **Gold** | Task-shaped knowledge | Read / activate | Relevance, abstraction, fit inside a hard context budget. |
| **Platinum** | Knowledge folded into weights | Internalise | Speed and density — **at the cost of every guarantee above.** |

The key translation, quoted because it is the whole Silver job: in
data engineering Silver assigns IRIs so records link across systems.
In memory that is **entity resolution across sessions**, so "my
manager Priya", "she", and "P. Raman" collapse to one node. Systems
that skip it accumulate and never connect.

**What we take.** Bronze is immutable. Summarising on ingest is the
cardinal sin — you cannot replay what you already overwrote, and you
cannot rebuild a poisoned Silver from a lossy Bronze. Platinum stays
out of Gold: a weight matrix has no tombstone.

**What we add.** The engine already exists (`mmg-medallion`). The
stack already has the stores (journal, `vv-blob`, oxigraph, Milvus,
vault, NATS). What does not exist is the **memory-shaped Flow set**
that binds those stores to the three Build tiers, plus a Consume
surface that injects Gold under a token budget, plus an Operate
surface that may later distill Platinum **from Silver**, never from
Gold-as-weights.

We do **not** build another Mem0 / Zep / Letta. We build the
refinement pipeline those products are each one slice of, on the
containers that already run.

---

## What this gem is

Private gem **`vv-medallion_memory`**. Not on rubygems.org. `Vv::`
because it is an upstream-shaped capability we consume; it is not the
substrate (`Mm::`) and not a hosting domain (`Mmg::`). Same naming
as [`plan_vv-code-search.md`](plan_vv-code-search.md).

It is the **memory product on the medallion engine**.

```
  mmg-medallion          Build engine: Layer, Flow, Conformer, Curator,
                         Purpose, Actionable, SemanticModel, Contract,
                         Promotion. Named graphs. audit! (to be armed).

  vv-medallion_memory    Memory-shaped Flows + CPCP + stack wiring.
                         Knows episodes, entities, temporal facts,
                         serving blocks, decay, observed-vs-inferred.

  app-botdataengine      Application overlay (ADR 0063). botdataengine.ai.
                         Consumes the gem. Does not live in this repo's
                         gems/.
```

ProductMap already split L2 as CQRS: `vv-memory` is the **data plane**
(Bronze episodes at rest), `vv-medallion` is the **projection plane**.
`mmg-medallion` migrated and superseded `vv-medallion`. This gem does
not reopen that migration. It is the first **concrete memory Flow
family** on the migrated engine, the way the compliance loop was
named as the first concrete Flow in ProductMap and never quite became
one.

Three phases, and they must not be conflated (same split as SparqlFun
/ TowardsSlms):

| Phase | Loop | Cost | Who |
|---|---|---|---|
| **Land** | write, Bronze | cheap per event, never lossy | BACK / BACKJOB, `vv-blob`, journal |
| **Conform** | manage, Silver | expensive, once per (subject, revision) | Conformer + SHACL + rag upsert |
| **Serve** | read, Gold | cheap per turn, budget-capped | Curator product + PySparqlFun + ContextFrame |

Platinum is not a fourth phase of Build. It is Operate: an optional
offline job that reads **stable Silver** and emits a rebuildable
artefact. See §Platinum.

---

## Product: botdataengine.ai

The owner owns the domain. The site gem
(`magentic-market-ai/gems/app-botdataengine`) is a portfolio landing:
CHARTER is one line ("bot data engine"), plus generated SAL/HTML.
That is the overlay slot. It is not the engine.

The Manus elaboration (`docs/research/botdataengine-elaboration.md`)
inferred a **semantic data marketplace** — agents discover, buy, and
ingest datasets. That is a different product. This plan does not
implement it. If botdataengine later grows a marketplace face, it
consumes Gold contracts (a published SemanticModel + freshness SLA);
it does not become the memory pipeline.

ADR [0063](../adr/0063-application-overlays-consume-the-substrate.md):
the application is a thin image on the mind-pod base, in its own
repo. `vv-medallion_memory` stays in `gems/` of **this** repo because
it is substrate capability, the same class as `vv-graph` and
`vv-blob`. The `.ai` site does not.

What the domain is for, once the gem exists: a bot's **yesterday**.
Not a document index. Not a bigger context window. The thing Kumar
names that nobody files a ticket for — the support agent that
proposes the fix that already failed, the coding agent that
re-suggests the rejected library, the sales agent that leads with
pricing two weeks after being told not to.

---

## What is actually there (so this is not a wish)

Measured 2026-09-11 unless noted.

| Thing | Where | State |
|---|---|---|
| `mmg-medallion` 0.2.0 | `magentic-market-ai/gems/mmg-medallion` (nested repo; parent gitignores `gems/`) | **engine scaffold.** Layer contracts, Flow registry, Conformer, Curator, Purpose, Actionable, SemanticModel, Contract, Promotion, in-process `GraphProjection`. |
| Conformer / Curator writes | same | **not wired.** Default `dry_run: true`. Armed path returns `because: "armed write not wired to store in 0.2.0 (CAS pointer only)"`. |
| SHACL gate | `conformer.rb` | **pragmatic_shacl_v0**: rejects empty shape_set, empty triples, blank lines. Not a SHACL engine. |
| `audit!` | PURPOSE_LAYERING.md | **doctrine only.** No method. Vocab has `AUDIT_RECORD`; no AuditRecord class. |
| Canonical tiers | `Tier::CANONICAL_ROWS` | **exactly three.** Bronze / Silver / Gold. A fourth slug is `nil`. |
| Named-graph IRI | `Layer.graph_iri` | `urn:mm:medallion/{flow}/{tier}/{revision}` |
| Retention hints | `Layer.retention_hint` | bronze `ephemeral_candidate`, silver `review_extend`, gold `retain_unless_governed` |
| `vv-memory` | ProductMap + MM `vendor/vv-memory` | **not in this repo.** Data-plane idea; not a stack gem. |
| `vv-medallion` | ProductMap | **superseded** by `mmg-medallion`. Shim exists (`install_vv_shim!`). |
| Journal | ADR 0052, BACK/BACKJOB | **live.** Admission truth. |
| `vv-blob` / `mmg-blob` | this repo, ADR 0012 | **live.** Content-addressed, idempotent `put`. |
| `graph` (oxigraph) | compose, BACK `graph.query` | **live.** Identity and grounding. No `userId` parameter. |
| `rag` (local Milvus) | [`RagContainer.md`](RagContainer.md) | **search live, writes refuse `rag_write_undecided`.** |
| PySparqlFun | [`SparqlFun.md`](SparqlFun.md) | **design only.** |
| ContextFrame activations | [`MeaningActivations.md`](MeaningActivations.md) | **built.** Weights `[-1, +1]`. `user_id` per activation still undecided. |
| LOG | [`LogContainer.md`](LogContainer.md) | **floor live, aggregation unbuilt.** |
| NATS | ADR 0065 | **live.** In-pod L7. |
| Vault | ADR 0046 | **live.** `put`/`list`; switch is allowlisted getter. |
| `vv-medallion_memory` | this repo | **none.** |
| CPCP `memory.*` | — | **none.** |
| botdataengine overlay on mind-pod | — | **none.** Landing HTML only. |

The projection engine is real and incomplete. The stores are real and
unwired to it. The memory product is the wiring, plus the Silver jobs
the engine does not yet know (entity resolution, temporal validity,
observed-vs-inferred), plus the Consume/Operate purposes the engine
named and did not implement.

---

## Layer mapping onto this stack

Bronze / Silver / Gold stay **pipeline position**, not confidence.
If a later spec needs evidence-confidence, name it L1/L2/L3 (PDF
§6.3). Mixing the two axes ships a document nobody can read.

### Bronze — land, never transform

`Purpose::BUILD`, actionable `landing`, state-change `raw_to_landed`.
Evidence already required by `Actionable`: `source_profile`,
`landing_receipt`, `raw_integrity`.

What lands:

| Intake | Bytes go | Triples go |
|---|---|---|
| Full turn logs / transcripts | `vv-blob` digest (`urn:mm:blob:sha256:…`) | Bronze named graph, pointer only |
| Agent trajectories (tool calls, failures, retries, user corrections) | blob + journal row | Bronze graph, one episode IRI |
| Raw documents / RAG chunks | blob; rag index is **not** Bronze | pointer in Bronze; chunk vectors wait for Silver |
| KV-cache / prefix state | blob, unparsed | none until Conformer |
| Working memory / the live context window | **volatile Bronze.** Session-scoped, dies with the session. Not a fourth tier. | optional; never the system of record |

Provenance envelope on every Bronze episode (PDF §2): session id,
actor, wall-clock, modality, source system, and a flag
**`observed | inferred`**. Reflections, Gold summaries, and
Dreaming-style profile synthesis that re-enter as episodes are
**inferred**. Without that flag the lineage graph is cyclic and
replay compounds errors (PDF §6.2). A generation counter bounds
recursive self-derivation.

**Cardinal sin, restated as a refusal.** A Conformer, a Curator, or
`switch` that writes a summary **over** the Bronze bytes is
`bronze_mutated`. Summaries are Gold products. They may be *landed*
as new inferred Bronze (a new blob, a new episode IRI). They may not
replace the source.

Admission is the journal (ADR 0052). Graph and rag are projections.
A Bronze land that never journals is not landed; it is a cache.

Promotion gate → Silver: extraction plus resolution. Nothing promotes
without an **identity and a timestamp**.

### Silver — first decision, and the only one that may resolve identity

`Purpose::BUILD`, actionable `transform`, state-change
`landed_to_conformed`. Evidence: `transformation_spec`,
`decision_execution`, `shacl_report`, `quality_result`.

This is where 2025–26 memory research actually lives, and where
`mmg-medallion`'s Conformer is currently a dry SHA of the input
triples. The memory product needs Silver to do jobs the lakehouse
Conformer named and did not implement:

| Silver job | Counterpart | Stack seam |
|---|---|---|
| Entity resolution across sessions | IRI / master-data assignment | oxigraph identity; same IRI, many Bronze pointers |
| Temporal validity | SCD Type 2 / Graphiti bi-temporal edges | `validFrom` / `validTo` on the Silver fact; the journal position is the clock |
| ADD / UPDATE / DELETE / NOOP merge | Mem0 extract-then-op | Conformer decision; **not** an LLM at serve time |
| Typed schemas | Memanto / SHACL | **real** SHACL via `shape`, not `pragmatic_shacl_v0` |
| Dedup + contradiction | data-quality rules | SHACL + explicit contradiction triples, not silent overwrite |
| Hybrid index | Hindsight / most stacks | `rag` (dense + BM25) **beside** the graph, same Silver subject |
| Cognitive typing | working / episodic / semantic / procedural | stamp on the Silver fact; routes the Gold destination |

**Temporal validity is the Silver differentiator.** The PDF attributes
the ~15-point LongMemEval gap (Zep 63.8% vs Mem0 49.0%) to this, and
those numbers are **third-party claims, not our measurement**. What we
can check ourselves: a store that knows *what* is true but not *when
it was true* will serve stale facts. Silver facts carry an interval.
A query that does not name a time is asking for "as of now", and the
answer records which journal position it used — the same determinism
rule as [`SparqlFun.md`](SparqlFun.md).

Hybrid retrieval lives **here**, not as a fourth tier. `rag.search` is
an index over Silver text. `graph.query` is identity and edges. Neither
is Gold. ADR [0019](../adr/0019-switchyard-content-blind-router.md)
still holds: SwitchYard is content-blind; retrieval is content; memory
is a store, not a router.

Promotion gate → Gold: consolidation. Facts promote when they recur,
generalise, or have proven useful downstream. Curator still requires
a Silver CAS pointer. Gold is not auto-asserted.

### Gold — connected knowledge, three products that are not one table

`Purpose::BUILD`, actionable `semantic_model`, state-change
`conformed_to_governed_product`. Evidence: `semantic_model`,
`contract`, `acceptance`, `shacl_report`, `freshness_result`,
`cas_outcome`.

Gold is the **shared definition of truth**, defined once, SHACL-typed,
contracted (freshness SLA + breakage policy). `mmg-medallion` already
has the value objects (`SemanticModel`, `Contract`). It does not yet
refuse a promotion that lacks them. That refusal is a required
modification.

For memory, Gold is three products that the field conflates. Keep them
named:

| Product | What it is | Consume path |
|---|---|---|
| **Semantic Gold** | Durable abstractions about entities: user/persona profiles, reflection trees, community reports, Dreaming-style background profiles | SPARQL over the Gold named graph; captured as PySparqlFun |
| **Procedural Gold** | How to act: playbooks, SOPs, ExpeL-style insights, **failure lessons** (highest value, least commonly implemented) | named functions / skills; TowardsSlms selector later |
| **Serving Gold** | Context-assembly under a token budget. Letta blocks, MemGPT paging. **This is Consume, not a fourth Build tier.** | ContextFrame + MeaningActivations; injected every turn |

Serving Gold is the place the lakehouse analogy strains (PDF §6.1).
In a lakehouse Gold is queried. In memory Gold is **injected**, under
a hard budget, on every turn. Budget as much design for the read path
as for the write path. The serving layer is a materialised-view cache
with an eviction policy, not a prompt-assembly afterthought.

Serving uses [`MeaningActivations.md`](MeaningActivations.md): a
meaning is activated under frames with a signed weight in `[-1, +1]`,
not owned by one parent FK. A serving pack is a walk of activations
above a threshold, not a tree dump.

PySparqlFun is how a Gold question stops being re-derived. TowardsSlms
is how choosing *which* captured function stops needing a frontier
model. Neither writes Gold. Both **read** it. The SLM never applies
scope ([`TowardsSlms.md`](TowardsSlms.md)): it chooses a function; the
function applies `userId` from the ContextFrame and vault credentials.

---

## Platinum — keep it out of Gold

PDF §4.4, restated as a substrate rule:

> Parametric memory breaks the medallion's core guarantee: it has no
> tombstone. A fact cannot be deleted from a weight matrix the way a
> row is dropped from a store, and a weight update leaves no audit
> trail for the provenance of the shift.

`mmg-medallion` already refuses a fourth Build tier
(`Tier.for("platinum")` is `nil`; PURPOSE_LAYERING `audit!` is the
doctrine). **Do not add Platinum to `CANONICAL_ROWS`.** That would be
exactly the maximalism `audit!` exists to reject.

Platinum is `Purpose::OPERATE`: an optional, rebuildable cache.

| Rule | Why |
|---|---|
| Distill from **Silver**, not from Gold-as-weights | Silver is the system of record for facts; Gold is a contracted product; weights are a derived artefact |
| Always rebuildable | A Platinum job that cannot be reproduced from Silver is a silent Gold |
| No tombstone → no authority | Deletion, contradiction, and governance execute on Bronze/Silver and cascade; Platinum is dropped and rebuilt |
| Offline | Sleep-time LoRA / Hope / SCM / cartridges are batch. They do not sit on the turn path |
| Out of v1 | Do not schedule the job until Silver has temporal validity and a deletion cascade that tests can see |

Working memory (the context window) is **volatile Bronze**, not
Platinum. Confusing the two is how a session cache becomes a weight
update with no receipt.

---

## Modifications to `mmg-medallion`

The owner said "modified if needed." It is needed. The engine is the
right shape and the wrong completeness. Changes stay in
`mmg-medallion` so every future Flow (compliance, transcripts, this
memory family) inherits them. `vv-medallion_memory` must not grow a
private Conformer.

Required, in order. Each earns its place by a unique state-change or
by arming one the doctrine already named.

| # | Change | Why it earns its place |
|---|---|---|
| M1 | **Arm SPARQL writes.** Conformer/Curator `dry_run: false` writes the named graph via the stack's `graph` seam (oxigraph), not an in-process `GRAPH = {}`. CAS pointer stays. | Without this the engine is a plan printer. |
| M2 | **Real SHACL gate.** Replace `pragmatic_shacl_v0` with validation against the flow's `shape_set`, served from `shape`. Persist the report, link it on the Promotion. SHACL remains a gate, not a transform. | Silver's unique state-change is conformance. A blank-line check is not that. |
| M3 | **Implement `audit!`.** Reject: (a) a proposed fourth Build tier, (b) Bronze that transforms, (c) Silver that only copies, (d) Gold promotion without SemanticModel + Contract + SHACL report + CAS. Return never-raise `{ok:false, reason: :audit_rejected, because:}`. | Doctrine with no method is a comment. |
| M4 | **Bronze provenance stamps.** `observed \| inferred`, `generation`, source blob digest, session, actor, wall-clock. Required evidence already lists `source_profile` / `landing_receipt` / `raw_integrity` — stamp them. | Circular-loop mitigation. Replay depends on it. |
| M5 | **Silver temporal validity.** Facts carry `validFrom` / `validTo` (journal positions, not wall-clock alone). Conformer UPDATE closes the previous interval; it does not overwrite. | The Silver differentiator. Stale-fact class of bug. |
| M6 | **Gold promotion requires published SemanticModel + Contract.** Curator already accepts optional `curation_id`; make model+contract mandatory for `dry_run: false`. | PURPOSE_LAYERING Gold is "defined once." Optional is not once. |
| M7 | **Purpose on Flow/Tier is carried, not only documented.** Consume and Operate remain sibling purposes, not tiers. Serving Gold registers `purpose: consume`. Platinum jobs register `purpose: operate`. `audit!` rejects a Consume/Operate thing wearing a Build rank. | Stops Platinum sneaking into `CANONICAL_ROWS`. |
| M8 | **Decay policy is per-tier, not a global TTL.** Bronze: legal-retention clock. Silver: contradiction and supersession. Gold: utility. Retention hints today are slogans (`ephemeral_candidate`); bind them to evidence. | Memory needs salience-weighted decay; a lakehouse only has retention. |
| M9 | **Deletion cascades.** A Bronze tombstone is executable and walks Silver then Gold. Platinum (when it exists) is dropped, not patched. Named-graph delete is SPARQL, journalled. | Mnemonic sovereignty. Poisoning defence. |
| M10 | **Confidence ≠ layer.** If a flow needs evidence-confidence, it is a stamp (`confidence=L1\|L2\|L3`), never a tier rename. | PDF §6.3, pre-empted. |

**Where the gem lives.** Today: nested under
`magentic-market-ai/gems/mmg-medallion`, parent-gitignored. The stack
cannot glob-pin a gitignored nested repo as a closed-substrate
dependency (ADR 0038). Two honest options, owner's call:

1. **Promote `mmg-medallion` into this repo's `gems/`** as a first-party
   stack gem (same namespace, same doctrine, M1–M10 land here). MM
   consumes it the way other stack gems are consumed.
2. **Keep it in MM** and publish/pin it so magentic-stack depends on a
   SHA, not a path inside a gitignore.

Do not silently copy the files into `vv-medallion_memory`. That is a
fork of the projection plane, and the next Flow will fork it again.

Out of scope for the engine: Mem0-style LLM extractors, Letta block
packing, LoRA trainers, a new storage plane. Those are this gem, or
Operate jobs, or not-v1.

---

## `vv-medallion_memory` — the memory Flow family

One engine, several Flows. Each Flow declares source graph(s), target
tier, shape-set, promotion policy, audit hooks — the contract
`semantic_medallion_next_step.md` already specified.

| Flow | Source | Target | Notes |
|---|---|---|---|
| `memory.episode` | journal + blob | Bronze | Land raw. Never summarise. Observed/inferred stamp. |
| `memory.conform` | Bronze graph + blob | Silver | Entity resolution, temporal intervals, SHACL, rag upsert of *conformed* text. |
| `memory.curate` | Silver graph | Gold | Requires SemanticModel + Contract. Semantic and procedural products are different models, different contracts. |
| `memory.serve` | Gold graph | Consume | Budget-capped ContextFrame pack. Activations, not a dump. |
| `memory.forget` | any | Operate | Per-tier decay / tombstone cascade. |
| `memory.distill` | Silver | Operate / Platinum | v2. Rebuildable. Refused until M5 and M9 exist. |

Idempotency: `(subject, template, idempotency_key)` already exists on
`MedallionFlow.start`. Memory subjects are **principal-scoped**: a
user, an account, a codebase, an agent. A Flow that lands another
principal's episode is `scope_violation`.

`userId` comes from the ContextFrame, never from an argument the
model supplied. Same rule as SparqlFun
(`principal_override_refused`). Vault credential name
`sparqlfun.<userId>` stays the query-time secret; memory writes use
the journalled principal. Do not invent a second identity channel.

---

## CPCP contract (destination)

JSON-RPC-LD, never-raise `{ok:true|false, reason, because}`. Subject
`cpcp.memory.rpc`. Same PDU HTTP would carry on `POST /_cpcp/rpc`.
When `MM_NATS_URL` is set, NATS only (ADR 0065).

This is **not** a new container. BACK already owns context/memory in
[`OVERVIEW.md`](OVERVIEW.md). The methods live on BACK (and BACKJOB
for conform/curate/distill). A fifteenth container named `memory`
would be a store we do not have; the stores are journal, blob, graph,
rag.

| Method | Direction | Does |
|---|---|---|
| `memory.land` | push | Bronze. Bytes → blob. Episode IRI → Bronze graph. Journal the admission. `operationId` required. Refuses `bronze_mutated` if the payload is a summary tagged as observed source. |
| `memory.conform` | push | Bronze → Silver. BACKJOB. Entity resolve + temporal close/open + SHACL. Rag upsert of conformed chunks once `rag_write_undecided` is decided. |
| `memory.promote` | push | Silver → Gold. Requires model + contract. `dry_run` default until M6 is armed. |
| `memory.read` | pull | Serving Gold. Input: ContextFrame + budget. Output: activated meanings/clarifications + blob refs, **not** a generation. Generation stays on `switch`. |
| `memory.lookup` | pull | Silver/Gold SPARQL or a named PySparqlFun. No query string at this seam once the function exists. |
| `memory.forget` | push | Tombstone + cascade. `operationId` required. |
| `memory.stat` | pull | Counts per named graph, last promotion, SHACL report ids, rag collection health. |

Refusals that must exist before the happy path is claimed:

| reason | when |
|---|---|
| `bronze_mutated` | attempt to overwrite or summarise-in-place |
| `audit_rejected` | `audit!` failed; `because` names which unique state-change was missing |
| `shacl_failed` | Silver/Gold gate |
| `model_required` / `contract_required` | Gold promotion without them |
| `principal_override_refused` | `userId` in args disagrees with the frame |
| `platinum_not_a_tier` | anyone passing `tier: platinum` to a Build API |
| `rag_write_undecided` | conform tries to upsert before that ADR is closed |
| `inferred_unbounded` | generation counter exceeded |
| `scope_violation` | subject outside the session principal |

`memory.read` does not call `switch`. If a caller wants generated
prose over the pack, that is a later `switch` completion whose
prompt cites the pack's IRIs. Retrieval that generates has quietly
become the thing capture was supposed to replace.

---

## Cross-cutting, specified per layer

These belong to no single tier (PDF §5). They are not optional
commentary.

**Forgetting and decay.** Not a lakehouse TTL. Bronze decays on a
legal-retention clock (and "ephemeral_candidate" for working memory
means the session ended). Silver decays on contradiction and
supersession (interval closed). Gold decays on utility (serving
weights drift toward 0; a 0-weight activation remains visible on
inspect, it is just not injected — same rule as MeaningActivations).

**Governance, replay, deletion.** A deletion request is executable at
Bronze and cascades. Replay rebuilds Silver/Gold from Bronze blobs +
journal. If Silver is poisoned you need a trustworthy Bronze; that is
the sharpest practical argument for immutable landing. The 2026
poisoning study the PDF cites (>90% of tested agents vulnerable, 100%
relapse when "fixed in conversation") is **not independently
reproduced here**; the architectural response does not depend on the
percentage: conversation is not a tombstone.

**Security.** Bronze immutability is the integrity floor. Extraction
under black-box threat models is a Consume problem: `memory.read` is
scoped, vault-credentialled, and never a dump of the Bronze graph.
Do not add a `memory.export` in v1.

**Evaluation.** Layer by layer, not only end-to-end. Silver: extraction
and resolution accuracy, temporal interval correctness. Gold:
downstream task success under a token budget. Platinum (v2):
retention vs catastrophic forgetting. Named benches (LoCoMo,
LongMemEval, MemBench, …) are **not** v1 gates. A plant that rebuilds
Silver from Bronze and checks IRI stability plus interval close is.

---

## Where the analogy strains — and what we do anyway

**The read path is the product.** HippoRAG PageRank, cross-encoder
rerank, agentic retrieval have no Gold-table equivalent. v1 serving
is: activations above threshold, optional `rag.search` over Silver
text for the same subject, optional captured PySparqlFun. Rerankers
and PageRank are v2. Do not skip v1 serving because v2 retrieval is
prettier.

**The loop is circular.** Gold reflections become new Bronze. Mitigate
with `inferred` + generation counter (M4). A reflection that promotes
back to Gold without new observed evidence is `inferred_unbounded` or
`audit_rejected` (Silver that only copies).

**One tool rarely covers extraction and retrieval.** The PDF's honest
caveat. We already split: blob/journal extract-and-keep, graph
identity, rag nearest-neighbour, switch generation, shape
validation. The gem's job is the **pipeline contract**, not a new
store.

---

## Stages

Design only. No stage is started by this file.

| Stage | Ships | Acceptance (observable) |
|---|---|---|
| **S0** | **HALF BUILT.** The substrate half shipped: `Tier.refuse("platinum")` returns `platinum_not_a_tier` with its reason, and `plant_medallion_memory.py` plants a fourth Build rank and watches the gate refuse it. The engine half (`audit!` itself, M3) waits on M-home. | ✅ Platinum/Serving/Working refused by name; ⛔ `audit!` not written — it lives in the engine. |
| **S1** | M1 + M4. `memory.land` on BACK. Transcript / trajectory → blob + Bronze graph + journal. | Same bytes twice → one blob (`stored: false`). Replay lists the episode. `bronze_mutated` plant. |
| **S2** | M2 + M5. `memory.conform` on BACKJOB. One entity resolved across two sessions. Temporal UPDATE closes interval. Real SHACL report persisted. | Two surface forms, one IRI. As-of query at T1 does not see the T2 fact. |
| **S3** | M6 + `memory.promote` + one Semantic Gold model (persona profile) with a Contract. | Promotion without model/contract refuses. Gold graph SPARQL returns the profile. |
| **S4** | `memory.read` + MeaningActivations serving pack. Budget argument is real (token or block cap). | Pack fits the cap. Zero-weight activations are inspectable and not injected. No `switch` call on the read path. |
| **S5** | M8 + M9 + `memory.forget`. Cascade plant: Bronze tombstone removes Silver fact and Gold projection; blob retained or legally dropped per policy. | After forget, `memory.read` does not serve the fact; Bronze replay shows the tombstone. |
| **S6** | First captured PySparqlFun over Gold (`prior_contacts` shape, memory-flavoured). | Third session does not re-derive; it calls the function. Deterministic on `(id, journal position)`. |
| **S7** | botdataengine overlay: thin image, ADR 0063 slot in `shapes-application/contracts/`. Landing copy names the memory product, not the marketplace elaboration. | Domain serves from the overlay; no memory code in the site gem beyond display. |
| **S8** | Platinum Operate job — only after S5. | Rebuild from Silver; forget-then-rebuild does not resurrect a tombstoned fact from weights. |

S2 is blocked on `rag_write_undecided` **only for the vector half**.
Graph-side Silver can ship without rag. Do not stall entity
resolution on an embedding ADR.

S6 is blocked on SparqlFun existing. Until then `memory.lookup` may
run a **named, stored** query with a journal pin; it may not accept a
caller-supplied SPARQL string.

---

## Non-goals

- A fourth Build tier named Platinum, Serving, or Working.
- Summarising on ingest, including "just for the vector."
- Zilliz Cloud, or any memory SaaS as the store.
- Forking `mmg-medallion` into this gem.
- Implementing the Manus botdataengine marketplace.
- Putting `userId` scope in a model prompt.
- Letting `memory.read` generate.
- Replacing `vv-blob`, the journal, oxigraph, or Milvus with "a memory
  database."
- End-to-end LongMemEval as a v1 gate.
- Sleep-time distillation in v1.
- Confidence-as-tier.

---

## Open questions (owner)

1. **M-home.** Stack `gems/mmg-medallion` vs MM nested repo + pin.
   The rest of M1–M10 does not start until this is named.
2. **`rag_write_undecided`.** Silver hybrid index needs a write path.
   Entity resolution does not. Close the ADR or accept graph-only
   Silver for S2.
3. **`user_id` on MeaningActivations.** Still undecided there. Serving
   Gold inherits the hole until it is closed.
4. **Container integer.** BACK owns the methods; no new container.
   Confirm, because rag/log/sparqlfun already fought over thirteenth.
5. **First Gold SemanticModel.** Persona profile for a single
   principal is the smallest contracted product. Failure-lessons as
   Procedural Gold is more valuable and larger. Which is S3?
6. **botdataengine copy.** Landing currently says "bot data engine."
   S7 should say yesterday-for-bots, not dataset-marketplace, unless
   the owner wants both faces on one domain.

---

## One-sentence frame

`vv-medallion_memory` is the write–manage–read memory product on
`mmg-medallion`'s Build engine, running on magentic-stack's journal,
blob, graph, and rag, served through ContextFrame activations, sold
at botdataengine.ai — with Platinum kept out of Gold, and with
summarising on ingest refused by name.
