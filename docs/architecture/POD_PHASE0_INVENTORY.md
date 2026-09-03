# Pod Phase 0 inventory

Status: **INVESTIGATE ONLY. No compose changes, no renames, no PERSIST, no
VAULT, no bus.** Started from magentic-stack `ce909fa`. Read
`docs/archive/reviews/2026-08-30c-pod-repartition-persist-vault-manus.md` Phase 0.

Confidence labels used below:

| label | meaning |
|---|---|
| **read the code** | claim cites a source line that does the thing |
| **inferred from config** | claim is what compose/env would do if the process boots as written |
| **unresolved** | not established; says what would settle it |

Do not treat this as authorization to change containers.

---

## FINDING 1 — BACKJOB actually writes SQLite

**Answer: yes. Not merely able to. The worker process issues ActiveRecord
INSERTs against `DB_PATH`.** Confidence: **read the code**.

Boot path:

1. Compose sets `ROLE: backjob`, `DB_PATH: /data/mind_pod.sqlite3`, and mounts
   `mind-data:/data` (`runtimes/mind-pod/docker-compose.yml` lines 33–37).
2. Image entrypoint, `ROLE=backjob`: waits for the sqlite file, then
   `exec bundle exec ruby bin/backjob`
   (`runtimes/mind-pod/app/extract/entrypoint.sh` lines 17–20).
3. `bin/backjob` loads the full Rails environment
   (`runtimes/mind-pod/app/bin/backjob` line 4: `require_relative "../config/environment"`).
4. `config/database.yml` lines 1–8: adapter `sqlite3`, database
   `ENV.fetch("DB_PATH", "db/mind_pod.sqlite3")`. Production and development
   both honour `DB_PATH`. There is no ROLE-conditioned skip.
5. On start it prints the connected database
   (`bin/backjob` line 12: `ActiveRecord::Base.connection_db_config.database`).

Writes (not reads):

| what | how | file:line | kind |
|---|---|---|---|
| `reconciliation` row | `Reconciliation.create!(note_count: n)` | `app/bin/backjob:37` | ActiveRecord INSERT |
| graph outbox row | `Vv::Graph::ProjectionJob.enqueue!` via `after_save` | `gems/vv-graph/lib/vv/graph/storable.rb:165–181` then `publisher/immediate.rb:32–37` | ActiveRecord INSERT, if the outbox table exists |

Reads:

| what | how | file:line |
|---|---|---|
| note count | `Note.count` | `app/bin/backjob:36` |
| L8 operation requests | `RailsOsiLevel8::OperationRequest.cross_boundary.where(...)` | `app/bin/backjob:41–44` |
| existence of complete child | `OperationRequest.exists?(...)` | `app/bin/backjob:46–50` |

It does **not** write L8 models directly. The comment at `bin/backjob:2–3`
says so, and the complete path is HTTP:

```
cpcp_push(back_url, "l8.execution.complete", ...)
→ POST #{BACK_URL}/_cpcp/rpc
```

(`app/bin/backjob:14–28, 53–58`). That is a write *if it reaches BACK*.

**FINDING (config):** compose does not set `BACK_URL` on `backjob`
(`docker-compose.yml:36`). The worker defaults
`BACK_URL` to `http://127.0.0.1:3000` (`bin/backjob:10`). Inside the
backjob container that is not the `back` service. Confidence: **inferred from
config**. Runtime evidence that would settle whether completes ever land:
observe `[backjob] l8.execution.complete ... ok=` lines, or a packet capture
on `back:3000/_cpcp/rpc` from the backjob network namespace.

Raw SQL: none in `bin/backjob`. Event log: the CPCP POST is the intended
durable-completion write; the sqlite `Reconciliation` row is also durable
state. RES as a separate log is **unresolved** from this file (no `Res.`
call in `bin/backjob`).

Manus: treat the *capability* (shared mount + `DB_PATH`) as a defect
regardless of observed behavior. The code uses that capability.

---

## FINDING 2 — what runs as SWITCH is not NVIDIA Switchyard

Two different things share a name.

### 2a. What compose actually runs (read the code)

`runtimes/mind-pod/docker-compose.yml:56–67` builds

```
context: ../..
dockerfile: runtimes/switch/Dockerfile
```

That Dockerfile (`runtimes/switch/Dockerfile:6–12`) copies **only**
`runtimes/switch/` and `gems/switchyard-offline/shared/`, sets
`SWITCH_STATE_DIR=/state`, exposes 8789 and 8790, `CMD ["node", "server.mjs"]`.
It does **not** copy `upstreams/nemo-switchyard`. There is no `USER`
directive; the `node:20-slim` default is root. Confidence: **read the
Dockerfile**; runtime uid **inferred from config** (no USER line).

`runtimes/switch/server.mjs` is a Node HTTP process with two planes:

| plane | port | published? | role |
|---|---|---|---|
| data | 8789 | `expose` only (`compose.yml:66`) | OpenAI-compatible completions; MIND calls this |
| UI | 8790 | `ports: ["13001:8790"]` (`compose.yml:67`) | config surface; `/api/sources` reads/writes keys |

Secrets:

- Bind mount `../../.agent/secrets:/state` (`compose.yml:64`). Agent-level,
  survives `down -v`. **Did not list or read the host directory.**
- `sources.mjs:16,22,40–52`: state file `${SWITCH_STATE_DIR}/sources.json`
  (`/state/sources.json` in the container). `saveState` writes mode `0o600`.
  Keys live in `state.keys[vendorId]`.
- Completions read `state.keys[vendorId]` and pass it to `egress()` as
  `token` (`server.mjs:76–90`). The key does not leave as a file to MIND.
- `OLLAMA_URL` env for the local path (`sources.mjs:20`, `server.mjs:62–70`).
  Unset in compose except `${OLLAMA_URL:-}`.

Outbound destinations (allowlist, https except local):

From `gems/switchyard-offline/shared/routes.js:5–27` plus
`runtimes/switch/providers.mjs:18–39`:

| id | origin |
|---|---|
| openai | `https://api.openai.com` |
| anthropic | `https://api.anthropic.com` |
| nvidia | `https://integrate.api.nvidia.com` |
| fireworks | `https://api.fireworks.ai` |
| openrouter | `https://openrouter.ai` |
| ollama (local) | `$OLLAMA_URL` — not on the https allowlist; bypasses egress |

Routing is content-blind at this layer: `X-SwitchYard-Source` header, not
the prompt body (ADR 0019; `server.mjs:114`). Confidence: **read the code**.

### 2b. NVIDIA NeMo Switchyard at pin 47babb1 (read the pinned source)

`upstreams/nemo-switchyard/src` is a **git submodule** pinned at
`47babb1a933e952bc6997b9ea208b5903c61a48c`
(`upstreams/manifests/nemo-switchyard.pin.json`). In this worktree the
`src/` directory is **empty** (submodule not populated). That is a checkout
fact, not an absence of upstream.

Verified from the MAIN checkout (Claude, read the tree): `src/` there is
populated and contains **8 Rust crates** (`Cargo.toml` count). So the pin is
real, is Rust, and is simply unpopulated in worktrees -- git does not
populate submodules in a `git worktree add` by default.

Pinned source was cloned **outside this repository** to
`/Users/ericlaquer/NoIcloud/.mm_tmp/switchyard-pin-47babb1` at that SHA
(read-only inspect; the magentic-stack tree was not modified).

NVIDIA Switchyard at that SHA **is a real LLM router**, not a passive
proxy:

- Rust binary `switchyard-server` (`Dockerfile` builds `-p switchyard-server`).
- Default listen port **4000** (`crates/switchyard-server/src/cli.rs:17`).
- Image `USER 1000:1000`, `EXPOSE 4000`, `ENV HOME=/tmp`
  (`Dockerfile:26–31`).
- Credentials from **environment variables** named in TOML `api_key_env`
  (`dev-server/config.toml:8` `NVIDIA_API_KEY`; docs list
  `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `NVIDIA_API_KEY`,
  `OPENROUTER_API_KEY` in `AGENTS.md:241–245`). Not a `/state` file.
- OpenAI Chat / Responses / Anthropic Messages on the server
  (`crates/switchyard-server/src/lib.rs` routes).
- Routing algorithms that **do inspect request content** (escalation
  router / judge in `docs/routing_algorithms/`). That is the opposite of
  ADR 0019's content-blind pod switch.
- Optional OTLP export (`observability.rs` `OTEL_EXPORTER_OTLP_ENDPOINT`).

**It is not the process compose starts.** Bundling VAULT with "Switchyard"
is therefore ambiguous until the operator says *which* Switchyard. The
pod's SWITCH is `runtimes/switch` + `switchyard-offline`. NVIDIA's binary
is a pinned unused submodule.

Runtime evidence that would settle whether the NVIDIA binary is ever
executed in this pod: a running container image id / `ps` inside `switch`
showing `node server.mjs` vs `switchyard-server`. Compose + Dockerfile
already say `node server.mjs`.

---

## Known doc defect (record, do not fix)

`docs/architecture/OVERVIEW.md:22–34` heading **"5-container MIND Pod"**
then a table of **six** roles (FRONT, BACK, BackJob, SWITCH, GRAPH, MIND).
`runtimes/mind-pod/docker-compose.yml:1–5, 22–78` defines **six** services
(`back`, `backjob`, `front`, `mind`, `switch`, `graph`) plus two volumes.
Do not correct the heading here; 2026-08-30c says the doc will be rewritten
by whichever design is chosen.

---

## Every process that opens SQLite

| process | path | adapter | read/write | confidence |
|---|---|---|---|---|
| **back** | `/data/mind_pod.sqlite3` via `DB_PATH` | ActiveRecord sqlite3 (`database.yml:1–8`) | **write** (Rails server, `db:prepare`, models, CPCP `Note.create!` at `rails_cpcp.rb:39`) | read the code |
| **backjob** | same file, same volume | same | **write** (`Reconciliation.create!`, ProjectionJob) | read the code |
| **front** | compose sets **no** `DB_PATH` and **no** data volume (`compose.yml:38–42`). Rails still loads ActiveRecord (`application.rb:3, 16–18`). Default file would be `db/mind_pod.sqlite3` **inside the container FS**, not `mind-data`. | sqlite3 if it connects | **unresolved whether FRONT's boot actually opens it**. `mmg_graph.rb:14` skips graph CPCP register unless `ROLE==back`. `osi_level_8.rb:17` skips CpcpAdapter unless `ROLE==back`. A Rails boot with AR still typically connects. | inferred from config; settle by tracing `ActiveRecord::Base.connection` at FRONT boot or `lsof` in the front container |
| **mind** | none in compose; Dockerfile comment "no DB" (`mind/Dockerfile:2–8`); harness talks HTTP only (`harness.py:35–51`) | — | does not open sqlite | read the code |
| **switch** | none | — | no sqlite | read the code |
| **graph** | Oxigraph files at `/data`, not sqlite (`compose.yml:75–77`) | — | n/a | read the code |
| **tests / gems** | `:memory:` or tmp sqlite in specs (`vv-base/spec/spec_helper.rb`, `mmg-blob`) | sqlite3 | test-only, not a pod process | read the code |
| **mmg-blob** | `ENV.fetch("MMG_BLOB_PATH", "db/blobs.sqlite3")` (`gems/mmg-blob/lib/mmg/blob/operations.rb:24`) | sqlite | **not referenced** from `runtimes/mind-pod/` | read the code; unused in this compose |

---

## Every process that mutates Oxigraph

Oxigraph itself: `oxigraph/oxigraph@sha256:e68b36…` command
`serve --location /data --bind 0.0.0.0:7878` (`compose.yml:75–77`). Volume
`graph-data:/data`. Port 7878 exposed, not published.

Mutation route in-tree: SPARQL UPDATE over HTTP.

| caller | route | when | confidence |
|---|---|---|---|
| **back** | `Vv::Graph::Sparql.execute` → OxirsBackend HTTP (`sparql.rb:15–19, 136`); also `Mmg::Graph::Execute.update` POST `{endpoint}/update` (`execute.rb:59–62`) | `Note` / session `project_on_save!`; graph replay; CPCP graph.register is BACK-only (`mmg_graph.rb:14`) | read the code |
| **backjob** | same Storable path: `Reconciliation` includes `Vv::Graph::Storable` and `project_on_save!` (`reconciliation.rb:2, 11`) → `semantica_emit_triples!` DELETE+INSERT (`storable.rb:226–247`) | every `Reconciliation.create!` tick | read the code |
| **front / mind / switch** | no `MM_OXIGRAPH_URL` on front/mind/switch | — | inferred from compose env |

BACKJOB is therefore a **second SPARQL writer**, not only a second sqlite
writer. Compose gives it `MM_OXIGRAPH_URL: "http://graph:7878"`
(`compose.yml:36`).

`Execute.federate` is explicitly not implemented (`execute.rb:70–72`).

---

## Database paths and volume mounts, per container

From `runtimes/mind-pod/docker-compose.yml`:

| service | volumes | env paths |
|---|---|---|
| back | `mind-data:/data` | `DB_PATH=/data/mind_pod.sqlite3` |
| backjob | `mind-data:/data` (same named volume) | `DB_PATH=/data/mind_pod.sqlite3` |
| front | none | no `DB_PATH` |
| mind | none | no DB |
| switch | `../../.agent/secrets:/state` (bind, not named volume) | `SWITCH_STATE_DIR=/state` (Dockerfile) |
| graph | `graph-data:/data` | Oxigraph `--location /data` |

Named volumes: `mind-data`, `graph-data` (`compose.yml:79–81`).

Duplicate topology: `runtimes/mind-pod/app/extract/compose.yml` (used by
`bootstrap`) — same six-role idea, switch secrets mount is
`../../../../.agent/secrets:/state` (line 65). Not the canonical
`runtimes/mind-pod/docker-compose.yml` but it exists.

---

## Secret sources

| source | where | who | confidence |
|---|---|---|---|
| bind mount `.agent/secrets` → `/state` | `compose.yml:64` | **switch only** | read compose. **Did not list host files.** |
| `sources.json` keys | `sources.mjs` `saveState` / `loadState` | switch | read the code |
| UI POST `/api/sources` `{vendor, key}` | `server.mjs:241–273` | switch UI on 8790 | read the code |
| `OLLAMA_URL` | compose env, optional | switch local path | read compose |
| `SECRET_KEY_BASE` | `application.rb:14` default `"mind-pod-not-a-secret"` | Rails roles (back/front/backjob) | read the code. **FINDING:** a default rails secret in source. Not under `.agent/secrets`. Not fixed. |
| NVIDIA Switchyard `*_API_KEY` env | pinned upstream TOML `api_key_env` | **not used by compose SWITCH** | read pinned source |
| MIND | no secret mount; `harness.py` uses `BACK_URL` and `SWITCH_URL`; model pin `openai/switchyard` (`harness.py:40`) | mind | read the code |

No runtime fetch of a vault is in this compose. SWITCH holds provider keys;
MIND holds none (`compose.yml:12–13`, `harness.py:5–6`).

---

## Network callers and callees (compose)

| from | to | port / path | confidence |
|---|---|---|---|
| back | graph | `http://graph:7878` SPARQL (`MM_OXIGRAPH_URL`) | compose + Execute |
| backjob | graph | same | compose + Storable on Reconciliation |
| backjob | back | **intended** `http://back:3000/_cpcp/rpc`; **configured default** `http://127.0.0.1:3000` | code vs missing env |
| front | back | `BACK_URL=http://back:3000` | compose |
| mind | back | `BACK_URL=http://back:3000` `/_cpcp/rpc` | compose + harness |
| mind | switch | `SWITCH_URL=http://switch:8789/v1` | compose + harness |
| switch | vendor origins | openai/anthropic/nvidia/fireworks/openrouter https; optional OLLAMA_URL | providers.mjs + routes.js |
| host | switch UI | `localhost:13001` → 8790 | compose ports |
| host | data plane 8789 | **not published** | compose comment line 65 |

Internal expose only: back 3000, front 3000, switch 8789, graph 7878.

---

## MIND (for the 2026-08-30c "MIND unchanged" gate)

No volume, no secret mount (`compose.yml:43–55`). Distroless Python
(`mind/Dockerfile:25–34`). Talks only BACK and SWITCH (`harness.py:2–9,
35–36`). Does not import Oxigraph or sqlite. Credential behaviour:
**no provider key in env**; SWITCH_URL only. Whether the image *contains*
a leftover key from the builder stage: builder copies `/deps` from pip
install of vendored NOOA; runtime stage does not copy `/nooa-src`.
Confidence: **read the Dockerfile**. A leftover secret inside a pip
package is **unresolved** without scanning the built image.

---

## Urgent? (report, do not fix)

1. **Second writer is real.** BACKJOB writes sqlite and, via Storable,
   SPARQL-updates Oxigraph. Manus's "capability is a defect" is also
   observed behavior.
2. **BACK_URL missing on backjob** — L8 complete via CPCP may never reach
   BACK. Config inference; not patched.
3. **Default `SECRET_KEY_BASE`** in `application.rb:14`.
4. **NVIDIA Switchyard ≠ pod SWITCH.** Combining VAULT with "Switchyard"
   without saying which one is a category error.
5. **OVERVIEW "5-container" vs six services** — recorded, not edited.

Nothing under `.agent/secrets` was opened.

---

## What would settle the remaining unknowns

| unknown | evidence |
|---|---|
| Does FRONT's Rails boot open sqlite? | `lsof` / `ActiveRecord::Base.connected?` in a running `ROLE=front` container |
| Do backjob CPCP completes ever hit BACK? | logs `ok=` on `l8.execution.complete`; tcpdump `back:3000` |
| Is ProjectionJob table present in the pod DB? | `.schema` on `/data/mind_pod.sqlite3` (runtime) |
| Does NVIDIA `switchyard-server` ever run here? | `ps` in the switch container; image history |
| MIND image credential residue | scan layers; not done |
