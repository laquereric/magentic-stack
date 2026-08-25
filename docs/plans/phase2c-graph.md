# Phase 2c — GRAPH is deployed, empty, not reconstructable

Status: **topology real; contents not; not a materialization**. Machine envelope:
[`phase2c-graph.json`](phase2c-graph.json). Driver: [`phase2c-graph.rb`](phase2c-graph.rb).
Branch: `grok/phase2c` from `0f9d2b8`. Worktree:
`/Users/ericlaquer/NoIcloud/.mm_tmp/wt/phase2c`.

Did not re-litigate BACK-as-authority. Did not stand up Storable. Did not
invent a backfill.

## What moved

Six services: switch, back, backjob, front, mind, graph. Both compose files
carry Oxigraph pinned at
`oxigraph/oxigraph@sha256:e68b3625…`, volume `graph-data:/data`.
`volume_not_in_inventory` was the empty-inventory call. Against the **real**
mount list, Placement of `/data` as `:host_volume` is **ok**.

The store is empty (projection not wired). An empty volume with a digest is
not a materialization.

## Classifier (real inventory)

| exhibit | ok | class | authority_role | materialization | rollback |
|---|---|---|---|---|---|
| GRAPH, empty inventory | false | refused | — | — | `volume_not_in_inventory` |
| GRAPH, real inventory, role `:projection`, no replay | true | irreversible | projection | **false** | `not_by_image_selection` |
| LIE: same + `reconstructable_from: "Vv::Graph::Storable whole-store replay"` | true | compensable | projection | **false** | `reconstruct_from_authority` |
| Oxigraph image, digest-pinned, `release_verified: false` | false | refused | — | — | `release_evidence_missing` |
| SQLite `mind-data`, `:authoritative` | true | irreversible | authoritative | **false** | `not_by_image_selection` |
| SQLite + `clone_evidence` | true | compensable | authoritative | **false** | `declared_volume_clone` |

The lie exhibit is still executable and still green. Naming a replay that
does not exist is the same shape as Phase 2b's absent-graph projection.

## Whole-store replay?

**No.** Confirmed, not just `vv-graph/lib` names:

- No `backfill` / `reproject` / `project_all` in `gems/vv-graph/lib`.
- `Storable` emits **per-row** on `after_save`.
- `Publisher#drain_pending!` drains the `ProjectionJob` **outbox of rows
  already enqueued**, not a scan of AR tables.
- `reasoner` `full_rebuild_required` is OWL, not AR replay.
- mind-pod `Gemfile` does not depend on `vv-graph`.
- `runtimes/graph/README.md` already says there is no backfill.

`reconstructable_from` that names Storable replay is a procedure nobody can
execute. Same false rollback point, one level up.

## Class-or-instance invariant: enforced or merely true?

**Merely true, and only as a README.** Not enforced.

`Vv::Graph::Sparql.execute("INSERT DATA {…}")` is a public write. Compose
binds Oxigraph as a raw SPARQL server (`serve --location /data`). mind-pod
has no Storable include and no write proxy. An `INSERT DATA` from anywhere
breaks reconstructability **silently**.

## Do `notes` / `journeys` / `flows` / `missions` carry `triples do…end`?

**No.** Inspected:

`Note`, `Journey`, `Flow`, `Mission`, plus `Actor`, `Persona`, `Vision`,
`Reconciliation`, and `ApplicationRecord`. Zero `include Vv::Graph::Storable`.
Zero `triples do`. `gems/rails-osi-level-8` likewise has none. The
only `triples do` in this tree is a **comment** on `RailsThreedotBack::Cid`.

So even after Storable is wired, GRAPH is a **partial** projection unless
those models (and the osi_l8_* tables) gain declarations. Those tables stay
Plane B with no reconstruction path. Phase 2b's SQLite finding survives.

## Mounts

| Mount | Disposition |
|---|---|
| `mind-data` → `/data` | `excluded` — Plane B SQLite |
| `graph-data` → `/data` | `excluded` — empty; not reconstructable |
| `.agent/secrets` → `/state` | `excluded` — secrets (C6 still does not see the path) |

`branch_seeded` on `mind-data` is still a clone of the authority.

## What would have to change

Shortest honest rollback story for the **pod**, given the truth store cannot
be a Plane C materialization:

GRAPH can be a reconstructable **projection** only after all three: (1)
`triples do` on every table that must come back, including
notes/journeys/flows/missions; (2) a whole-store replay that can actually
run; (3) Oxigraph writes gated so only Storable emits (class-or-instance
enforced). Until then the only declared restore of mind-pod state is a
**volume clone of `mind-data`** — compensation of Plane B, `materialization:
false`. There is no fork-activatable predecessor.

No Dockerfiles or compose files were modified.
