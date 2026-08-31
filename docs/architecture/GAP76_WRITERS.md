# Gaps 76–79 — make the two-writer decision real

Measured 2026-08-31 from `5803e3e`. ADR
[0056](../adr/0056-back-and-backjob-are-the-writers.md). Four
consequences of one decision, one branch. No ADR edits. Volume not
changed. No GRAPH wiring.

## 76. The split, enumerated then gated

Claude's reading: BACKJOB writes Reconciliation and nothing else;
everything else is BACK's. **That reading holds**, with one
consequential row.

### What BACKJOB actually writes (source, not folklore)

`runtimes/mind-pod/app/bin/backjob`, ROLE=backjob, full Rails env:

| Site | Kind | Writer |
|---|---|---|
| `Note.count` | read | — |
| `Reconciliation.create!(note_count:)` | **domain write** | BACKJOB |
| `project_on_save!` → `Vv::Graph::ProjectionJob` | consequential outbox row for that write | BACKJOB |
| `OperationRequest.cross_boundary.admitted` / `exists?` | read | — |
| `cpcp_push(..., "l8.execution.complete", ...)` | HTTP to BACK | **BACK** writes the L8 rows |

No other `.create!` / `.save!` / `.update!` / `.destroy!` / bulk write
in the script. Completions were already not local writes.

### What BACK writes (reachable from ROLE=back)

Domain sqlite `schema.rb` has **61 tables**. Plus `sessions` (vv-base
migration `20260828000004`, not in this schema snapshot) and
`vv_graph_projection_jobs` (`ensure_schema!` at runtime).

Write sites in the running app, not gem specs:

| Source | Models / tables |
|---|---|
| `config/initializers/rails_cpcp.rb` `note.create` | `Note` |
| `db/seeds.rb` | Note, Actor, Mission, Vision, Persona, Journey, Flow |
| `SessionCycle.open` | `Vv::Base::Session` |
| `RailsOsiLevel8::CpcpAdapter` | OperationRequest, OperationJournalEntry, ExecutionReceipt, Context, CyborgChannel, BiographyEvent, ProvenanceEdge, AdmissionAttempt |
| `P7Commands` / `Learning` | Observation, Outcome, completion rows, learning events |
| `authorization` / `references` / `profile_index` | AuthorizationEvidence, ReferencePass, ProfileEvidence |
| P9 mutations, P11 store, P10 factory | ux_* / mng_* / intent_* |
| `project_on_save!` on Note / Session / Reconciliation | ProjectionJob |
| `l8.execution.complete` (including BACKJOB's HTTP) | ExecutionReceipt + journal — **BACK** |

FRONT: `HomeController` talks HTTP to BACK; no AR write.
VAULT: JSON file store, not domain sqlite.
MIND: own sqlite (ADR 0057), not domain.

Unknown ROLE: refuse. A new container does not inherit write rights by
existing.

### The rule

`runtimes/mind-pod/app/config/domain_writers.json`:

- BACK: `all_domain`
- BACKJOB: `Reconciliation` + consequential `Vv::Graph::ProjectionJob`
  (tables `reconciliations`, `vv_graph_projection_jobs`)
- FRONT, VAULT: nothing
- unknown: refuse

### The gate

`DomainWriters.install!`: `before_save` / `before_destroy` on
`ActiveRecord::Base` (catches ProjectionJob, which does not inherit
ApplicationRecord) plus an `sql.active_record` subscriber on
INSERT/UPDATE/DELETE (catches `insert_all` / `update_all` /
`delete_all`, which skip callbacks). A refused write is
`reason=domain_write_refused` on RefusalLog, then raised so it does
not succeed.

Static plant: `tooling/compose/check_two_writers.py`.
Runtime plant: `tooling/compose/plant_two_writers.rb`.

This is instrumentation of an invariant, not a CPCP contract change.
BACKJOB has no caller for the loop body.

## 77. WAL declared — delivering the guarantee, not a runtime change

**Before** (nothing in our tree set it):

| File | `PRAGMA journal_mode` |
|---|---|
| host `runtimes/mind-pod/app/db/mind_pod.sqlite3` | `wal` |
| volume `mind-pod-demo_mind-data` `/data/mind_pod.sqlite3` | `wal` |
| `database.yml` | adapter, pool, `timeout: 5000`. No pragmas. |
| `PRAGMA journal_mode=WAL` in tree | `idempotency.rb:41` and `vv-blob` — different databases |

Rails 8 sqlite3 adapter `DEFAULT_PRAGMAS` includes `"journal_mode" =>
:wal`. The live files are wal because of that default.

**After:** `database.yml` `pragmas: journal_mode: wal`. Setting WAL on
a copy of the already-wal host file returns `wal`. Runtime unchanged.

`timeout: 5000` was already declared; it is the busy wait (gap 78).
`PRAGMA busy_timeout` on the volume via the sqlite CLI is `0` because
busy timeout is a connection setting, not a file property. Rails
applies `timeout:` per connection.

## 78. SQLITE_BUSY is a refusal — not a contract change

SQLite still allows one writer at a time in WAL. After 5000ms the
second raises. In BACKJOB that used to hit `rescue StandardError` and
get printed (and, after gap 63, recorded as generic
`backjob_loop_error`).

A lock timeout is a refusal: a boundary said no, for a reason. First
real customer of RefusalLog. `SqliteBusy.busy?` recognizes
`SQLite3::BusyException` and the `database is locked` wrap;
`SqliteBusy.record!` writes `reason=sqlite_busy`. The loop uses that
path instead of the generic print.

Not a contract change: BACKJOB's loop has no caller, return value
unchanged, CPCP envelopes unchanged. Observation, not a new `ok`
channel. Would have stopped if it needed one.

The plant produces a real `BEGIN IMMEDIATE` collision with
`busy_timeout=1` and shows the JSONL line.

## 79. Live prose, not history

Fixed now (live: routes, compose headers, code comments, READMEs,
QUICKSTART, bootstrap):

- `runtimes/mind-pod/docker-compose.yml` header
- `runtimes/mind-pod/app/extract/compose.yml` header
- `runtimes/mind-pod/README.md`, `mind/README.md`
- `runtimes/README.md`, `runtimes/graph/README.md`
- `QUICKSTART.md`, `bootstrap`
- `config/routes.rb` (seam vs writer distinguished)
- `config/initializers/rails_cpcp.rb`
- `rails-osi-level-8` engine.rb (schema owner, not sole writer)
- `profile9/translation_board.rb` comment

MIND system prompt was already plural at `b1f871b` (gap 62). Not
rewritten.

**Left (dated records, or unsure — listed, not edited):**

- ADRs 0045, 0047, 0048, 0050, 0052, 0055. 0056 is the amendment.
- `docs/reviews/*` (dated)
- `docs/plans/phase3-slo-mind-pod.md`
- `runtimes/mind-pod/docs/OSI_LEVEL_8_*.md`, `RAILS_OSI_LEVEL_8_IN_DEMO.md`
- `gems/osi-level-8-profiles/docs/*`
- CPCP protocol "sole writer on the far side"
  (`rails-cpcp` README/gemspec, `mmg-graph`, `ACIA.md`) — the seam
  far-side is still BACK; BACKJOB does not mount `/_cpcp`
- `GAP62_PROMPT.md` (dated measurement)
- `ContainerTopology.md` "sole writer degrades into folklore (gap 20)"
  — different claim

## What this does not do

- Does not change `mind-nooa-data`.
- Does not set `MM_OXIGRAPH_URL` on extract compose.
- Does not edit ADRs.
- Does not make BACKJOB mount `/_cpcp`.
- Does not add a second inbox.
- Gaps 64, 65, 74, 82, 61 still not ours.
