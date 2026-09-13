# Integrate DuckDB — three paths

**Design only. Not built.** No binary, no compose service, no gem, no
`lake.*` CPCP, no dbt project, no Iceberg writer in this repo. This
file is the contract an implementation has to keep.

Source read: `magentic-market-ai/docs/research/DuckDb.md` (DataExpert,
3 Sep 2026, *DuckDB Just Put a $400K/Year Skill on Your Laptop*).
Companion: [`SqliteFast.md`](../../../magentic-market-ai/docs/research/SqliteFast.md)
(DuckDB is the columnar twin of SQLite, not a replacement),
[`RagContainer.md`](RagContainer.md) (engine stays the engine; CPCP is
the envelope), ADR
[0047](../adr/0047-three-languages-container-boundaries-own-images.md),
[0052](../adr/0052-the-journal-is-the-only-admission-truth.md),
[0056](../adr/0056-back-and-backjob-are-the-writers.md),
[0057](../adr/0057-three-kinds-of-state.md).

The sentence this file takes from the article, because it is the
acceptance test for path 3 and not for 1 or 2:

> An engineer who ships a credible Iceberg/dbt/DuckDB stack locally
> has a legitimate claim to the role.

Comp figures, MotherDuck counts, and “6–7× Snowflake” timings in the
source are **the author’s claims, not our measurements.** They are
quoted because they point at an architecture choice. The architecture
choice is the part we can check ourselves.

---

## What this is not

DuckDB does not become a fourth authority.

| Store | Algebra | Authority |
|---|---|---|
| SQLite (BACK / BACKJOB) | rows, FKs, transactions | **application state** |
| Journal | append-only operations | **admission** (ADR 0052) |
| oxigraph `graph` | triples, named graphs | projection of rows |
| Milvus `rag` | ANN / BM25 | index of text |
| DuckDB | columnar scan, Iceberg write | **never.** Analytical engine over data the others already hold |

It does not replace AR for point lookups (SqliteFast: 134× slower than
SQLite on PK get). It does not replace oxigraph for identity. It does
not replace Milvus for nearest neighbour. It does not admit operations.
Generation stays on `switch`.

Redundancy and extra security are out of scope. No MotherDuck account,
no Snowflake adapter in v1, no Spark cluster. Local, unpublished,
digest-pinned if it is an image; in-process if it is a library. Same
exemption class as `graph` (oxigraph) and `nats` (nats-server): a
third-party engine we do not fork.

---

## What is actually there (so this is not a wish)

Measured against this repo, 2026-09-11.

| Thing | State |
|---|---|
| DuckDB binary / gem / compose service | **none.** |
| Iceberg writer in magentic-stack | **none.** |
| dbt project / `dbt-duckdb` | **none.** |
| DuckLake / Polaris catalog | **none.** |
| SQLite as application store | **live.** `mind_pod.sqlite3` on BACK/BACKJOB. |
| oxigraph | **live.** Identity and SPARQL. |
| `rag` / Milvus | **search live; writes `rag_write_undecided`.** |
| `mmg-archive` Iceberg/Parquet cold tier | **MM substrate**, not this pod. Doctrine in `durable-is-the-event-log-hot-and-cold.md`. |
| Python in-pod | **MIND only** (ADR 0047). dbt Core is Python. That collision is named in path 3, not papered over. |

The article’s May 2026 milestone — DuckDB v1.5.3 Iceberg **write**
(MERGE INTO, ALTER TABLE, partition transforms, Iceberg V3) — is why
a local lakehouse stopped being architecturally dishonest. Before
writes, you could query Iceberg and not manage it. We have not pinned
that version. Path 2+ must pin a release that actually writes, or it
is the old dishonest laptop.

---

## The honest gaps the article already named

Keep these in the design. They are not TODOs to be designed away in
v1.

1. **One writer.** DuckDB serializes or fails multi-process writes.
   BACK and BACKJOB are already two SQLite writers (ADR 0056). DuckDB
   writing the same file, or two DuckDB processes writing Iceberg, is
   the interview question the article says “DuckDB handles it” fails.
   Quack / DuckLake concurrency is **not** treated as stable here.
2. **Iceberg+Parquet is slower than native DuckDB.** Manifest
   explosion (hourly appends → thousands of manifests / year) is the
   2026 operational failure mode. A laptop demo never hits it. A path
   that writes Iceberg without a compaction + snapshot-expiration job
   is a toy.
3. **Lineage vs dbt tests.** dbt Core tests grain and freshness
   inside a model. It is not a governance platform. Column-level
   lineage as a CIO mandate is **not** claimed by path 3.
4. **Ops muscle.** A laptop stack does not page you at 03:00. We do
   not pretend otherwise. What we can do is refuse to ship a path
   whose happy path has no compaction, no snapshot expiration, and no
   named writer.

---

## Three paths

They are a ladder. Each path is a complete, shippable slice. Path *n*
must not require path *n+1*. Path 3 is the only one that satisfies
the hiring sentence. Path 1 is still worth shipping: it is the
SqliteFast complement and it is the only path that does not fight
ADR 0047.

```
   Path 1  DuckDB reads SQLite / Parquet          ← analytics, $0, in-process or sidecar
        ↓  still not a lakehouse
   Path 2  DuckDB writes Iceberg + DuckLake       ← manage tables locally, no Spark
        ↓  still not dbt
   Path 3  dbt Core + dbt-duckdb on that Iceberg  ← the credible stack
```

Any two of the three tools existed before spring 2026. The article’s
point, which we keep: **without Iceberg writes, local work is a
query demo; without dbt, it is not the framework enterprises run;
without DuckDB, Iceberg writes still meant Spark.**

---

### Path 1 — DuckDB as SQLite’s analytical twin

**What it is.** An embedded columnar engine that scans the data we
already have. `sqlite_scanner` over `mind_pod.sqlite3`. Direct
Parquet/CSV/JSON reads when a file exists (archive snapshots, blob
exports). GROUP BY / window / incremental rollups that SQLite is the
wrong shape for.

**What it is not.** A warehouse. An Iceberg catalog. A second
admission log. A writer of application rows.

**Writer rule.** **Read-only** against SQLite. BACK/BACKJOB remain
the only mutators of `mind_pod.sqlite3`. DuckDB opening that file
for write is `duck_sqlite_write_refused`. Native DuckDB tables, if
any, live in a **separate** file (`duck-data`, persist-placed), never
in the AR file.

**Where it runs (pick one; default A):**

| | Wiring | ADR 0047 | When |
|---|---|---|---|
| **A** | Sidecar, unpublished, digest-pinned DuckDB image. SQL/Arrow over a local port. CPCP face on BACK: `duck.query` | Same exemption as oxigraph: third-party engine, not our code | default |
| **B** | In-process `duckdb` Ruby FFI inside BACK | A C++ library in a Rails process. Not a new language, but not “Rails form” either. Record as a named exception if chosen | only if A’s process hop is measured and too slow |

Do not put DuckDB in MIND. MIND’s SQLite is ephemeral inference
state (ADR 0057), not the analytical plane.

**CPCP (destination).**

| Method | Does |
|---|---|
| `duck.query` | parameterized SQL. Returns columns + rows, never a generation. Read-only. |
| `duck.stat` | file path, duckdb version, read-only flag, last query journal position if known |

Refusals: `write_sql_refused`, `sqlite_write_refused`, `vector_required`
is not this store.

**Acceptance.** A plant that GROUP BYs a real table in
`mind_pod.sqlite3` and does not take a SQLite write lock that BACK
can notice. No Iceberg files. No dbt.

**Claim this path does not earn:** the lakehouse role. It earns
“we can aggregate without Snowflake credits.”

---

### Path 2 — DuckDB writes Iceberg; catalog in SQLite (DuckLake)

**What it is.** Local table management. MERGE INTO, partition
transforms, schema evolution, against Iceberg V3, with the catalog
**embedded in SQLite** (DuckLake, April 2026) rather than Hive/Glue/
Polaris. This is the article’s “Spark requirement disappeared”
slice. 96% of Iceberg writes used to mean a JVM cluster. Path 2
collapses that to the same engine as path 1.

**What it is not.** dbt. Multi-writer Iceberg. A replacement for
`mmg-archive`’s *meaning* (cold projection of the durable log, two
assertions: file exists, catalog contains these contents). If we
write Iceberg here, catalog rows still need an AR home
(`Snapshot` / `CatalogEntry` or a stack equivalent) so graph can
project them. Ungrounded Iceberg files are the hairball
AR-grounded-triples exists to refuse.

**Writer rule.** **One DuckDB writer.** BACKJOB owns Iceberg writes
and compaction. BACK may `duck.query` those tables. A second DuckDB
process that writes is `duck_multi_writer_refused`. Compaction and
snapshot expiration are jobs, not comments — without them path 2
is the laptop that never sees manifest explosion.

**Where it runs.** Path 1’s sidecar, plus a volume for the warehouse
(`lake-data`: Iceberg table dirs). DuckLake metadata **in SQLite**,
placed by persist, **not** in `mind_pod.sqlite3`. Mixing lake
catalog rows with Notes/Journeys is how two authorities share a
file and then disagree.

**Relation to `mmg-archive`.** MM already named Iceberg/Parquet as
the **cold** durable tier. Path 2 in this pod is the **query and
maintain** engine over that shape, or over a new analytical
warehouse that is *not* the event log. Do not compact the journal
into Iceberg from DuckDB as a side effect of a dashboard query.
Journal compaction stays a durable-tier job. DuckDB may *read* the
archive.

**CPCP (adds to path 1).**

| Method | Does |
|---|---|
| `duck.merge` | Iceberg MERGE INTO. `operationId` required. BACKJOB. |
| `duck.compact` | rewrite small files. BACKJOB. |
| `duck.expire_snapshots` | snapshot expiration. BACKJOB. |
| `duck.tables` | list Iceberg tables + partition spec + snapshot id |

Writes that skip `operationId` refuse. Reads remain `duck.query`.

**Acceptance.** Create a table, MERGE two batches, compact, expire.
A catalog AR row names the snapshot file (digest + path). Query
after compact returns the same grain. Two DuckDB writers in the
plant: the second refuses.

**Claim this path does not earn:** “dbt.” It earns “we can manage
Iceberg locally without Spark.” Hiring panels that ask for dbt
`ref()` and incremental materializations will still say no.

---

### Path 3 — Iceberg / dbt / DuckDB (the credible stack)

**What it is.** The sentence. dbt Core (Apache 2.0, no seat limits)
+ `dbt-duckdb` over path 2’s warehouse. Identical SQL and
`ref()` / incremental / SCD Type 2 models that a Snowflake
deployment would run. Tests for grain, referential integrity,
freshness. Compaction and snapshot expiration **as dbt jobs or
BACKJOB steps the models declare**, not as a README wish.

This is the functional equivalent of the production lakehouse
workflow the article prices at ~$500K/year Databricks — on the
laptop, at $0 compute, **if** the models are real: partition
evolution, schema migration, SCD2, documented grain.

**What it is not.** dbt Fusion. Column-level lineage UI. A
guarantee that MotherDuck or Evidence.dev “use it in production”
makes our pin correct. A Python service in MIND.

**The ADR 0047 collision, named.** dbt Core is Python. ADR 0047
assigns Python to **MIND only**. Three honest options; pick before
code:

| | Where dbt runs | Cost |
|---|---|---|
| **3a** | Third-party unpublished image (`dbt` + duckdb), digest-pinned, BACKJOB invokes via CPCP. Same exemption class as Milvus/oxigraph | default. dbt is not our code |
| **3b** | MIND | **refused.** MIND is the agent runtime and ephemeral inference state. Transforming the lakehouse there mixes kinds (ADR 0057) |
| **3c** | Rewrite transforms as Ruby | not dbt; fails the hiring sentence |

3a is the only option that keeps both the sentence and the language
rule. The image is unpublished, no `ports:`, persist-placed
profiles dir. Models live in **this repo** (or a private models
repo), versioned, reviewed. Running `dbt run` is a CPCP effect with
an `operationId`, not a developer laptop habit that happens to
share a volume.

**Writer rule.** dbt is the *author* of SQL; DuckDB is still the
single writer. BACKJOB runs `dbt run` / `dbt test` / compact.
Concurrent `dbt run` is `duck_multi_writer_refused`.

**CPCP (adds to path 2).**

| Method | Does |
|---|---|
| `dbt.run` | named models, `operationId`, journalled. BACKJOB |
| `dbt.test` | tests; failure is `{ok:false, reason: :dbt_test_failed}` with node names |
| `dbt.docs` | refuse to serve a public site; artifact digest only |

No `dbt run` from FRONT. No model SQL in a CPCP argument — the
model is a file in git. A caller that supplies a SQL string is
`sql_not_a_model`.

**Acceptance (the hiring plant).**

1. Incremental ingest → Iceberg (DuckDB) → dbt models → queryable
   layer.
2. SCD Type 2 on an entity that already exists in this pod
   (`Vv::Base::Actor` is the smallest).
3. dbt tests: grain unique, FK to Actor, freshness bound.
4. Compaction job ran; snapshot expiration ran; both journalled.
5. A second `dbt.run` overlapping the first refuses.
6. Documented: grain, partition key, why denormalized — in the
   model’s schema YAML, not a blog post.
7. `duck.query` after all of the above returns the SCD2 current
   row for one Actor.

Until 1–7 are plants, this path is a Medium article, not a claim.

**Claim this path earns:** a legitimate local claim to the lakehouse
role, with the ops gap still open (no 03:00 pager). That gap is
honest and stays in the README.

---

## Path vs store (so nothing is asked to be two things)

```
journal ──admit──► SQLite (AR) ──read-only──► DuckDB          Path 1
                         │
                         └──compact (durable tier)──► Iceberg files
                                                       ▲
DuckLake SQLite catalog ───────────────────────────────┤     Path 2
dbt models (git) ──BACKJOB dbt.run──► DuckDB writer ───┘     Path 3
```

SQLite remains OLTP. DuckDB remains OLAP. Iceberg is the **table
format** for the analytical warehouse and/or the cold archive, not
a new truth. dbt is the **transform program**, not a store.

---

## What we take from the article, and what we leave

**Take.** Iceberg writes made local lakehouse work honest. dbt Core
is the enterprise transform dialect. DuckDB is a 30MB engine, not a
cloud. The portfolio that moves a hiring panel is incremental
ingest + SCD2 + tests + compaction, not a notebook that `SELECT`s
Parquet. One writer is a real constraint; say so in the API.

**Leave.** Salary bands. MotherDuck customer counts. “FinQore 60×.”
Databricks retired-Standard outrage. Those are the author’s
economics. Our check is: can a plant rebuild the warehouse from
git + volumes without a credit card, and can a second writer be
shown to refuse.

**Leave also.** Spark as a write engine. Path 2 exists so we do not
add it. If an Iceberg feature DuckDB cannot write appears, that is
a pin bump or a refused method, not a Spark sidecar.

---

## Non-goals

- MotherDuck, Snowflake, BigQuery, Databricks as the engine.
- DuckDB as the AR database.
- DuckDB in MIND.
- dbt Fusion / paid lineage UI.
- Polaris REST catalog in v1 (DuckLake-in-SQLite first; Polaris is
  a later catalog swap if DuckLake stays unstable).
- Multi-writer Iceberg.
- Replacing `mmg-archive` doctrine with “DuckDB is the cold tier.”
- A fifteenth container integer fight in this file. Path 1A/2/3a
  is one unpublished engine plus BACKJOB as the face. Owner names
  the count.

---

## Deferred: ProcedureRepo / SelfLearn are not DuckDB work

Those products store **procedures** (SHAPE renderers first) as a
semantic-medallion catalog: Bronze traces curated into Gold
components. The store is **BACK ActiveRecord + `vv-blob`**, not a
columnar engine. DuckDB paths 1–3 stay design-only and are **not**
a prerequisite. Path 1 may later GROUP BY reward rows read-only.

Plans:

- [`plan_procedure_repo.md`](plan_procedure_repo.md)
- [`plan_self_learn.md`](plan_self_learn.md)

---

## Open questions (owner)

1. **Path 1 wiring: sidecar (A) or in-process FFI (B).**
   Recommendation: **A**, matching oxigraph/Milvus. Measure before
   B.
2. **Which Iceberg is path 2 writing** — a new analytical warehouse
   (`lake-data`), or the `mmg-archive` cold layout of the journal?
   Recommendation: **new warehouse**. Archive compaction stays a
   durable-tier job. DuckDB may read it on path 1.
3. **First SCD2 entity for path 3.** `Vv::Base::Actor` is already
   the first `ar_class` in `vv-bpmn-bbo`. Same recommendation here.
4. **dbt image (3a) vs “not path 3 yet.”** 3a is the only ADR-clean
   way to keep the sentence. Confirm before anyone copies a
   `profiles.yml` into MIND.
