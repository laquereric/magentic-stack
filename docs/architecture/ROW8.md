# Row 8 — `ROLE=persist` is a placement authority that cannot live in the file it moves

> **Built: see [`GAP8.md`](GAP8.md).** This document stays the scope record;
> the refresh note above dates the last measurement.

Measured 2026-09-03 from `6f1686b`; **refreshed same day from `f678413`**
after `f14529b` (BUS owns its sqlite on `bus-data`). **Design only. Not built.**

ADR [0050](../adr/0050-switchyard-is-the-upstream-plus-bus-and-persist-roles.md)
already decided persist owns the write-LOCATION decision, not the data, and
never holds an event. Row [48](COVERAGE_GAPS.md) decided placement covers
every store. This document is the surface those sentences have to be true
against: the sqlite that actually exists, the writers 0056 actually
declared, and the journal that row 17 left inside that file.

No `database.yml`. No compose. No `.agent`. No 0056/0057 amendment.

---

## What is actually there (so the table is not a wish)

SHA `f678413`. Population named per count.

| Thing | Measured |
|---|---|
| Compose services | **10**: back, backjob, bus, front, vault, config, shape, mind, switch, graph. Population: `^  [a-z].*:` under `services:` in `docker-compose.yml`. |
| Entrypoint ROLEs | **7**: back, front, backjob, vault, config, shape, bus. `persist` is the `*)` branch: unknown ROLE, exit 2. |
| `role_routes.json` roles | **7**. No persist key. |
| `domain_writers.json` roles | **7**. persist absent. |
| `seam_authority.json` | **4 live** (back, switchyard-offline, vault, bus). persist is not live and not in `decided_unbuilt`. |
| Images | **4**: `mind-pod`, `mind-pod-mind`, `mind-pod-switch`, oxigraph digest-pinned. Target is already 4. |
| Target | **12 containers, 4 images** (nine Rails ROLEs + MIND + SwitchYard + oxigraph). Today is ten running; persist as an 8th Rails ROLE would be the **11th** container. `project-graph` is still not its own container (row 7). |
| Named volumes | **4**: `mind-data`, `mind-nooa-data`, `bus-data`, `graph-data`. |
| Credential bind mounts | **2**: `.agent/vault:/vault`, `.agent/secrets:/state`. Row 46: convert neither. |

### Files `DB_PATH` actually binds

| Path | Volume | Compose services that set it | Kind (0057) |
|---|---|---|---|
| `/data/mind_pod.sqlite3` | `mind-data` | back, backjob (rw) + **bus (ro source)** × both compose files (**8** `DB_PATH:` lines) | application state (and, today, the journal) |
| `/bus-data/bus.sqlite3` | `bus-data` | bus × both compose files (**2** `BUS_DB_PATH:` lines) | metadata (0057), owned by BUS since `f14529b` |
| `/mind-data/nooa.sqlite3` | `mind-nooa-data` | mind × both compose files (**2** bindings) | ephemeral nondeterministic inference state |

Population: **3 sqlite files**, **8** `DB_PATH:` + **2** `BUS_DB_PATH:` lines across the two compose files. FRONT / vault / config / shape set **neither**. Persist: **no** service, **no** ROLE, **no** volume of its own.

### What lives *inside* `/data/mind_pod.sqlite3`

`schema.rb` version `2026_09_04_000001`. Population: **61** `create_table` calls
(`bus_projections` left for `bus_schema.rb` in `f14529b`).

Among them, two names that rows talk about as if they were stores:

| Name | Table | Who writes (domain_writers.json) |
|---|---|---|
| Domain record | `notes` and the rest of `all_domain` | BACK (`all_domain`); BACKJOB `Reconciliation` + outbox |
| Admission journal | `osi_l8_operation_journal_entries` | BACK (0052/0053; row 73: stays in BACK) |

And one file of its own since `f14529b`:

| Name | File | Table | Who writes |
|---|---|---|---|
| Bus projection | `/bus-data/bus.sqlite3` (`bus_schema.rb`, 1 table) | `bus_projections` | BUS (`writes: ["BusProjection"]`) |

The journal is still a **table in file 1**. A path.set that moves "the event log" without moving `notes` is still not a placement of two stores; it is a schema split that does not exist.

### Other durable things that are not `DB_PATH`

| Thing | Form | Persist-via-0051? |
|---|---|---|
| GRAPH | oxigraph, `graph-data:/data` | **No.** Not SQLite, not `DB_PATH`. Projection of Rails, not authority. |
| Vault | encrypted JSON `/vault/secrets.json` | **No.** Bind mount; row 46. |
| Switch keys | JSON `/state/sources.json` | **No.** Bind mount; row 46. |
| RefusalLog | JSONL, not sqlite | **No.** |

---

## 1. Row 43 after 0056 — one writer per path, or one declared writer-*set*?

Row 43 still reads: "two writers on one file needs a compose edit today" /
"`persist` enforces this as its invariant."

That sentence is **the pre-0056 defect**. Rows 1 and 2 closed by **declaring**
BACK and BACKJOB co-writers on `mind-data` (ADR 0056). `f14529b` then moved
bus to its own file. Measured today: **two declared writers on one path**
(plus bus mounted read-only as a projection source, which is not a writer).

0051 §5 is harsher still: *the closed set must encode single-writer -- no two
roles may be pointed at one path*. Honouring that sentence as persist's
invariant **reopens 0056** and evicts BACKJOB. The brief forbids amending 0056.

SQLite is still one-writer-*at-a-time* (WAL, `timeout: 5000`, row 45's NOOA
session lock on the *other* file). That is a runtime lock, not a placement
rule.

**What row 43 can still mean, without lying:** persist's closed set records
**which declared roles may bind which path**. Domain sqlite: `{back,
backjob}` (rw) + `{bus}` ro-source. Bus sqlite: `{bus}`. MIND's set is
`{mind}` (and NOOA already refuses a second MIND). Persist does **not**
resurrect "one process per file."

That is a declared writer-**set** per path. I am not restating the row. The
row as written is the 0051 §5 sentence, and that sentence is false of the
pod we have.

---

## 2. Three consumers? Three files — and the journal is still a table

Row 48 named three stores: the event log, the Rails domain sqlite, MIND
NOOA. At scope time `bus_projections` sat in the shared `DB_PATH`, so the
section below argued the row over-counted files by one. `f14529b` has
since given BUS its own file, and the count now lands exactly on row 48:

| # | What people call it | What it is |
|---|---|---|
| 1 | Rails domain sqlite | **File** `/data/mind_pod.sqlite3` |
| 1a | "the event log" | **Table** `osi_l8_operation_journal_entries` **in file 1** |
| 2 | `bus_projections` | **File** `/bus-data/bus.sqlite3` since `f14529b`. Own *writer* (BUS) **and** own file. |
| 3 | MIND NOOA | **File** `/mind-data/nooa.sqlite3` |

The remaining over-count is 1a: the journal is a table in file 1, not a
path. The closed set 0051 needs is a set of **paths**, and today there
are **three** sqlite paths. Treating the journal as a fourth path is a
schema split nobody has decided — 0052/73 keep it in BACK.

Oxigraph / vault / switch are real durable places and **out of 0051's
SQLite sentence**. Row 48 said every store; 0051 said `DB_PATH` for
SQLite. Those are not the same population. I will not collapse them.

---

## 3. MIND is not boot-only — persist's model cannot pretend it is

ROW41 already measured this. Re-measured at `f678413` (unchanged):

- `mind_agent.py:67` — `os.environ.get("DB_PATH")` **inside** `_storage()`
- `mind_agent.py:140` — `MindCognition(storage=_storage())` on every `build_agent`
- `harness.py` calls `build_agent` every cognition cycle (ROW41: `harness.py:114`)

Rails ERB is boot-once (`database.yml` `ENV.fetch`). BACKJOB's wait loop
is start-once. MIND will **follow a mutated env without a restart**.

Docker does not mutate a running container's env. That is not a reason to
write "everyone binds at boot" into persist. A persist that records
next-boot placement and assumes MIND will not see a live env change is
wrong for MIND on day one. The honest control for MIND is still a
**restart** (ROW41 S2); the honest *reader* is per-cycle. Persist's
receipt is "what the next process start will bind," not "what this
process currently has open."

---

## 4. Continuity's pointer cannot live in the file being left

ROW41 §5: after declining RES, "continuity from the event log" names
BACK's journal, **inside** `/data/mind_pod.sqlite3`. Moving that path
leaves the journal in the file you walked away from.

If persist is "just another Rails ROLE" on `mind-data`, its own AR table
(`persist_placements`, or whatever) is **the same file**. The next-boot
pointer and the boot receipt then die with the swap they are supposed to
explain. That is the 0051 §3 paradox, now with persist sitting in the
old store.

**Finding, not a solution:** persist's placement ledger **cannot be a
table in the domain sqlite.** A ROLE that only `db:prepare`s onto
`mind-data` cannot hold the record 41 said had to live outside the file
being left.

Where, then? Named, not chosen:

| | Where | Cost |
|---|---|---|
| **A. Persist-owned sqlite on its own volume** | A fourth sqlite file (`f14529b` is the precedent: BUS got `BUS_DB_PATH` on `bus-data` the same way). | Persist placing persist is a new bootstrap. Closed set must include persist's own path, which persist is the authority for. |
| **B. Non-sqlite file on a persist volume** (JSON, like vault, but a **named** volume — not a credential) | Matches "never holds an event"; no AR. | New durable format. Who signs it? Not vault (wrong store). |
| **C. Compose remains the record** | Status quo. | Persist is a checker of compose, not an authority. 0051's "stops being a deploy-time constant" is then false. |
| **D. Sibling env rewritten over RPC** | No. | No process in this tree can set another's env. MIND has no inbound CPCP (row 10). |

I would rather see A vs B named than pick B because it looks like vault.
Vault is a bind mount *because keys survive `down -v`*. Placement is not
a credential; a named volume that dies on `down -v` may be the honest
ephemerality, or it may erase the only record of where the domain file
went. That is an owner call about **what a `down -v` is allowed to
forget**.

---

## 5. Effect surface (candidate, not minted)

0051: control of `DB_PATH` moves to `/_cpcp` effects. No method is named.
Who may call is **not decided** (0051 "Not decided here").

Until persist exists there is **no honest server** (ROW41). A BACK
always-refuse method fake-enforces 0051. Do not.

| | Candidate | Not this document |
|---|---|---|
| Server | `ROLE=persist`, `POST /_cpcp/rpc`, own controller (not the engine — `note.create` is BACK's). Same shape as vault/bus/shape. | Whether that is an 11th container. |
| Write | `persist.path.set` `{ "store": <id>, "path": <closed-set member> }` — records **next-boot** placement. A request that would change a **running** process's open file is refused (ROW41 S1). | The store-id vocabulary (`BUS_DB_PATH` is the naming precedent; must not invent a fourth sqlite path for the journal). |
| Read | `persist.path.get` `{ "store": <id> }` — the recorded placement, not `ENV` of some other container. | Whether config-admin displays it. |
| Caller | Named, explicit operation (0051, 0046 pattern). | Who. Not "any seam holder." Not MIND (no inbound). |

Restart is operational (compose), not an RPC. Persist records intent.
ERB / entrypoint / MIND bind at **process start**. MIND's per-cycle
re-read means a live env mutation would also bind; persist must not
rely on mutating env, and must not assume MIND is boot-only.

---

## 6. ROLE on the Rails image, or something smaller?

| | Shape | Cost |
|---|---|---|
| **A. 8th Rails ROLE, 11th container** | `ROLE=persist` in entrypoint, `role_routes.json`, unpublished `:3000`, image `mind-pod`. Language: ruby (0047 default). | Hits the 12-container target only after `project-graph` is also a container (row 7). Adds a CPCP seam (live 4 → 5) if it serves `/_cpcp/rpc`. |
| **B. No new container: a library BACK calls** | Smaller. | BACK becomes the placement authority. Row 8 forbade that. |
| **C. A file writer with no HTTP** | Smaller still. | No governed effect, no `operationId`, no receipt. Not 0051. |

**v1, if built, is A for the process and B-for-the-ledger-file is the
trap in §4.** The ROLE can be Rails. The **ledger** cannot be the
domain sqlite. Those are different axes — same as 0057's placement vs
ownership, applied to persist itself.

I do not take the container-count change.

---

## 7. What 0051 and 0057 need (I will not amend them)

| ADR | Need | Not mine |
|---|---|---|
| **0051** | Stays whole `unenforced` until persist exists and is gated. `unenforced_because` already names row 8. **§5's "no two roles at one path" is false of today's compose** (back+backjob share the domain file, bus mounts it ro). Striking it is an amendment. | Whether to withdraw §5. |
| **0057** | Three kinds still hold. Placement does not change WHO writes. BUS "via RES" is already retracted by 0050 amendment 2; metadata today is `bus_projections`, still 0057-metadata, still not persist's content. **Do not retarget `mind-nooa-data` on the strength of "ephemeral."** | Volume form. |

---

## 8. What rows 39, 41, 43 become

| Row | After this document |
|---|---|
| **39** | Still prerequisite, still unbuilt. The closed set is **paths** (and the declared roles that may bind each). Today that is **three** sqlite paths (domain, bus, mind). Contents of the set are an owner decision. A path for "the journal" that is not the domain sqlite is a schema split, not a persist feature. |
| **41** | Still blocked on persist *existing*, not on this scope. Live swap refused. Next-boot record **outside** the file being left — which, given §4, means persist's ledger is not an AR table on `mind-data`. |
| **43** | Reframed: persist enforces the **declared writer-set per path**, not single-writer-process. The sets are now clean — domain `{back, backjob}` + ro `{bus}`, bus `{bus}`, mind `{mind}`. Building 43 as "reject any set with more than one role" would undo 0056 (evict BACKJOB). |

---

## 9. Owner decisions this document will not take

| Decision | Why it is not mine |
|---|---|
| Whether to **build** persist now | Brief. |
| The closed set's **actual contents** | Row 39. |
| Any **container-count** change (11th vs wait for 12) | Target is 12; I will not spend the 11th. |
| A vs B in §4 (persist sqlite vs JSON file) | New bootstrap vs new format. |
| What `down -v` may forget about placement | Named-volume vs bind-mount for persist's ledger. |
| Who may call `persist.path.*` | 0051 left it open. |
| Whether to withdraw 0051 §5 | Amendment. |
| Whether the journal splits from the domain sqlite | 0052/73; not persist. |
| `project-graph` as the 12th container | Row 7. |
| Amending 0056 / 0057 | Brief. |
| Touching `.agent/*`, `database.yml`, compose | Brief. |

The consume-vs-rewrite call for SwitchYard was 0050. The equivalent
here is already answered: **placement authority, not a storage engine.**
This document answers *where that authority cannot live* (inside the
sqlite it moves) and *what row 43 cannot mean* (one process per path)
without taking those owner lines.

---

## 10. What this is not

- Not a ROLE. Not a port. Not a compose service. Not a method.
- Not the bus split (that built as `f14529b`, outside this scope).
- Not a BACK always-refuse stand-in for 0051.
- Not a volume change for `mind-nooa-data`.
- Not an amendment of 0051 §5, 0056, or 0057.
- Not row 41's build. Not row 39's list.
