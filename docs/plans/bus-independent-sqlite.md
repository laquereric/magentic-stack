# BUS independent sqlite on a named volume (Rails multi-DB)

Status: built (uncommitted — verify with `bin/sweep` before push; row 114
pre-push hook refuses a red push to `main`).

Decision: BUS gets its own sqlite file on a new named volume `bus-data`,
wired as a second Rails database. `bus_projections` moves out of the domain
sqlite (`/data/mind_pod.sqlite3`) into `/bus-data/bus.sqlite3`.

* `bus-data` is a **named volume**: survives `down` + restart, deleted by
  `down -v`. Acceptable because BUS holds derived metadata, not truth
  (row 73: the journal stays in BACK). Loss = re-run the projection from
  BACK's journal, same class as GRAPH replay. Credentials stay bind mounts
  per ADR 0046:85 (`GAP46.md`); this does not touch them.
* Ingestion v1 = **dual-mount read**: bus mounts `bus-data:rw` +
  `mind-data:ro`, reads journal counts via the primary connection (SELECT
  only — passes the `DomainWriters` gate, which traps only
  INSERT/UPDATE/DELETE), writes via the bus connection. No new BACK RPC,
  no row-72 amendment. A BUS-pulls-BACK HTTP read stays a follow-up if
  zero shared-volume coupling is wanted later.

## Why

Today `bus_projections` is a table in the domain file shared by
`back + backjob + bus` (6 `DB_PATH` bindings across both composes).
Stand-in rationale (`GAP18.md:41`, `domain_writers.json:38`,
`docker-compose.yml:43`): "persist WHERE unbuilt; bus does not pick a store."

That makes row 43 ("persist enforces one writer per path") unstatable
without reopening ADR 0056, and mixes ADR 0057 kinds (application state vs
metadata) in one WAL/`SQLITE_BUSY` domain. Splitting gives one
writer-set per path — domain `{back,backjob}`, bus `{bus}`, mind `{mind}` —
and a persist closed set (row 39) of three sqlite paths instead of two
paths where one mixes kinds.

## What is true today (SHA `6f1686b`)

| Thing | Measured |
|---|---|
| Domain file | `/data/mind_pod.sqlite3` on `mind-data`, bound by back, backjob, bus × both composes |
| Bus write | `Bus::Projector.retain!` → `BusProjection.create!` on `ActiveRecord::Base.connection` |
| Bus read | `Bus::Projector.derive` → `OperationJournalEntry.group(:event_kind).count` on same connection |
| Entrypoint `bus)` | waits for `${DB_PATH}`, no `db:prepare` (schema is BACK's — gated by `check_role_bus.py`) |
| Migration | `db/migrate/20260903120001_create_bus_projections.rb` in primary stream; table in `db/schema.rb` |
| Gate | `check_role_bus.py` forbids `db:prepare` on bus, requires shared-DB stand-in prose |

## Build steps

### 1. Rails multi-DB (`runtimes/mind-pod/app/`)

1. `config/database.yml`: add `bus` entry alongside `primary`.
   `primary: ENV.fetch("DB_PATH", "db/mind_pod.sqlite3")` unchanged.
   `bus: ENV.fetch("BUS_DB_PATH", "db/bus.sqlite3")`,
   `migrations_paths: [db/bus_migrate]`. Same adapter (`sqlite3`),
   `pool: 5`, `timeout: 5000`, `pragmas: { journal_mode: wal }` on both.
   Test env gets both DBs (`db/test.sqlite3`, `db/test_bus.sqlite3`).
2. `app/models/bus_record.rb` (new): abstract, `connects_to database:
   { writing: :bus }`. `application_record.rb` unchanged.
3. `app/models/bus_projection.rb`: parent `ApplicationRecord` → `BusRecord`.
4. `app/services/bus/projector.rb`: read via `ApplicationRecord.connection`
   (journal), write via `BusProjection` (bus DB). Keep `journal absent →
   {count: 0}` fallback so bus boots before BACK migrates.
5. Migrations: `git mv db/migrate/20260903120001_create_bus_projections.rb
   db/bus_migrate/`. Follow-up primary migration `drop_table
   :bus_projections` lands **after** bus DB is proven live, not in the
   same deploy. Regenerate `db/schema.rb` (without the table) + new
   `db/bus_schema.rb`.

### 2. Runtime / deploy

6. `extract/entrypoint.sh` `bus)` branch: wait for `${BUS_DB_PATH}`,
   run `bundle exec rails db:prepare:bus` (never primary `db:prepare`).
7. Both `runtimes/mind-pod/docker-compose.yml` and
   `app/extract/compose.yml`, `bus:` service:
   `environment: { ROLE: bus, PORT: "3000",
   BUS_DB_PATH: /bus-data/bus.sqlite3, DB_PATH: /data/mind_pod.sqlite3 }`
   (`DB_PATH` retained read-only for the v1 source read),
   `volumes: ["bus-data:/bus-data", "mind-data:/data:ro"]`,
   top-level `volumes: { bus-data: {} }`.
   Keep unpublished, same image, `depends_on: [back]`.
8. `spec/spec_helper.rb` + `spec/bus_spec.rb`: establish both connections,
   transactional wrap on both, create `bus_projections` in bus test DB.

### 3. Gates + docs (same PR or `bin/sweep` fails)

9. `tooling/cpcp/check_role_bus.py`: allow `db:prepare:bus`, forbid bare
   `db:prepare`; require `BUS_DB_PATH` + `bus-data` mount; forbid
   `mind-data` rw (allow `:ro` only).
10. `tooling/compose/check_two_writers.py`,
    `config/domain_writers.json:35-38`: bus note "own file `bus-data`,
    stand-in retired"; domain file writers `{back,backjob}`.
11. `check_no_baked_sqlite.py`, `.dockerignore`: cover second sqlite path.
12. Docs: `GAP18.md:41-42`, `COVERAGE_GAPS.md` rows 8/9/16/39/43,
    `ROW8.md` §1/§2/§4 (rebase `grok/gap-8-persist@ab516cf` first),
    ADR 0050-amend-2 "bus does not pick a second sqlite" sentence,
    `seam_authority.json` (bus `domain_writer:false` stays, add store binding).

## Verify

* `bundle exec rspec spec/bus_spec.rb` (both DBs).
* `bin/sweep` green (row-114 pre-push hook).
* `docker compose up bus` + `POST /_cpcp/rpc bus.projection.latest`
  with BACK up, then BACK down (refusal path).
* `down -v` wipes `bus-data`; next `latest` recomputes from BACK journal.

## Run evidence (2026-09-03, `mind-pod:busspec` from `mind-pod-rails-base:latest`)

* `bundle` shim repaired (`gem install bundler`; stale 2.6.9 default shadowed).
* `spec/bus_spec.rb`: **4 examples, 0 failures** in container
  (`docker run --rm -e RAILS_ENV=test --entrypoint bundle ...`
  — bare `docker run` hangs because the image ENTRYPOINT boots the server).
* Full suite: **92 examples, 12 failures** — byte-identical failure list
  to clean-HEAD baseline image (**91 examples, 12 failures**), so all 12
  are pre-existing on `main` in this runner (seed-dependent boundary/p10/
  p11 specs), none from this change. Delta from this change: +1 passing
  example, 0 new failures.
* `bin/sweep`: **88 ok, 0 fail**. Both `docker compose config` valid;
  bus resolves to `bus-data` rw + `mind-data` ro.
* Two spec_helper traps found by running (not by reading): `load` of
  `bus_schema.rb` and `MigrationContext` with a foreign pool both execute
  on the primary connection — specs set up the bus table directly on
  `BusRecord.connection` instead. Production `db:migrate:bus` is unaffected
  (official per-database task).

## Live verification (2026-09-03, `f14529b`, isolated `busverify-*` fixtures)

* BACK (`ROLE=back`) + BUS (`ROLE=bus`, `bus-data` rw + `mind-data` ro)
  from `mind-pod:busspec`, oxigraph for BACK's strict gate. All fixtures
  removed afterwards.
* `bus.projection.latest` → 200; seeded 2 journal rows via BACK runner →
  derived `{grounded:1, received:1, count:2}`. Cross-file read proven.
* File inspection: `bus.sqlite3` holds only `bus_projections`; domain
  `mind_pod.sqlite3` has **no** `bus_projections` table. (Copy the `-wal`
  sibling too — the row lives there until checkpoint.)
* BACK stopped → BUS still 200 with same counts (file-based v1; row 72
  holds — nobody dials anybody).
* Volume deleted + BUS recreated → entrypoint `db:migrate:bus` rebuilt the
  schema on the empty volume and `latest` recomputed count 2. `down -v`
  semantics hold: projections recomputable, journal untouched.
* Side note: `note.create` via the engine seam returned ok but wrote no
  journal row (journal is OSI-admission only) — projection honestly
  reported count 0 before seeding.

## Explicit non-goals

No BACK push to BUS (row 72 stands), no journal split (0052/73 stand),
no `bus_projections` second-table semantics change, no persist build
(row 8 stays scoped-unbuilt), no credential-mount change (0046:85 stands).
