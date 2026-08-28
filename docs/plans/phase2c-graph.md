# Phase 2c — GRAPH is deployed, empty, not reconstructable

> ## SUPERSEDED 2026-08-28 — the title no longer describes the tree
>
> **This is a dated snapshot taken at `0f9d2b8` on 2026-08-24, kept as the record
> of why the projection was built. Its analysis was correct when written. Four of
> its central findings have since been answered by building the thing it said was
> missing. Do not cite the body below as current state.**
>
> | This document said | Now |
> |---|---|
> | The store is empty; projection not wired | **False.** `Note`, `Reconciliation`, and `Vv::Base::Session` declare `triples do` + `project_on_save!` |
> | Whole-store replay? **No.** | **False.** `graph.replay` is a CPCP operation (`rails_cpcp_session.rb:63`) backed by `GraphReplay.run`; models are discovered, not listed |
> | Class-or-instance invariant merely true, not enforced | **False.** `VV_GRAPH_TRIPLE_GATE: "strict"` on `back` and `backjob` (`docker-compose.yml:30,36`) |
> | The pod `Gemfile` has no graph gem | **False.** It now carries both `mmg-graph` (line 17) and `vv-graph` (line 22) |
> | `runtimes/graph/README.md` says deployed-and-empty | Now reads **`Status: projected, and reconstructable`** |
>
> One irony worth recording. The **LIE exhibit** in the classifier table below —
> declaring `reconstructable_from: "Vv::Graph::Storable whole-store replay"` — was
> called a lie *because no such replay existed*. It exists now, and
> `runtimes/mind-pod/test/graph_replay_equality_test.py` asserts it round-trips
> (20 → 0 → 20). The accusation was answered by building the missing procedure
> rather than by deleting the claim.
>
> ### What still stands
>
> Two findings survive and are **open**, not superseded:
>
> 1. **The projection is still partial.** `Journey`, `Flow`, `Mission`, `Actor`,
>    `Persona`, and `Vision` carry zero `triples do` — verified 2026-08-28. Those
>    tables remain Plane B with no reconstruction path, so Phase 2b's SQLite
>    finding survives intact.
> 2. **Grounded is not derivable.** Session graphs are grounded by
>    `Mmg::Graph::Entry` rows but cannot be *derived* from them.
>    `reconstructable_from` is true of projected application state and false of
>    authored session content.
>
> ### On the sibling files
>
> `phase2c-graph.json` is **generated** by `phase2c-graph.rb` (which writes it at
> line 140), so it is a machine snapshot at `sourceCommit 0f9d2b8` and still
> carries `graph.empty: true`. It has deliberately **not** been hand-edited: a
> re-run would overwrite the edit, and mutating it would make it a false record of
> the commit it names. Re-run the driver against the current tree if a fresh
> envelope is wanted.

Status (as of `0f9d2b8`, 2026-08-24): **topology real; contents not; not a
materialization**. Machine envelope: [`phase2c-graph.json`](phase2c-graph.json).
Driver: [`phase2c-graph.rb`](phase2c-graph.rb). Branch `grok/phase2c` and its
worktree were collapsed into `main` and deleted on 2026-08-28; the unique commit
was `f98cf9f`, recoverable from reflog.

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

> **No longer true (2026-08-28).** The projection is wired and the store is
> non-empty; `session.open` takes it from 0 to 6 triples. See the header.

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

> **ANSWERED YES since 2026-08-28.** `graph.replay` is a CPCP operation backed
> by `GraphReplay.run`, with a replay-equality test. The bullets below stay
> literally true *of `gems/vv-graph/lib`* -- the replay lives in the pod, not in
> the gem -- but the conclusion drawn from them no longer holds.

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

> **NOW ENFORCED (2026-08-28).** `VV_GRAPH_TRIPLE_GATE: "strict"` is set on
> `back` and `backjob`. A planted `INSERT DATA` fails the run by name.

**Merely true, and only as a README.** Not enforced.

`Vv::Graph::Sparql.execute("INSERT DATA {…}")` is a public write. Compose
binds Oxigraph as a raw SPARQL server (`serve --location /data`). mind-pod
has no Storable include and no write proxy. An `INSERT DATA` from anywhere
breaks reconstructability **silently**.

## Do `notes` / `journeys` / `flows` / `missions` carry `triples do…end`?

> **PARTIALLY ANSWERED (2026-08-28).** `Note` and `Reconciliation` now declare
> `triples do`, as does `Vv::Base::Session`. `Journey`, `Flow`, `Mission`,
> `Actor`, `Persona`, and `Vision` still do **not** -- so the partial-projection
> conclusion at the end of this section STANDS.

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

> **STATUS 2026-08-28:** (2) and (3) are DONE. (1) is PARTIAL -- done for
> `Note`, `Reconciliation`, `Vv::Base::Session`; not done for `Journey`, `Flow`,
> `Mission`, `Actor`, `Persona`, `Vision`. So the conclusion below still holds,
> but for one reason now instead of three.

GRAPH can be a reconstructable **projection** only after all three: (1)
`triples do` on every table that must come back, including
notes/journeys/flows/missions; (2) a whole-store replay that can actually
run; (3) Oxigraph writes gated so only Storable emits (class-or-instance
enforced). Until then the only declared restore of mind-pod state is a
**volume clone of `mind-data`** — compensation of Plane B, `materialization:
false`. There is no fork-activatable predecessor.

No Dockerfiles or compose files were modified.
