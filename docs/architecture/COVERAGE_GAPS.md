# Gap analysis

Measured 2026-08-31 at `ce4296c`. Doctrine: ADR 0046 (vault separate), 0047 +
amendments (three languages, container boundaries, one Rails app many ROLEs),
0048 (MIND serves a CPCP seam), 0049 (ROLE=shape from mounted gems), 0050
(SwitchYard is the upstream; bus and persist are Rails ROLEs).

**Target: 12 containers, 4 images.** One Rails application under **nine** ROLEs,
plus MIND (Python), SwitchYard (NVIDIA Rust + a CPCP endpoint), and oxigraph.

## 1. Containers

| # | Container | Image | Today | Gap | State |
|---:|---|---|---|---|---|
| 1 | `back` | Rails | `ROLE=back`, sole domain writer, draws `/_cpcp` | shares `mind-data` with `backjob`, so sole-writer is not physically enforced | partly done |
| 2 | `backjob` | Rails | `ROLE=backjob`, CPCP completion works | mounts `mind-data`; `bin/backjob:37 Reconciliation.create!` writes domain rows directly | **owner decision** |
| 3 | `front` | Rails | `ROLE=front`, route-gated off `/_cpcp` | served the write seam until `0a7d67f`; historical exposure not established | done / 1 question |
| 4 | `vault` | Rails | `ROLE=vault` landed `968d3cd` | nothing consumes it yet | ready |
| 5 | `config-admin` | Rails | does not exist | build as `ROLE=config`; the **only** published port; inherits catalogue/discovery/verify if they have no upstream home (row 15) | **next** |
| 6 | `shape` | Rails | does not exist | no shape HTTP surface exists anywhere; design against ADR 0045's list | open |
| 7 | `project-graph` | Rails | does not exist | `Storable` projection unwired, so `graph` comes up empty | open |
| 8 | `persist` | Rails | does not exist | **new (0050)**; scope beyond the event repository is unstated | open |
| 9 | `bus` | Rails | does not exist | **new (0050)**; Rails Event Store + CPCP interface | open, blocked by 16, 17 |
| 10 | `mind` | Python | CPCP **client** only: `CMD ["harness.py"]`, no `EXPOSE`, no inbound surface | must serve `/_cpcp/rpc`, map NOOA push/pull | **blocked by 14** |
| 11 | `SwitchYard` | NVIDIA Rust + CPCP endpoint | **Node**: 17 `.mjs`, 350-line `server.mjs`, two ports one process | replace with the upstream proxy; add a CPCP endpoint | **blocked by 15, 18, 19** |
| 12 | `graph` | oxigraph, third-party | running, digest-pinned, **empty** | exemption from the language rule is assumed, not written | open |

## 2. Cross-cutting gaps

| # | Gap | Measured today | Blocks | State |
|---:|---|---|---|---|
| 13 | **CPCP has no language-neutral specification** | `rails-cpcp` is a Rails engine; no schema, no protocol doc, no conformance suite. The contract IS the Ruby implementation | MIND (10), SwitchYard's endpoint (11), the bus interface (9) | **prerequisite** |
| 14 | MIND's seam has no spec to conform to | — | row 10 | = row 13 |
| 15 | **SwitchYard parity: catalogue, discovery, verification** | `catalog.mjs`, `discovery.mjs`, `verify.mjs` have **no described upstream equivalent** | replacing the Node service | **owner decision** |
| 16 | **Bus vs persist: RES *is* a repository** | memo 0830d says the bus must not own the durable repository; RES writes events to a DB | rows 8, 9 | **owner decision** |
| 17 | **`rails_event_store` is a new dependency** | **zero hits** in the repo; adoption, not relocation | row 9 | open |
| 18 | **The CPCP endpoint's language, and do-not-fork** | ADR 0038 + the `adapters-sole-path-to-upstreams` gate forbid patching upstream; `gems/adapters/` contains **one file, a README** | row 11 | **owner decision** |
| 19 | **Upstream is pre-alpha by its own README** | "experimental… not for production use"; API expected to change before v1.0 | row 11 | **accepted risk?** |
| 20 | **Four CPCP seams; authority stated for one** | BACK, MIND, SwitchYard, bus. Every "the seam is the only write path" sentence predates the second | reading the invariant literally | **owner decision** |
| 21 | Route-gating is not CI-gated | `routes.rb` gates by ROLE and rspec covers it; no checker, no workflow | every future ROLE — and there are now five to add | **next** |
| 22 | `osi.example` is unresolvable | 11 shapes resolve under `https://osi.example/shapes/...` | becomes externally visible when `shape` SERVES | open |
| 23 | Shape payload part-migrated | 7 TTL moved; **52 remain** in `osi-level-8-profiles`; arc step 10 unrun | what `shape` serves | open |
| 24 | FRONT historical exposure | unknown whether anything was ever admitted through FRONT's `/_cpcp` | nothing structural; a durable-state question | open |

## 2b. DB_PATH as a CPCP effect (ADR 0051)

| # | Gap | Measured today | Blocks | State |
|---:|---|---|---|---|
| 39 | **The path parameter must be a CLOSED set** | none exists; `DB_PATH` is a free-form env string read once by ERB | the whole ADR -- an open string parameter is an arbitrary-file-write primitive reaching other containers' stores and the vault bind mount | **prerequisite** |
| 40 | **Boot-time resolution; a change is a reconnect** | `database.yml` evaluates `ENV.fetch("DB_PATH")` in ERB at load; consumers also in `entrypoint.sh` (x2) and `spec_helper.rb` | quiesce/swap/resume semantics and in-flight request behaviour are undefined | open |
| 41 | **The bootstrap paradox** | CPCP records operations in the database being changed | the audit chain at the moment of the swap; needs the receipt in BOTH stores under one `operationId` | **owner decision** |
| 42 | **MIND has a SQLite it does not bind** | `nooa/storage/sqlite.py` ships `SQLiteStorageManager` with schema, session lock and WAL sidecars, but `db_path` **defaults to `":memory:"`**; our code never passes one; the `mind` service has **no `volumes:`** | binding it is the change -- not adding a database. Today NOOA state is ephemeral and invisible | open |
| 45 | **NOOA already enforces single-writer** | `_acquire_session_lock` + `SessionAlreadyActiveError` | gap 43 should ADOPT this mechanism, not grow a parallel one | open |
| 46 | **A path is a file triple, on a hazardous mount** | WAL mode adds `-wal`/`-shm`; `delete_sqlite_database` unlinks all three. NOOA ships `_is_virtiofs` because SQLite misbehaves on Docker Desktop sharing, and ADR 0046 requires a **bind mount** for `down -v` survival | the closed set (39) enumerates triples; mount type is a decision | **owner decision** |
| 47 | **MIND's system prompt becomes false** | `mind_agent.py` instructs the agent "You never persist anything" and "there is no write path for you at all" | this is inside the SYSTEM PROMPT, not documentation -- a MIND carrying memory while told it persists nothing is an inconsistency in the cognition layer. Rewrite in the same change, or do not bind | **prerequisite** |
| 43 | **Row 1 becomes reachable at runtime** | two writers on one file needs a compose edit today | once settable, it is an available operation; the closed set must encode single-writer and a checker must prove it | **prerequisite** |
| 44 | **Does `ROLE=persist` survive?** | gap 16 stalls because SQLite has no server | governing the BINDING may reach the same goal without a storage-engine migration | **owner decision** |

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
| 2 | **Row 5** — `config-admin` | gives `vault` its first caller and closes the credential-entry path |
| 3 | **Row 13** — extract a CPCP contract + conformance suite | one prerequisite blocking three seams (10, 11, 9) |
| 4 | **Rows 16, 18** — bus/persist ownership, and the endpoint's language | both owner decisions; each blocks a new container |
| 5 | **Row 2** — the backjob writer boundary | still the only **live** correctness defect on this list |
