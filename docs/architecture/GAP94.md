# Gap 94: the outbox does not say applied — it was never created

Measurement only. No writes. Live store copied off
`mind-pod-demo_mind-data` read-only (`docker run ... -v :ro`).

## Stores

| Store | notes | `vv_graph_projection_jobs` | schema_migrations includes gem migration |
|---|---:|---|---|
| **LIVE** volume `mind-pod-demo_mind-data` (`DB_PATH=/data/mind_pod.sqlite3`) | **96** (id 1–96, 2026-08-24 15:40–16:33) | **ABSENT** | **NO** (38 versions, none `20260811170000`) |
| REPO `app/db/mind_pod.sqlite3` | 4 | ABSENT | NO (24 versions) |
| REPO `app/db/m38.sqlite3` | 1 | ABSENT | NO (20 versions) |
| REPO `app/db/test.sqlite3` | 1 | ABSENT | NO (38 versions) |

96 is real. It is the compose volume, not the repo copies. Claude's
doubt was right about conflation and wrong about the live count: the
volume still has 96 notes. Last sqlite mtime on the volume is 2026-08-31
18:17; the notes themselves all date 2026-08-24.

App `db/migrate` has no copy of
`gems/vv-graph/db/migrate/20260811170000_create_vv_graph_projection_jobs.rb`.
`schema.rb` does not name the table. `ensure_schema!` is a runtime
`create_table`. It has **never succeeded against the live volume**: if
it had, the table would exist.

## Enqueue never happened

There are **zero** outbox rows in any state, because there is no
table. The 96 notes were written on 2026-08-24, before Storable was
wired. After wiring, no `note.save` on that volume created the table
either.

`Immediate#schedule` previously drained **even when** `outbox_ready?`
was false (`job = nil` then `drain_job!`). So a later save could have
emitted SPARQL without enqueueing. The live graph volume is still 0
triples (gap 7). Either no save ran the new path, or emit did not
land. Either way: **nothing was enqueued.**

## Reset-to-pending is the wrong remedy

The owner decided: reset affected rows to pending and let drain retry.
That needs rows. There are none. Running a reset against this store
is a no-op that looks like a fix.

`graph.replay` would emit without the outbox (bypasses the fail-closed
path). Also not this turn.

Honest backfill, when the owner wants it: **install the gem migration
in the app**, migrate, enqueue the 96 as pending, drain. That is a
schema change. Not done here.

## Row 7

Live volume: 96 notes, 0 outbox rows, 0 triples. Replay is still an
owner call. The mechanical half (env + fail-closed SPARQL) does not
enqueue historical notes.
