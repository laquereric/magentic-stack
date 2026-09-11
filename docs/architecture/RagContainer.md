# `rag` — local Zilliz (Milvus) as the retrieval container

> ## BUILT 2026-09-11 — and the shape is not quite what this file assumed
>
> Two containers, not one. Option **3** was chosen: `rag` is a Rails
> `ROLE=rag` that IS the `rag.*` contract, and the engine is the official
> Milvus image beside it. That took the name: every Rails role is named
> for its role, so the engine is **`milvus`**, not `rag` as §"One compose
> service" assumed. The doc assumed the engine kept the name because it
> had not yet picked a face.
>
> The count: `rag` is the **14th** container. ADR 0058 keeps 13 for LOG,
> which stays decided-unbuilt. Owner named it.
>
> **One process after all**, but not for free. The published image has no
> `embedEtcd.yaml`, so `ETCD_USE_EMBED=true` panics in
> `etcd.InitEtcdServer` on a nil config — and without `DEPLOY_MODE=STANDALONE`
> it panics earlier with "embedded etcd can not be used under distributed
> mode". Both are set, and the etcd config is supplied as a compose
> `configs:` entry rather than a bind-mount, so no source tree is mounted
> into a third-party container. etcd and minio therefore stay engine
> internals, exactly as §"One compose service" wanted.
>
> **REST, not gRPC.** Ruby has no maintained Milvus gRPC client; Milvus
> serves REST v2 on the same 19530. Same engine, no protocol stack
> vendored into the pod.
>
> **The write path is still undecided, and is refused rather than guessed.**
> `rag.upsert` and `rag.delete` answer `rag_write_undecided` naming the
> open ADR question below. `rag.search` without a vector answers
> `vector_required` for the same reason: embedding here would be the
> silent pick this file warns against.

Companion to [`ContainerTopology.md`](ContainerTopology.md) (what runs)
and the graph store (oxigraph). Same *wrapping* shape as putting a CPCP
face on `graph`. Different *algebra*.

---

## What this is

A **thirteenth logical container**, `rag`, that holds the
retrieval-augmented-generation **index**: dense vectors, sparse/BM25
text, hybrid search.

The engine is **Zilliz's Milvus, run locally in the pod**. It is **not**
Zilliz Cloud. No account, no public endpoint, no cluster HA. The image
is third-party, unforked, digest-pinned, unpublished — the same
exemption class as `graph` (oxigraph) and `nats` (nats-server). See ADR
[0047](../adr/0047-three-languages-container-boundaries-own-images.md)
`exemption_conditions`.

Zilliz the company ships two products people collapse:

| Product | Where it runs | This pod |
|---|---|---|
| **Milvus** (OSS engine) | our compose, our volume | **this** |
| **Zilliz Cloud** | their SaaS | **not this** |

"Zilliz locally" in this document always means Milvus Standalone in
`rag`. It never means a cloud collection URL.

Redundancy and extra security are **out of scope**. No replicas, no TLS
termination, no second allowlist. In-pod CPCP still follows ADR
[0065](../adr/0065-nats-is-the-in-pod-l7-broker.md): when `MM_NATS_URL`
is set, NATS only; HTTP is not a fallback.

---

## What is actually there (so this is not a wish)

| Thing | Measured 2026-09-10 |
|---|---|
| Vector / BM25 store in the pod | **none.** |
| Zilliz Cloud client | **none.** |
| Embedding model in-pod | **none.** Completions go to `switch :8789`. |
| CPCP `graph.*` | **on BACK**, talking SPARQL to oxigraph `:7878`. |
| CPCP `rag.*` | **none.** |
| Language-rule exemptions | `graph`, `nats`. `switch` is a named **violation**. |

The only retrieval surface that exists is SPARQL on `graph` and CPCP
`graph.query` on BACK. That is identity and grounding, not nearest
neighbour.

---

## Parallel with `graph` — and where it stops

Zilliz : Milvus :: a CPCP face : oxigraph.

The engine stays the engine. Callers get a typed envelope instead of the
native protocol (Milvus gRPC / oxigraph SPARQL). We do not fork either
store.

| | `graph` | `rag` |
|---|---|---|
| Engine | oxigraph | Milvus (Zilliz, local) |
| Native protocol | SPARQL HTTP `:7878` | Milvus gRPC (and its REST) |
| Algebra | triples, named graphs, identity | ANN + BM25 + hybrid |
| Authority | **never.** Projection of the journal | **never.** Index of text/chunks |
| Grounding extra-state | AR `Entry` (date, name, description) | collection / schema / chunk ids |
| CPCP today | `graph.query` / `count` / `entries` / `publish` on BACK | unbuilt |
| Cloud offering we refuse | (none in play) | Zilliz Cloud |

They do **not** replace each other. A cycle can `graph.query` a named
graph for what was asserted and why, and `rag.search` for nearest
chunks. Generation stays on `switch`. Admission stays on BACK (ADR
[0052](../adr/0052-the-journal-is-the-only-admission-truth.md),
[0056](../adr/0056-back-and-backjob-are-the-writers.md)).

What is **not** parallel: Zilliz Cloud's extra product surface (managed
pipelines, cloud hybrid UI). `rag` does not add a new retrieval algebra
beyond what local Milvus already speaks. CPCP only changes the envelope.

ADR [0019](../adr/0019-switchyard-content-blind-router.md) is why this
is not a SwitchYard job. Routing is content-blind. Retrieval **is**
content. `rag` is a store, not a router.

---

## One compose service

The topology row is **one** container named `rag`. Prefer Milvus
Standalone as a **single process** so etcd/minio do not become extra
CPCP roles or extra gap-table rows. If the published image still
requires those processes, they are **engine internals** (the same class
as oxigraph SST files), not seams.

- Unpublished. No `ports:`.
- Named volume `rag-data`.
- Digest-pinned image, no build context, no bind-mount of our source.
- `MM_NATS_URL=nats://nats:4222` on the CPCP face (see §3). Native
  Milvus gRPC stays off the docker network once that face exists.

LOG (ADR [0058](../adr/0058-role-log-is-the-thirteenth-container.md))
was already the decided thirteenth container and is still unbuilt.
`rag` is a **second** claimant on that integer. Owner names the count;
this file does not.

---

## CPCP contract (destination)

JSON-RPC-LD, never-raise `{ok:true|false, reason, because}`. Subject
`cpcp.rag.rpc`. Same PDU HTTP would carry on `POST /_cpcp/rpc`.

| Method | Direction | Does |
|---|---|---|
| `rag.search` | pull | dense, BM25, or hybrid. Query is text and/or a vector. Returns chunk ids + scores, **not** a generation. |
| `rag.upsert` | push | insert/replace chunks. Vector may be supplied by the caller, or the face embeds via `switch` then stores. `operationId` required. |
| `rag.delete` | push | by id. `operationId` required. |
| `rag.stat` | pull | collection existence, counts. Never a default-collection lie: empty is `ok:true` with `n: 0`, or `ok:false` `collection_missing`. |

**Not registered:** anything that writes domain rows, anything that
calls the LLM for an answer, anything that SPARQLs oxigraph. Those are
BACK, `switch`, and `graph`.

`rag.upsert` does not admit a note. BACK admits; the index is a
projection of text BACK already journalled (same relationship as
`project_on_save!` → oxigraph). A chunk with no `operationId` is
refused. An agent cannot mark its own retrieval effect committed.

Who embeds: **not this container's job to own a model**. Write path
either (a) caller supplies the vector (BACK already talked to `switch`),
or (b) the CPCP face calls `switch :8789` once, then upserts. Pick one
in the ADR; do not do both silently.

---

## Three ways to give `rag` a CPCP interface

Same fork as graph. Milvus is the engine; the face is the question.

`rag.upsert` / collection metadata are **not** raw Milvus inserts in
our sense — they need a recorded why (operationId, source cid / note
id). A process that only speaks gRPC to Milvus cannot honestly serve
that without extra state, exactly as `graph.publish` needs AR `Entry`.

### 1. Sidecar — keep the official Milvus image

Second container next to `rag`, subject `cpcp.rag.rpc`. Milvus gRPC
stays on localhost-in-namespace or `rag:<grpc>`.

- Language: Rails (ADR 0047 default).
- Exemption on the engine image **unchanged**.
- Extra running container.
- `rag.search` here; extra-state for upsert/ids can live in the sidecar
  sqlite **or** stay on BACK with search-only on the sidecar.

Smallest change to the engine. The Milvus process still does not speak
CPCP; its neighbour does.

### 2. One container — our image, Milvus + CPCP in-process

`FROM` the Milvus image, CPCP listener as a second process. Only CPCP
is exposed; gRPC binds loopback inside the box.

- ADR 0047 §2: if adapter and store are **not** a boundary, they are one
  container. That is this option.
- **Drops** the third-party exemption. `rag` becomes our image.
- Compose service count stays one.
- Hot-patch of the adapter rebuilds the store image.

This is the one that literally gives **the rag container** a CPCP
interface.

### 3. Rails `ROLE=rag` — full seam, Milvus stays dumb

A Rails ROLE (pattern: persist / vault / bus). It **is** the `rag.*`
contract, including upsert extra-state. It talks gRPC to Milvus.
Milvus image stays official.

- BACK does not register `rag.*`. Domain writes still admit on BACK;
  indexing is a **call** to `cpcp.rag.rpc`.
- Engine exemption stays.
- Extra container, Rails image.
- Closest Zilliz-Cloud analogue: the product API owns collection
  metadata; the engine owns the index.

**Default if the store should look like vault:** (3).  
**Default if only gRPC must leave the docker network:** (2).  
**Default if the Milvus digest must not move:** (1).

Do not: fork Milvus, point `MM_NATS_URL` at Zilliz Cloud, or declare
BACK's future `rag.*` as "the rag container's interface" while gRPC
stays reachable — that leaves a second, untyped seam.

---

## What this document will not decide

| Decision | Why it is not mine |
|---|---|
| 13th vs 14th container vs LOG | ADR 0058 already claimed 13 for LOG, unbuilt. Owner names the integer. |
| Sidecar vs combined image vs ROLE=rag | §3. Same owner call as graph's CPCP face. |
| Who embeds (caller vs face→switch) | Two legal write paths; one must be the ADR. |
| Chunk schema / collection names | Payload design; not topology. |
| Whether `graph` also gets a CPCP face | Separate store, separate ADR. |
| Pin SHA / standalone vs clustered Milvus | Pin review when compose exists. Standalone is the intent. |

---

## Gates — built

Mirror `graph` / `nats`, and all six plants fire:

- `check_language_rule.py` — **done**: `milvus` is an exemption row beside
  `graph` and `nats`, third-party and unforked. The gate refused it first,
  which is the gate working.
- `check_cpcp_callers.py` — **done**: the controller is a `kind=server`
  row; an unclassified `_cpcp/rpc` site fails.
- `check_seam_authority.py` — **done**: `rag` declares what it is
  authoritative for, and what it is not.
- `check_rag.py` — **done**: engine digest-pinned, unpublished, `rag-data`
  named, no Zilliz Cloud URL; seam is `ROLE=rag`, routed, and known to the
  entrypoint.
- `plant_rag.py` — **done**: a Cloud endpoint, a published port, a missing
  volume, an unpinned engine, a missing route and an entrypoint that does
  not know the role each fail.

Zero jobs is a fail. A checker that has never been planted is not a
gate.
