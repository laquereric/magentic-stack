# Gap 7: why GRAPH is empty

Measured 2026-08-31 from `4593fe2`. Investigation only. No wiring.

The compose header says the Storable projection is not wired, so the
store comes up empty. `runtimes/graph/README.md` says it is no longer
empty. Those cannot both be true of the same store. A query settles it.

## 1. What MIND actually gets today

**From a SPARQL query against the only surviving graph volume,
`mind-pod-demo_graph-data`:**

```
SELECT (COUNT(*) AS ?n) WHERE { ?s ?p ?o }
→ n = 0

SELECT (COUNT(*) AS ?n) WHERE { { ?s ?p ?o } UNION { GRAPH ?g { ?s ?p ?o } } }
→ n = 0

SELECT DISTINCT ?g WHERE { GRAPH ?g { ?s ?p ?o } } LIMIT 20
→ no bindings
```

Oxigraph files exist (IDENTITY/MANIFEST from 2026-08-24 15:40, same
window as the 96-note sqlite demo). `000009.sst` is 1246 bytes. The
store came up. Nothing was asserted into it.

There is no `mind-pod_graph-data` volume. Canonical compose was never
the running demo.

**From BACK's sqlite on that same demo (`mind-pod-demo_mind-data`):**
96 notes, 0 sessions, no `mmg_graph_entries`, no projection-job table.
The demo never ran the session cycle and never grounded a graph entry.

**What the harness does (not the compose comment, not the MIND README):**

`runtimes/mind-pod/mind/harness.py` PULLs `session.latest` then
`session.context`. It does not SPARQL. It does not call `note.list`
(the README still says it does — stale). `session.context` is implemented
in `SessionCycle.context` as:

```sparql
SELECT ?s ?p ?o WHERE { GRAPH <urn:mm:session:ID> { ?s ?p ?o } } LIMIT N
```

sent through `Mmg::Graph::Execute.query`. If that call is `ok: false`,
the harness prints `mind_waiting` and returns — MIND does not cognize
on a failed preview.

On extract compose, `Execute.endpoint` is `http://localhost:7878`
(`execute.rb:15`: `ENV["MM_OXIGRAPH_URL"] || "http://localhost:7878"`).
Inside BACK that is not GRAPH. The query fails closed.

So today MIND gets: either `no_open_session` (ordinary, and what the
96-note demo was — no sessions table), or an empty/failed preview of
a named graph that has never held triples.

## 2. Why is Storable "unwired"?

It is not. The compose header is stale. The missing connection is
elsewhere.

| What exists | Where | Since |
|---|---|---|
| `triples do` + `project_on_save!` on `Note`, `Reconciliation` | models | `3cbd5bf` 2026-08-28 |
| same on `Vv::Base::Session` | `session_projection.rb`, **ROLE=back only** | `3cbd5bf` |
| `graph.replay` PULL + `rake graph:replay` | `GraphReplay`, `graph.rake` | `3cbd5bf` era |
| `graph.query` / `graph.count` / `graph.publish` | `Mmg::Graph::Cpcp.register!`, ROLE=back | `fa5f718` 2026-08-28 |
| `MM_OXIGRAPH_URL=http://graph:7878` | **canonical** `docker-compose.yml` only | `fa5f718` |
| `VV_GRAPH_TRIPLE_GATE=strict` | canonical `back` and `backjob` only | same |
| equality test 20 triples → 0 → 20 | `test/graph_replay_equality_test.py` | `c7a6e67` |

`runtimes/graph/README.md` (`c7a6e67`) is right that the **code path**
can fill GRAPH. It is wrong if read as a claim about the store that
has actually been running.

**What is not connected:**

1. **Extract compose (bootstrap / `bin/docker-containers`) never sets
   `MM_OXIGRAPH_URL`.** `git log -S MM_OXIGRAPH_URL -- extract/compose.yml`
   is empty. BACK's default is localhost. GRAPH is a sibling named
   `graph`. Extract BACK also does not `depends_on: graph`. Canonical
   does both.
2. **`Vv::Graph.publisher.schedule` never-raises `:error`**
   (`publisher/immediate.rb:42–45`). A projection that cannot reach
   oxigraph does not fail the `Note.create!`. The sqlite row commits;
   GRAPH stays empty; nothing in the request envelope says so.
3. **The Aug 24 demo predates projection.** `project_on_save!` landed
   2026-08-28. The 96 notes were written when there was no emit path.
   Even a correct URL would not have backfilled them without
   `graph.replay`.
4. **`ROLE=project-graph` does not exist.** That is row 7's container.
   It is **not** why the store is empty. Empty is "the writer that ran
   never reached oxigraph." A seventh Rails ROLE would not have filled
   this volume.

Two write paths, both needing the URL, neither used on extract:

| Path | Trigger | Lands in |
|---|---|---|
| Storable `project_on_save!` | AR save of Note / Reconciliation / Session | `<urn:mm:pod:state>` |
| `Mmg::Graph::Cpcp.publish` via `session.observe` | MIND's proposal, committed by BACK | `<urn:mm:session:ID>` |

Session graphs are **not** reconstructable from sqlite (graph/README
"What a rebuild does NOT recover" — that paragraph is still true).
State-graph triples from Storable **are**, via `graph.replay`.

## 3. What wiring would take, and what is an owner decision

Not done here.

**Would fill GRAPH on the extract path (config, not a new ROLE):**

- `MM_OXIGRAPH_URL=http://graph:7878` on extract `back` and `backjob`
- `depends_on: graph`
- `VV_GRAPH_TRIPLE_GATE=strict` (canonical already)
- `graph.replay` for the 96 notes already in sqlite
- New session.observe writes still need a reachable GRAPH or they
  refuse (`publish` rolls back the entry; Storable does not roll back
  the Note)

**Owner, not this investigation:**

| Decision | Why it is not mine |
|---|---|
| Does projection stay **inside BACK on write**, or is it the **`ROLE=project-graph`** the target topology names? | Topology. Row 7. Claude named this. Today the emit is in BACK (`project_on_save!`). Moving it is a repartition. |
| Is a PULL (`graph.replay`) allowed to write oxigraph? | It already does, as a rebuild of a projection. Confirming that as doctrine is owner-shaped. |
| Prompt rewrite (below) | Same class as the 030af95 persistence rewrite. Separate job. |

Setting the extract env var would make bootstrap behave like canonical.
That is still wiring. Not this branch.

## 4. Is MIND's prompt currently false?

**Yes.** Do not fix it here.

The prompt (`mind_agent.py:76–123`, rewritten at `030af95` for
persistence) says:

| Claim | Measured |
|---|---|
| "a pod whose knowledge lives in an RDF graph" | Knowledge is 96 sqlite notes. GRAPH has 0 triples. |
| "SPARQL SELECT, always scoped to ONE named graph and always bounded by a LIMIT" | MIND never issues SPARQL. BACK does, inside `session.context`. The model is instructed in a query language it does not speak. |
| "The store is append-only and holds every session ever opened, so an unscoped query reads across sessions and returns rows that look entirely plausible while belonging to someone else" | Hazard of a **populated** store. The store is empty. BACK already scopes the only query MIND can provoke. MIND cannot issue an unscoped query. |

This is the same class of untruth as "you never persist anything" was
before `030af95`: a standing instruction about a store that is not
doing what the instruction assumes.

The `mind_waiting` path when `session.context` fails is honest
**behaviour**. The prompt the model sees when it *does* run is not.

---

Looked in: SPARQL against `mind-pod-demo_graph-data` (live oxigraph on
that volume); sqlite `mind-pod-demo_mind-data` (96 notes, no sessions);
`extract/compose.yml` vs `docker-compose.yml`; `Execute.endpoint`;
`Note` / `Reconciliation` / `session_projection.rb`;
`publisher/immediate.rb` never-raise; `harness.py` vs `mind_agent.py`
vs `mind/README.md`; `graph/README.md`; git history of
`project_on_save!` (`3cbd5bf`) and `MM_OXIGRAPH_URL` (canonical only,
`fa5f718`).
