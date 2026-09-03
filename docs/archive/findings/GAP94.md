# Gap 94: install the outbox, enqueue 96, drain

The earlier measurement (same file, before this land) was READ-ONLY:
live volume `mind-pod-demo_mind-data` had **96 notes** and
**no `vv_graph_projection_jobs`**. Reset-to-pending had nothing to
operate on. Owner ruling: copy the gem migration into the app, migrate,
enqueue the 96 as pending, drain through the path that now fails closed
(gap 69). Schema change AND a live-store write. Rehearsal on copies
first. Did not fold U5.

## What changed in the tree

- `runtimes/mind-pod/app/db/migrate/20260811170000_create_vv_graph_projection_jobs.rb`
  is a byte copy of `gems/vv-graph/db/migrate/20260811170000_create_vv_graph_projection_jobs.rb`.
- `ProjectionJob.schema_status` uses `connection` (establishes the
  pool). `connected?` is false in a freshly started rails runner and
  was reporting `:check_failed` while the table existed, so Immediate
  refused to drain. A real lookup error still rescues to `:check_failed`.
- Gate: `check_outbox_migrated.py`. The app migrate dir must hold that
  file, and it must match the gem. `check_outbox_schema.py` now also
  fails if `schema_status` gates on `connected?`.

`ensure_schema!` remains specs-only. Immediate still refuses
`:missing` / `:check_failed`. Did not dump live `schema.rb`. Did not
apply `20260828*` (sessions / `mmg_graph_entries`) to live. Did not
`down -v`. Demo volumes preserved.

## Rehearsal (copies of the live volumes)

Volumes: `gap94-rehearsal-mind` / `gap94-rehearsal-graph`.
Compose bind-mounted worktree `gems/vv-graph` over the image gem
(`mind-pod:latest` GEM_HOME is still 0.23.0 without gap 69).

| step | result |
|---|---|
| preflight | 96 notes, outbox **absent**, 38 `schema_migrations`, no `20260811170000` |
| `db:migrate` (full, copy only) | outbox installed; also applied `20260828*` sessions/entries — extra, **copy-only** |
| enqueue | 96 pending |
| first drain | refused: `schema_status` `:check_failed` because `connected?` was false |
| after `connection` fix | `{ok:true, drained:96, errors:0}` |
| graph | 384 named-graph triples, 96 subjects, 0 applied-without-graph |

Rehearsal sqlite after: 96 applied, 0 pending, `20260828*` present
(3 rows), 42 migrations. Plan was not wrong. Went live.

## Live (external demo volumes)

Compose `gap94-live` on **external** `mind-pod-demo_mind-data` +
`mind-pod-demo_graph-data`. Same bind-mount of worktree vv-graph.
`db:migrate:up VERSION=20260811170000` only.

| step | result |
|---|---|
| preflight | notes=96, outbox **missing** |
| migrate-up | `20260811170000` only |
| enqueue | 96 pending |
| graph before | 0 (named-graph UNION) |
| drain | `{ok:true, drained:96, errors:0}` |
| graph after | **384** named-graph triples, **96** subjects, **1** named graph |
| applied | 96 |
| applied-without-graph | **0** |
| `20260828*` on live | **0** |
| `schema_migrations` | 39 (38 + outbox) |

Containers `down` without `-v`.

Read-only re-census 2026-09-02 (sqlite copied off the volume; SPARQL
against a **copy** of the graph volume, not the live lock):

| store | notes | outbox applied | pending | mig `20260811170000` | `20260828*` | default-graph COUNT | named-graph UNION | subjects |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| LIVE `mind-pod-demo_*` | 96 | 96 | 0 | 1 | 0 | 0 | **384** | **96** |
| REHEARSAL `gap94-rehearsal-*` | 96 | 96 | 0 | 1 | 3 | (not re-queried) | (not re-queried) | (not re-queried) |

Default-graph `SELECT (COUNT(*) AS ?n) WHERE { ?s ?p ?o }` stays 0.
The triples live in named graphs (`PodGraph::STATE`). Gap 7's "0
triples" was that default-graph query plus a truly empty store; the
store is no longer empty.

## Row 7

96 notes are now in GRAPH. Replay is not needed for these 96.
Whether projection stays in BACK or becomes `ROLE=project-graph`
is still an owner call. Row 7 stays open for that.

## Gate / plants

`tooling/cpcp/check_outbox_migrated.py`. Plants: empty CHECK_ROOT;
delete the app copy; diverge the app copy from the gem.
`check_outbox_schema.py` plants: drop `schema_status`; plant lazy
`ensure_schema!`; restore `connected?`.

Image rebuild so GEM_HOME carries gap 69 is not this task. Live drain
used the bind-mount.
