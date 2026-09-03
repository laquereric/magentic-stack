# Gap 8: `ROLE=persist` exists — placement authority with its own file

Built at SHA of this change. Scope was [`ROW8.md`](ROW8.md) (refreshed
post-`f14529b`); this is the build findings.

## 1. What was built

`ROLE=persist` on the shared Rails image, 11th container: own `POST
/_cpcp/rpc` on `PersistCpcpController` (not the engine — `note.create` is
BACK's; stock `RpcController` is all-200), own sqlite on the `persist-data`
named volume (`PERSIST_DB_PATH`), third Rails database
(`PersistRecord` / `db/persist_migrate`). It mounts **no** domain store —
the ledger cannot live in the file it places (ROW8 §4, option A; the
`BUS_DB_PATH` pattern is the precedent).

Two methods, allowlisted callers (`PERSIST_CALLERS`, 0046 pattern —
`{id: {token, operations}}`, empty fails closed at boot):

| Method | Contract |
|---|---|
| `persist.path.set` `{store, path}` | Unknown store → 400 `unknown_store`; path outside the closed set → 400 `unknown_path`. Else upserts the next-boot intention `{path, set_by, recorded_at}` → 200 with `live_applied:false, effective:next_boot`. Idempotent. |
| `persist.path.get` `{store}` | Unknown store → 400. Else 200 `{recorded, path, set_by, recorded_at}`; unrecorded stores report `recorded:false` (compose default governs). |

Auth: missing/unparseable callers → 500 (server misconfig, vault pattern);
no/wrong token → 401; token without the op → 403. All refusals non-200
plus envelope (row 49 KEEP BOTH).

## 2. The row-41 refusal, structurally

ROW41 S1 forbids an effect that would change a running process's path.
`path.set` never applies anything — restart does (compose) — so there is
no live swap to refuse. The refusal half is admission: open-set paths are
refused, and every success says `live_applied:false` so no reader can
mistake a recording for an application.

## 3. Single source for the closed set

`config/store_bindings.json` moved here from `tooling/compose/` (row 39's
file): the controller reads the same file `check_store_bindings.py`
enforces, with the persist store as 4th member. `database.yml` host
defaults are not members — only container paths are governed.

## 4. Gates

* `check_role_persist.py` (13 examined): own-controller seam, own-DB
  migrate, fail-closed callers, unpublished, own volume, no domain mount,
  writers `[PersistPlacement]`, BACK never dials persist. Plants: engine
  mount, back-dials, primary prepare, missing db path, domain mount.
* `check_store_bindings.py` extended generically (`PERSIST_DB_PATH` var,
  per-store volumes) — the 4th store rode the existing gate, plus
  `role_routes.json`, `seam_authority.json` (live, not a writer), and the
  `cpcp_callers.json` census (server + spec entries).
* `PERSIST_CALLERS` dummy added to the role-routes dump env so the
  fail-closed boot does not break route dumping.

## 5. What this does not settle

* **Row 41 stays next, unblocked** (was: blocked on persist existing): the
  record half exists; remaining is caller wiring (no production client
  yet — same position bus held at GAP18 §4), first real placement, and
  the restart that applies one.
* **Row 48 stays decided-unbuilt**: row 43's invariant is enforced by the
  static sweep gate, not by persist at runtime.
* **0051 §5** amended to writer-set language (0051 amendment, 2026-09-03);
  0051 stays partial (closed set + serving ROLE gated, effect application
  still operational).
* Config-admin is persist's first caller (GAP41): placements UI records
  next-boot intentions from the closed set. No production placement has
  been applied yet; that is operational.

## 6. Traps found by running

* **Migration timestamps must be <= now+1day on every clock** (Rails
  `valid_migration_timestamp?`). A `20260905` stamp written on Sep 03
  kills first boot with `InvalidMigrationTimestampError` — and the failed
  boot can leave the table behind without recording the version, so the
  next boot fails differently (`already exists`). Fix was a same-day
  stamp; a poisoned volume is wiped, never repaired in place.
* **`Schema.define` and `MigrationContext` follow the primary
  connection**, never the pool handed in — same trap as the bus specs.
  Specs set up the persist table directly on `PersistRecord.connection`;
  production `db:migrate:persist` is unaffected.
