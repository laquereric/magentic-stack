# Gap 24: FRONT historical `/_cpcp`

Measured 2026-08-31 from `94b7737`. Investigation only. No code
change; no live bad state.

The question: before `0a7d67f` gated the route table, did anything get
**admitted** through FRONT's `/_cpcp` into a sqlite that was not BACK's
`mind-data` volume?

## Verdict

| Step | Answer |
|---|---|
| **1. COULD it?** | **Yes.** Reachability is a fact of the compose and the routes as they were. |
| **2. WOULD WE KNOW?** | Only from FRONT's container-local sqlite or FRONT container logs. Those locations do not survive. |
| **3. DID it?** | **Not established.** The evidence is gone. That closes the row. |

No admitted operation with no durable backing was found in anything that
still exists. If that had been found, this document would have stopped
there.

## 1. COULD it have happened?

From the tree at `97a0ca5` (parent of `0a7d67f`), not from memory.

**Routes.** `runtimes/mind-pod/app/config/routes.rb` mounted
`RailsCpcp::Engine => "/_cpcp"` **unconditionally**. Comments named BACK
and FRONT; the mount did not. FRONT's process served the write seam.
Window: `cc26e65` (2026-08-19) → `0a7d67f` (2026-08-30 20:20). After
`0a7d67f`, `when "front"` draws only `/`, `/notes`, `/governance`.

**Extract compose** (`app/extract/compose.yml`, used by
`bin/docker-containers` and `./bootstrap`):

- `ROLE=front`, `PORT=3000`, `BACK_URL=http://back:3000`
- **`ports: ["13000:3000"]`** — host-reachable
- **no `DB_PATH`**
- **no `mind-data` volume**

**Canonical compose** (`runtimes/mind-pod/docker-compose.yml`): FRONT
`expose: ["3000"]` only. Host cannot hit it; other containers on the
network can.

**Default sqlite.** `database.yml` is
`ENV.fetch("DB_PATH", "db/mind_pod.sqlite3")`. FRONT's entrypoint is
`exec bundle exec rails server` — no `db:prepare`. The image still had
a database: `COPY . .` baked the host's gitignored
`db/mind_pod.sqlite3` into `/rails/db/mind_pod.sqlite3`.

| Image | Baked sqlite | sha256 of `/rails/db/mind_pod.sqlite3` |
|---|---|---|
| `mind-pod:demo` (2026-08-24 11:40) | 835584 bytes, mtime 2026-08-19 18:10 | `fc8dc54d4f6f83b328a0c6812a6718ccd57d80064d05da1af9a04eb58c132053` |
| `mind-pod:latest` (2026-08-29 08:19) | identical | same |
| `mind-pod:thin` (2026-08-24 17:23) | identical | same |
| `mind-pod:vault-test` (2026-08-30 20:20, gating-era) | **absent** | — |

The baked file already had `osi_l8_operation_requests` (5 rows) and
`osi_l8_operation_journal_entries` (19 rows), including the
`admission_status` column the pre-0052 adapter wrote. The container
runs as **root**. FRONT did not need `db:prepare` for `note.create` to
insert.

So a `POST http://localhost:13000/_cpcp/rpc` against the extract demo
would have been handled by FRONT's engine, against FRONT's overlay of
that baked file, not against `/data/mind_pod.sqlite3` on `mind-data`.

**Who was pointed at that port.**

- `QUICKSTART.md` (from `d9b61fa`, still on main):
  `curl http://localhost:13000/_cpcp/up` and `POST …/rpc` `note.list`.
- `.threedot/cid.json`: `"backUrl": "http://localhost:13000"`.
- `bin/docker-containers` waits on `:13000/up` and seeds via
  `POST /notes` (the FRONT form). That form uses
  `BACK_URL=http://back:3000` — the **intended** path, not the hole.
- `HomeController` and `BackCpcpClient` speak only to `config.x.back_url`.
  Browser "Create via /_cpcp" is not the hole.
- MIND and BACKJOB use `BACK_URL=http://back:3000`.
- CI overlays publish **BACK** on `:3000`, not FRONT on `:13000`.
- Historical `make demo` overlay (`docker-compose.demo.yml` at
  `42a7aea`, file now gone) published **BACK** on `:13000`.

The hole is host (or a docker-network peer) talking to FRONT's
`/_cpcp`, not the UI and not in-pod MIND.

## 2. WOULD WE KNOW? Where we looked

A FRONT admission would live in the FRONT container's writable layer at
`/rails/db/mind_pod.sqlite3`. FRONT never mounted `mind-data`. Recreate
destroys the overlay.

| Location | What it is | What is there |
|---|---|---|
| `docker ps -a` | leftover FRONT containers | **none** (only `buildx_buildkit_kamal-local-docker-container0`) |
| `docker logs` of those containers | request log of `/_cpcp` on FRONT | **gone with the containers** |
| image layers `mind-pod:demo` / `:latest` / `:thin` | baked copy of the **host** sqlite at image build | Aug 19 local-dev snapshot, 5 `operation_request` rows (`boot-key-1`, `m2-boot-1`, `m38-1`, `m38-deny`, one `l8.execution.complete`). **Not a FRONT overlay.** Identical across the three tags. |
| `mind-pod:vault-test` | gating-era image | no sqlite |
| volume `mind-pod-demo_mind-data` | BACK's `DB_PATH=/data/mind_pod.sqlite3` | 95 `note.create`, 96 notes, last write 2026-08-24 16:33. Includes seed `Hello from docker-containers` (FRONT form → BACK) and MIND titles. This is BACK. It cannot show FRONT-only rows. |
| `/tmp/gap52/mind_pod.sqlite3` | earlier copy of that volume | same 95/96 population |
| host `runtimes/mind-pod/app/db/mind_pod.sqlite3` | local Rails, default `ROLE=back` | same 5 cids as the baked image, plus the 0052 `authorized` backfill (journal 19 → 23). `development.log` is 127.0.0.1 on 2026-08-19. Not a FRONT container. |
| host `log/development.log`, `log/test.log` | local Rails | `ViaFront` posts are `POST /notes` then `/_cpcp/rpc` on **one process** (unconditional routes). Monolith, not the FRONT container. Last development write 2026-08-19 14:10. |
| `~/.zsh_history` | operator curls | no `13000/_cpcp` |
| TCP `:13000` now | live listener | nothing |
| `runtimes/mind-pod/evidence/` | `mind_boundary_test.py` artifact | absent |

Image sqlite checksum `fc8dc54d…` ≠ host today
`e7f60b6e…` (backfill) ≠ volume `113e6ab0…`. Three lineages; none is a
surviving FRONT overlay.

## 3. DID it?

Only askable if step 2 still has the overlay. It does not.

What the surviving stores **do** show, and what they are not:

- Volume note id 2 title `Hello from docker-containers` at
  2026-08-24 15:40:47 matches `bin/docker-containers`'s
  `POST /notes` seed. That went FRONT form → `http://back:3000/_cpcp`
  and **is** on BACK. Intended path.
- The other 94 volume `note.create` rows carry `mind-*` idempotency
  keys or MIND titles, `caller_iri=cyborg:front` (the OSI actor name,
  not `ROLE=front`), against BACK's volume.
- Baked/host 5 cids are 2026-08-19 local milestone traffic
  (`boot-key-1`, `m2-boot-1`, `m38-*`), also `caller_iri=cyborg:front`.

None of that is a FRONT-container admission. None of it is "admitted
with no durable backing": the volume rows are on BACK; the baked rows
are the image snapshot of host local-dev.

A human following QUICKSTART, or the threedot extension using
`cid.json`'s `backUrl`, **would** have hit FRONT `/_cpcp` during the
window. No leftover overlay, log, or history line shows that they did.
That is not a claim that they did not.

## Present leftovers (not this row)

These are not live write holes. FRONT no longer draws `/_cpcp`
(`0a7d67f`, gated by `check_role_routes.py`). They are stale pointers
at the published port:

- `QUICKSTART.md` still tells the reader to
  `curl http://localhost:13000/_cpcp/up` and `POST …/rpc`. That is now
  404.
- `.threedot/cid.json` still has `"backUrl": "http://localhost:13000"`.
  Extract compose still does not publish BACK.
- `app/.gitignore` ignores `db/*.sqlite3`; there is still no
  `.dockerignore`. Rebuilds of `mind-pod:demo`/`latest` from a tree
  that has the host sqlite will bake it again. FRONT will not serve
  `/_cpcp` even then.
- `Makefile` `demo` still sets `BACK_URL=http://localhost:13000` and
  waits on `:13000/up`; `test/docker-compose.demo.yml` (BACK published
  on 13000) is gone.

No code in this change. Those leftovers are not gap 24's question.
