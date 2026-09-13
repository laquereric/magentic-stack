# ProcedureRepo — BACK catalog of procedural memory

> ## CONTRACT GEM 2026-09-13 — `gems/vv-code-repo`
>
> Refusals, `procedure.*` operation list, land/bind/serve/promote
> envelopes, DEV grant. **No AR, no blob IO, no CPCP dispatcher.**

**Design only for the store.** No `procedure.*` CPCP on BACK, no AR
tables, no Gold renderer row. This file is the contract an
implementation has to keep.

**Store is Rails ActiveRecord on BACK + `vv-blob` / `mmg-blob`.**
DuckDB is **deferred** and is not a prerequisite. Analytical scan of
these tables, if anyone later wants it, is
[`IntegrateDuckDb_3_paths.md`](IntegrateDuckDb_3_paths.md) path 1
read-only over SQLite — not a second authority.

Companion: [`plan_self_learn.md`](plan_self_learn.md) (GOLD → PROD →
Bronze collection → Gold recommendations; eval per EvalGrading),
[`plan_ornith.md`](plan_ornith.md) (v2 solver; not v1),
[`plan_vv_medallion_memory.md`](plan_vv_medallion_memory.md)
(tiers, cardinal sin, Platinum refused), ADR
[0012](../adr/0012-mmg-blob-content-addressed-operations.md),
[0047](../adr/0047-three-languages-container-boundaries-own-images.md),
[0052](../adr/0052-the-journal-is-the-only-admission-truth.md),
[0056](../adr/0056-back-and-backjob-are-the-writers.md),
[0057](../adr/0057-three-kinds-of-state.md),
Lu et al. *Procedural Graphs* (arXiv:2609.09153, 8 Sep 2026) at
`magentic-market-ai/docs/research/ProcedureGraphs.pdf`.

The sentence this file takes from that paper, because it is the
acceptance test and not a slogan:

> Just as a knowledge graph organizes factual knowledge into
> (entity, relation, entity) triplets for *what-is* questions, a
> Procedural Graph organizes procedural knowledge into
> (procedure, relation, procedure) triplets for *what-to-do*
> questions.

Identity of a revision is the **digest of its bytes**. The AR row
is the named account (title, current Gold pointer, LinkML cites,
language bindings). Same split as canvas: digest is the name,
`graph_iri` is refused on the way in.

---

## What this is not

- DuckDB, Iceberg, dbt, a lakehouse table. Deferred.
- A fourth Flow / tree / `ui_procedures` graph as truth. oxigraph
  may *project* AR rows later; it does not mint the procedure.
- MIND SQLite as the catalog. MIND's store is ephemeral inference
  state (ADR 0057). A procedure that only lives there is a lead,
  not a component.
- Platinum / weight updates. The repo does not fine-tune Ornith.
  Procedural knowledge stays outside the weights, where it can be
  inspected, retrieved, and edited without retraining (PG §1).
- FRONT eval. Language bindings are stored bytes. FRONT DBless
  **reads** Gold; it does not `instance_eval` Ruby or `exec` Python.
  MIND may run a Python binding in DEV against a harness. PROD
  FRONT uses the already-shipped renderer path.
- Summarising on ingest. Reflection text is **inferred** Bronze
  derived from an observed parent, or it is refused `bronze_mutated`.

---

## What is actually there (so this is not a wish)

Measured 2026-09-13.

| Thing | State |
|---|---|
| `procedure.*` CPCP | **none.** |
| AR `procedures` / bindings / transitions | **none.** |
| DuckDB | **none.** Deferred. |
| `vv-blob` / `mmg-blob` | **live.** Digest-named bytes; `date`/`name`/`description` required on put. |
| Journal | **live.** Admission (ADR 0052). |
| BACK / BACKJOB writers | **live.** ADR 0056. |
| `vv-medallion_memory` | **contract only.** Tiers, Flows, refusals. Engine unwired. `memory.curate` already says "semantic and procedural products are different models." |
| P9 GHIS renderers | **live in-process** (`Profile9::Renderer` / `ux.render`, ghis-19@1, DateInput ghis-20, Input ghis-21). Not a procedure row. |
| shared-ai-space-app FRONT | **live overlay.** Draws `ui.*` via CPCP; no procedure catalog. |
| Ornith runtime in MIND | **not wired.** Notes in `docs/research/Orinth1.md`, `Ornith2.md`, `Ornith3.md`. |

The stores exist. The catalog does not. This plan is the catalog.

---

## The object

A **procedure** is one named *what-to-do* unit:

| Field | Where | Why |
|---|---|---|
| `slug` | AR | stable name (`shape.render.ghis-19`) |
| `revision_digest` | AR cites blob | content address; `sha256:<64 hex>` |
| `tier` | AR | `bronze` \| `silver` \| `gold` |
| `reflection` | blob (and optional AR excerpt) | inferred text: when to use, pitfalls. Never overwrites the observed parent. |
| `linkml_in` / `linkml_out` | blob digests | I/O contract. Source is LinkML YAML; generated SHACL/JSON-Schema are artifacts, not a second authority. |
| `bindings[]` | AR + blob | one or more `{ language: ruby\|python, digest, entrypoint }` |
| `graph` | AR `procedure_transitions` + blob snapshot | PG: nodes, attributed edges (`condition`, `guidance`, `pitfalls`) |

Bytes of a revision (bindings, LinkML, envelope JSON) live in
`vv-blob`. AR never holds the program text. Two filings of the same
bytes are one digest (ADR 0012).

**Language bindings.** Ruby is the BACK/FRONT production path
(ADR 0047: Rails form everywhere except MIND). Python is the MIND
path. A procedure may have one or both. Missing a language is not
a refusal; asking PROD FRONT to run a Python-only Gold is
`binding_not_for_role`.

---

## Medallion (this repo is the place Bronze becomes Gold)

Same three Build tiers as `vv-medallion_memory`. Not a fourth.

```
observed rollout / expert prior     ──memory.episode──►  Bronze  (immutable)
        │
        └──conform (identity, LinkML, SHACL)──────────►  Silver
                │
                └──curate (validation gate, contract)─►  Gold
                         │
                         └── FRONT / MIND PROD read only
```

| Tier | What lands | Who writes | Who reads |
|---|---|---|---|
| **Bronze** | Raw episode: task, scaffold, rollout bytes, Ornith reward vector, expert prior, failed ΔG. Observed stamp. | BACK via CPCP PUSH. MIND in **DEV** is a caller, not a store. | SelfLearn refiner, humans |
| **Silver** | Resolved `slug`, LinkML in/out, typed bindings, PG topology. Inferred from Bronze; parent digest required. | BACKJOB `procedure.conform` | SelfLearn validate |
| **Gold** | Production component. First: a SHAPE renderer FRONT will call. Contract + held-out plant must pass. | BACKJOB `procedure.promote` | FRONT and MIND in **PROD** (PULL only) |

Platinum is refused by name (`platinum_not_a_tier`). Distilling
weights from Gold is the thing the medallion exists to prevent.

**DEV vs PROD (the write/read split).**

| | DEV | PROD |
|---|---|---|
| MIND | PUSH `procedure.put` / `learn.*` (journalled, `operationId`) | PULL `procedure.get` / `procedure.serve` only |
| FRONT | PULL Gold (same as PROD); never writes the catalog | PULL Gold |
| BACK | writer | writer of *reads' side effects* only (journal). No silent Gold overwrite. |
| Env | `PROCEDURE_WRITE=1` (or equivalent grant) | unset → `prod_write_refused` |

MIND does not keep a durable copy. If DEV MIND dies, Bronze is
still on BACK. If PROD MIND "remembers" a procedure that BACK does
not serve, that memory is a lead (ADR 0057).

---

## Procedural Graph (what AR must be able to say)

Lu et al.: directed attributed graph
`G = (V, R, E, Φ)`, `E ⊆ V × R × V`. Edge attributes in v1:
`condition`, `guidance`, `pitfalls`.

Online (PROD, graph **frozen**): localize the active node from the
last tool/step, extract the 2-hop neighborhood, emit situational
guidance. Guidance **biases** the solver; it does not dictate the
next CPCP call.

Offline (DEV, SelfLearn): refiner proposes Add/Delete/Update.
Validation gate on a held-out plant. Rejected candidates stay in
**rejection memory** so the next proposal does not repeat them.
A rejected graph never becomes the starting graph of the next
round.

AR tables (names are a sketch; migrations are the implementation):

```
procedures            id, slug, gold_digest, status
procedure_revisions   id, procedure_id, digest, tier, parent_digest,
                      provenance (observed|inferred), generation, reflection_digest
procedure_bindings    id, revision_id, language, digest, entrypoint
procedure_linkmls     id, revision_id, direction (in|out), digest
procedure_transitions id, revision_id, from_slug, relation, to_slug,
                      condition, guidance, pitfalls
procedure_rejections  id, procedure_id, candidate_digest, because, traces_digest
```

SQLite WAL is load-bearing under BACK+BACKJOB (ADR 0056). Declare
it; do not inherit it.

---

## First application — SHAPE renderers for shared-ai-space FRONT

A **deterministic** task. That is the point: Ornith and PG both
need a verifiable harness, and a renderer either matches the
fixture or it does not.

Today: `ux.render` / `Profile9::Renderer` compiles an accepted
ACIA (ghis-19@1, DateInput on ghis-20@1, Input on ghis-21@1) to
HTML (projection) or A2UI 0.9.1 (emit). The program lives in the
image. FRONT in shared-ai-space-app pulls `ui.surface.get` and
draws.

Destination: those renderers are **Gold procedures**.

| slug | In (LinkML) | Out (LinkML) | Bindings |
|---|---|---|---|
| `shape.render.ghis-19` | RenderBundle / ACIA document | receipt: html digest, token digest, `as=html` | Ruby required; Python optional (MIND check) |
| `shape.render.ghis-20` | same + DateInput field | same; `date_kind_missing` if ghis-19 | Ruby |
| `shape.render.ghis-21` | same + Input | same | Ruby |
| `shape.emit.a2ui-0.9.1` | ACIA | A2UI 0.9.1 JSON only | Ruby |

HTML remains a **projection**, never the source. A Gold binding
that returns authorable HTML as authority is `html_as_source_refused`.

Acceptance plant (this plan's hiring sentence):

1. Put the current ghis-19 renderer bytes as Bronze (observed,
   from git / image), conform to Silver (LinkML in/out), promote
   to Gold after the plant below is green.
2. Fixture ACIA → `procedure.serve slug=shape.render.ghis-19` →
   HTML digest **equals** today's `Profile9::Renderer` on the same
   fixture.
3. FRONT shared-ai-space-app, PROD grant: PULL Gold only; a PUSH
   is `prod_write_refused`.
4. A second language binding (Python) may exist; FRONT does not
   call it.
5. `graph_iri` on `procedure.put` is refused. Digest is the name.

Until 1–5 are plants, "the renderer is in the repo" is a Medium
article.

---

## CPCP (destination)

All writes: `operationId` required. Journalled. Never-raise
`{ok:true,…}` / `{ok:false, reason:, because:}`.

| Method | Direction | Does |
|---|---|---|
| `procedure.put` | push | Land a revision (bytes already in `blob.put`, or inline then blob). DEV only. |
| `procedure.get` | pull | By slug or digest. Returns envelope + binding list, not the program eval. |
| `procedure.list` | pull | Catalog; Gold-first in PROD. |
| `procedure.bind` | push | Attach `{language, digest, entrypoint}` to a revision. |
| `procedure.conform` | push | Bronze → Silver. LinkML + SHACL. BACKJOB. |
| `procedure.promote` | push | Silver → Gold. Requires Contract + held-out plant. BACKJOB. |
| `procedure.graph.get` | pull | Localized neighborhood or full graph. PROD default: 2-hop. |
| `procedure.serve` | pull | Gold only. FRONT/MIND consume. Budget later (token cap is SelfLearn). |
| `procedure.reject` | push | Record a failed ΔG in rejection memory. DEV. |

Refusals (closed set, add to `vv-medallion_memory` or a sibling):

`prod_write_refused`, `bronze_mutated`, `blob_digest_required`,
`graph_iri_refused`, `binding_not_for_role`, `html_as_source_refused`,
`linkml_required`, `contract_required`, `validation_failed`,
`platinum_not_a_tier`.

No SQL in a CPCP argument. No model weights. No `procedure.eval`.

---

## Layer vs store (so nothing is asked to be two things)

```
MIND DEV ──CPCP push──► journal (admit) ──► BACK AR ──cite──► vv-blob (bytes)
                                              │
                                              ├── procedure_revisions.tier = bronze|silver|gold
                                              └── procedure_transitions (PG)

MIND/FRONT PROD ──CPCP pull──► BACK AR Gold pointer ──blob.get──► bytes
```

SQLite/AR is OLTP identity. Blob is content. Journal is admission.
Graph (oxigraph) is an optional later projection of the same rows.
DuckDB is not on this diagram.

---

## Non-goals

- DuckDB / Iceberg / dbt as the procedure store.
- Fine-tuning Ornith from Gold.
- FRONT executing bindings.
- A marketplace of procedures.
- Replacing `memory.*` Flows — this is the **procedural** product
  those Flows already distinguished from the semantic one.
- Minting `graph_iri` as the procedure's name.

---

## Open questions (owner)

1. **Grant bit.** `PROCEDURE_WRITE` env vs a persona/grant on the
   paired device. Recommendation: env on the pod for v1 (DEV
   compose sets it; PROD image does not).
2. **Ruby source home.** Gold binding digest of in-repo
   `Profile9::Renderer` vs a copied blob. Recommendation: **blob
   of the file bytes** so PROD can pin a digest without reading
   git at runtime; CI checks digest matches HEAD.
3. **oxigraph projection.** v1 AR-only. Project when a SPARQL
   consumer exists, not before.

SelfLearn ([`plan_self_learn.md`](plan_self_learn.md)) is the only
writer of *new* Bronze from model traces. Expert priors and the
ghis-19 plant may land without it.
