# Gap analysis

Diagrams and per-container detail: [`ContainerTopology.md`](ContainerTopology.md).

Measured 2026-08-31 at `030af95`. Doctrine: ADR 0046 (vault separate), 0047 +
amendments (three languages, container boundaries, one Rails app many ROLEs),
0048 (MIND serves a CPCP seam), 0049 (ROLE=shape from mounted gems), 0050
(SwitchYard is the upstream; bus and persist are Rails ROLEs).

**Target: 12 containers, 4 images.** One Rails application under **nine** ROLEs,
plus MIND (Python), SwitchYard (NVIDIA Rust + a CPCP endpoint), and oxigraph.

Row numbers are stable across revisions so they can be cited; the DB_PATH block
(39-47) was inserted later and therefore sits out of sequence.

## 0. Rollup

| State | Rows | Meaning |
|---|---|---|
| **prerequisite** | 13/14, 21, 39, 43 | blocks other work; do these first |
| **owner decision** | 2, 15, 16, 18, 20, 41, 44, 46 | needs your call, not more analysis |
| **next** | 5, 21 | briefed or briefable now |
| ready | 4 | built, waiting on a consumer |
| open | 6, 7, 8, 9, 10, 11, 12, 17, 19, 22, 23, 40 | known, unscheduled |
| closed today | 3, 24, 42, 47 | FRONT `/_cpcp` gated; historical exposure unrecoverable; NOOA store bound |

## 1. Containers

| # | Container | Image | Today | Gap | State |
|---:|---|---|---|---|---|
| 1 | `back` | Rails | `ROLE=back`, sole domain writer, draws `/_cpcp` | shares `mind-data` with `backjob`, so sole-writer is not physically enforced | partly done |
| 2 | `backjob` | Rails | `ROLE=backjob`, CPCP completion works | mounts `mind-data`; `bin/backjob:37 Reconciliation.create!` writes domain rows directly | **owner decision** |
| 3 | `front` | Rails | `ROLE=front`, route-gated off `/_cpcp` | served the write seam until `0a7d67f`; historical overlay gone — see row 24 | done |
| 4 | `vault` | Rails | `ROLE=vault` landed `968d3cd`, bespoke REST | **inbound edge becomes a CPCP contract, TBD (0046 amendment 2)** — must land BEFORE `config-admin`, which is its first caller | rework pending |
| 5 | `config-admin` | Rails | does not exist | build as `ROLE=config`; the **only** published port; inherits catalogue/discovery/verify if they have no upstream home (row 15) | **next** |
| 6 | `shape` | Rails | does not exist | **DESIGN** [`ROLE_SHAPE.md`](ROLE_SHAPE.md). v1 is retrieval of the 7 moved TTL files by digest under `/_cpcp` GET; the other five 0045 items are not in the gems. Not built | design ready |
| 7 | `project-graph` | Rails | does not exist | `Storable` projection unwired, so `graph` comes up empty | open |
| 8 | `persist` | Rails | does not exist | **SCOPED (0050 amendment).** Owns the write-LOCATION decision, not the data. Holds the closed path set of row 39 and enforces row 43 | open, scoped |
| 9 | `bus` | Rails | does not exist | **SCOPED (0050 amendment).** Implements RES: event log content, streams, append, pub/sub, CPCP interface. Does not decide where it is written | open, blocked by 17 |
| 10 | `mind` | Python | CPCP **client** only: `CMD ["harness.py"]`, no `EXPOSE`, no inbound surface | must serve `/_cpcp/rpc`, map NOOA push/pull | **blocked by 14** |
| 11 | `SwitchYard` | NVIDIA Rust + CPCP endpoint | **Node**: 17 `.mjs`, 350-line `server.mjs`, two ports one process | replace with the upstream proxy; add a CPCP endpoint | **blocked by 15, 18, 19** |
| 12 | `graph` | oxigraph, third-party | running, digest-pinned, **empty** | exemption from the language rule is assumed, not written | open |

## 2. Cross-cutting gaps

| # | Gap | Measured today | Blocks | State |
|---:|---|---|---|---|
| 13 | **CORRECTED.** The shapes ARE the language-neutral spec | `grounding.rb:123`: "The shapes are the specification and CI runs pyshacl over them with fixtures"; the Ruby is a deliberate hand-written reproduction because `mm-shacl-reader` is not wired in-process. `pyshacl` is already pinned | what is missing is **distribution**, not authorship -> row 6 | reframed |
| 14 | ~~Behavioural contract is Ruby-only~~ | **WRITTEN** at `55dbd82`: `ContainerTopology`'s companion `CPCP_BEHAVIOUR.md` — 324 lines, 63 `file:line` citations, **16 SPECIFIED vs 38 OBSERVED**, plus what could not be determined | — | closed |
| 15 | **SwitchYard parity: catalogue, discovery, verification** | `catalog.mjs`, `discovery.mjs`, `verify.mjs` have **no described upstream equivalent** | replacing the Node service | **owner decision** |
| 16 | ~~Bus vs persist~~ | **CLOSED.** BUS implements RES; PERSIST determines the filesystem write location for the Event Store. Departs from memo 0830d deliberately — that memo reasoned about a Rust router holding credentials; the premise moved | — | closed |
| 17 | **`rails_event_store` is a new dependency** | **zero hits** in the repo; adoption, not relocation | row 9 | open |
| 18 | **The CPCP endpoint's language, and do-not-fork** | ADR 0038 + the `adapters-sole-path-to-upstreams` gate forbid patching upstream; `gems/adapters/` contains **one file, a README** | row 11 | **owner decision** |
| 19 | **Upstream is pre-alpha by its own README** | "experimental… not for production use"; API expected to change before v1.0 | row 11 | **accepted risk?** |
| 20 | **FIVE CPCP seams; authority stated for one** | BACK, MIND, SwitchYard, `bus`, and now `vault`. Every "the seam is the only write path" sentence predates the second | reading the invariant literally | **owner decision** |
| 21 | ~~Route-gating not CI-gated~~ | **CLOSED.** `check_role_routes.py` boots each ROLE and diffs the DRAWN table against `role_routes.json`; roles discovered both-ways from `entrypoint.sh` + both composes. 4 boots, ~5s | — | closed, see 51 |
| 22 | `osi.example` is unresolvable | 11 shapes resolve under `https://osi.example/shapes/...` | becomes externally visible when `shape` SERVES | open |
| 23 | Shape payload part-migrated | 7 TTL moved; **52 remain** in `osi-level-8-profiles`; arc step 10 unrun | what `shape` serves | open |
| 24 | ~~FRONT historical exposure~~ | **CLOSED.** Reachable until `0a7d67f` (extract compose published FRONT `:13000`, routes mounted `/_cpcp` for every ROLE, image baked a writable sqlite). FRONT overlay `/rails/db/mind_pod.sqlite3` is gone with the containers. Image sqlite is the Aug 19 host snapshot, not a FRONT overlay. Volume `mind-pod-demo_mind-data` is BACK. Findings: [`GAP24_FRONT_CPCP.md`](GAP24_FRONT_CPCP.md) | — | closed |
| 49 | **Vault refusals vs the never-raise envelope** | vault answers HTTP 401/403; CPCP answers `{ok:false, reason:, because:}` with 200. A credential broker that returns 200 to a refused read is harder to monitor and easier to mishandle | vault's CPCP contract | **owner decision** |
| 50 | **Contract-before-caller sequencing** | `config-admin` is next on the critical path and is vault's first caller; built today it targets REST, built later it targets CPCP | building `config-admin` twice | **next** |
| 51 | ~~Route gate excludes `/rails*` by path string~~ | **CLOSED** at `02e59a2`, and closed harder than briefed: the path-prefix skip is GONE, not made provenance-based, and any `skipped` entry is now itself a FAIL. My plant `GET /rails/backdoor` on `vault` -> `vault extra GET /rails/backdoor`, exit 1 | — | closed |
| 52 | ~~A P6 denial is stored as `admitted`~~ | **CLOSED** at `6803c72`. Column dropped; admission derived from the journal in three states + an `indeterminate` alarm. Verified in SQL on the real host DB: `cid:sha256:cb841fdf` journals `received,grounded,refused` while the column said `admitted` — column predicate selected 4, journal derivation selects 3 | — | closed |
| 53 | ~~Two replay body shapes for one write~~ | **CLOSED** at `53f98e2`. One replay document for any PUSH replay, compact (absent cids omitted); first success stays domain-shaped. Caller analysis covered all nine; none break | — | closed |
| 54 | ~~Invalid JSON becomes `unknown_operation`~~ | **CLOSED.** `empty_body` and `unparseable_json` are now distinct refusals, specified as != `unknown_operation` | — | closed |
| 55 | ~~Dispatcher retry reports `replayed:false`~~ | **CLOSED** with 53 — same defect, the frozen first response | — | closed |
| 56 | ~~`l8.execution.complete` rows have an empty journal~~ | **CLOSED** at `f1dab59` (ADR 0053). Complete rows journal themselves — `received` at creation, `completed` after the receipt. Additive: parent journals verified unchanged (7 entries before and after). Still `not_an_admission`; `NOT_AN_ADMISSION_NAMES` untouched; indeterminate still 0 | — | closed |
| 57 | ~~2 historical rows unclassifiable~~ | **CLOSED.** Backfilled `authorized` entries carrying `backfill:true`, `not_a_p6_permit:true`, the reason, ADR 0052 and a timestamp — a reader can always tell P6 never saw them | — | closed |
| 58 | ~~`indeterminate` must stay empty~~ | **CLOSED.** `check_admission_indeterminate.py` gates it; the migration itself refuses to drop the column when the count is non-zero, and writes the gate artifact BEFORE aborting | — | closed |
| 59 | **The CPCP seam already has Python and JS callers** | `rails-cpcp/front/app.py`, `mind/harness.py`, and `switchyard-offline` (which SERVES its own `/_cpcp`). Nine callers across three languages | ADR 0048 treated a non-Ruby implementation as a FUTURE risk; it is present tense. Envelope changes must carry a caller analysis | open, informational |
| 60 | **The app image bakes local dev databases** | no `.dockerignore` under `runtimes/mind-pod/app`, and the Dockerfile does `COPY . .`. `db/*.sqlite3` is gitignored but present — 3 files, ~2.7MB — so every build ships them. Confirmed identical `sha256:fc8dc54d` across `mind-pod:demo`, `:latest`, `:thin`, carrying 5 operation_requests and 19 journal rows | every container starts with someone's dev data on disk; the artifact carries state it should not | **next** |
| 61 | Stale host-facing docs point at FRONT's `/_cpcp` | `QUICKSTART.md` curls `localhost:13000/_cpcp`; `.threedot/cid.json` has `backUrl localhost:13000`; the Makefile demo waits on `:13000`; extract compose still does not publish BACK | those all 404 now that FRONT is route-gated — the docs describe a path that was the defect | open |

## 2b. DB_PATH as a CPCP effect (ADR 0051)

| # | Gap | Measured today | Blocks | State |
|---:|---|---|---|---|
| 39 | **The path parameter must be a CLOSED set** | none exists; `DB_PATH` is a free-form env string read once by ERB. **`persist` now holds this set** (0050 amendment) | ADR 0051 | **prerequisite**, owner = `persist` |
| 40 | **Boot-time resolution; a change is a reconnect** | `database.yml` evaluates `ENV.fetch("DB_PATH")` in ERB at load; consumers also in `entrypoint.sh` (x2) and `spec_helper.rb` | quiesce/swap/resume semantics and in-flight request behaviour are undefined | open |
| 41 | **The bootstrap paradox** | CPCP records operations in the database being changed | the audit chain at the moment of the swap; needs the receipt in BOTH stores under one `operationId` | **owner decision** |
| 42 | ~~MIND has a SQLite it does not bind~~ | **DONE.** `DB_PATH` binds `SQLiteStorageManager`; unset keeps NOOA's `:memory:` default. Named volume `mind-nooa-data` in both composes | — | closed |
| 43 | Row 1 becomes reachable at runtime | two writers on one file needs a compose edit today | **`persist` enforces this** as its invariant, rather than every caller | **prerequisite**, owner = `persist` |
| 44 | ~~Does `ROLE=persist` survive?~~ | **CLOSED. Yes.** Placement authority is a job it can do without a database server — which is what "persist owns physical storage" foundered on | — | closed |
| 45 | **NOOA already enforces single-writer** | `_acquire_session_lock` + `SessionAlreadyActiveError` | gap 43 should ADOPT this mechanism, not grow a parallel one | open |
| 46 | **A path is a file triple, on a hazardous mount** | WAL mode adds `-wal`/`-shm`; `delete_sqlite_database` unlinks all three. NOOA ships `_is_virtiofs` because SQLite misbehaves on Docker Desktop sharing, and ADR 0046 requires a **bind mount** for `down -v` survival | the closed set (39) enumerates triples; mount type is a decision | **owner decision** |
| 47 | ~~MIND's system prompt becomes false~~ | **DONE.** Prompt rewritten and the store bound in the same change: "you never persist anything" -> a WHAT YOUR OWN MEMORY IS, AND IS NOT section; memory is private and is not evidence | — | closed |
| 48 | **Is `persist` the placement authority for EVERY store, or only the event log?** | the decision names the Event Store; ADR 0051 makes `DB_PATH` an effect for every Rails container and MIND (domain SQLite, NOOA memory) | scope of `persist`; the closed set in row 39 | **owner decision** |

## 3. Outside the language rule

| # | What | Count | Status |
|---:|---|---:|---|
| 25 | Python release gates under `tooling/` | 23 | **carve-out adopted**: "`tooling/` is Python until rewritten" |
| 26 | Python validators in `gems/osi-level-8-profiles` | 4 | same carve-out |
| 27 | Shell: `bootstrap`, `build-baselines`, `docker-containers`, `prereq` | 4 | outside all three languages |
| 28 | CI workflows (YAML) | 11 | not covered; they **invoke** the Python gates |
| 29 | `runtimes/effect-plane` | 1 gem | no container assigned |
| 30 | `mmg-blob` / `vv-blob` | 2 gems | blob storage has no owner |

## 4. Browser carve-out (not violations)

| # | What | Why JS |
|---:|---|---|
| 31 | `gems/switchyard-offline` | Chrome MV3 extension; the one gem with **no gemspec** |
| 32 | `gems/vv-html-components` | web components |
| 33 | `rails-osi-level-8/.../ux-host-layout.js` | browser asset |
| 34 | `config-admin`'s UI, once it exists | runs in a browser |

## 5. Accepted costs and dead prose

| # | Item | Source |
|---:|---|---|
| 35 | Hot-patch granularity is 4 units, not 12 | 0047 amendment 1 |
| 36 | ADR 0046 keeps its network/mount/allowlist boundary but loses image isolation | 0047 amendment 1 |
| 37 | `mind_agent.py:58` "There is no second socket, and there is no write path for you" — now false | 0048 |
| 38 | Every "`/_cpcp` is the ONLY write path" comment — now false; means *BACK is the only writer of domain state* | 0050 |

## Critical path

| Order | Do | Why |
|---:|---|---|
| 1 | **Row 21** — route-gate checker | five new ROLEs are coming; the invariant must be enforced before they land, not after |
| 2 | **Row 4/50** — define vault's CPCP contract | `config-admin` is its first caller; defining after building means writing the caller twice |
| 2b | **Row 5** — `config-admin` | gives `vault` its first caller and closes the credential-entry path |
| 3 | **Row 6** — build `ROLE=shape` v1 per [`ROLE_SHAPE.md`](ROLE_SHAPE.md) | design is in; the shapes ARE the spec; serving them is how MIND and SwitchYard conform (row 13) |
| 3b | **Row 14** — write down the behavioural half | payload validation is free; envelope, idempotency and the method registry are not |
| 4 | **Rows 16, 18** — bus/persist ownership, and the endpoint's language | both owner decisions; each blocks a new container |
| 5 | **Row 2** — the backjob writer boundary | still the only **live** correctness defect on this list |
