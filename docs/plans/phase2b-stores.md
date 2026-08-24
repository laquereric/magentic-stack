# Phase 2b — SQLite and Graph as stores (report only)

Status: **neither store is a Plane C materialization today**. Machine envelope:
[`phase2b-stores.json`](phase2b-stores.json). Driver:
[`phase2b-stores.rb`](phase2b-stores.rb). Branch: `grok/phase2b-stores`
(worktree `/Volumes/G-DRIVE slim/dsh/work/magentic-stack-phase2b`, from `c304315`).
`mmg-effect-plane` was **not** extended. No graph service was stood up.

## Per store

### 1. SQLite (`mind-data` → `/data/mind_pod.sqlite3`) — deployed

Honest declaration:

```
authority: { role: :authoritative, reconstructable_from: nil, clone_evidence: nil }
```

| Probe | Verdict |
|---|---|
| `Placement` `:host_volume` + `/data` | **ok** (once a disposition is assigned) |
| `Classifier` on that placement, role `:authoritative` | **ok: true**, `:irreversible`, rollback `:not_by_image_selection` |
| `Classifier` `:snapshot_image` + role `:authoritative` | **ok: false**, `:sole_authority_store` |
| `Classifier` `:host_volume` + `clone_evidence` | **ok: true**, `:compensable`, `:declared_volume_clone` — volume restore, **not** a materialization |
| LIE: role `:projection`, `reconstructable_from: "oxigraph:named-graph:mind-pod"` on `:host_volume` | **ok: true**, `:compensable`, `:reconstruct_from_authority` — Classifier goes **green** |
| LIE: same on `:snapshot_image` | **fork_reversible** |

**What is this a projection of?** Nothing that exists. The file is the truth.

It is one SQLite file mixing append-only `osi_l8_*` journals (closest thing
mind-pod has to an event log) **and** mutable AR (`notes`, `journeys`,
`flows`, `missions` with `updated_at` / `status`). Substrate doctrine
(graph + event log as truth, AR as projection) **does not hold here**. There
is an in-file journal; there is no store outside the file.

### 2. Graph (Oxigraph) — **not deployed** (design-only)

Honest declaration it **would** carry, if it existed:

```
authority: { role: :authoritative, reconstructable_from: nil, clone_evidence: nil }
```

| Probe | Verdict |
|---|---|
| `Placement` `:host_volume` `/data/oxigraph` with compose's real mount inventory (empty for this path) | **ok: false**, `:volume_not_in_inventory` |
| `Placement` `:snapshot_image` with no digest | **ok: false**, `:digest_missing` |

The gem is how we know it is not real. A materialization record with a digest
for this store would be a lie.

README intent (`runtimes/graph/`, mind-pod README): Oxigraph is RDF truth;
other surfaces project from it. **If that were true**, Graph would still be
Plane B (`:authoritative` → Classifier refuses it as a materialization) and
SQLite `osi_l8_*` could become `:projection` with `reconstructable_from`
pointing at a named-graph cursor.

What would have to be true for that to be real:

1. a graph service in `app/extract/compose.yml` with a durable volume
2. BACK writing RDF as append-only truth, not only `jsonld` columns inside SQLite
3. `notes` / `journeys` / `missions` either in the graph or declared a **separate** Plane B
4. a real cursor SQLite can replay from

Until (3), even a well-formed “graph is B, sqlite is projection” contract is
still a lie about the mutable AR tables. The driver’s counterfactual contract
**validates `ok: true`**. That is the danger: C1–C9 can pass while `notes`
have no reconstruction path.

## One sentence

**SQLite (`mind-data`) is the sole deployed authority; GRAPH is not
deployed; Classifier will never accept an authoritative store as a Plane C
materialization.**

## Mount dispositions (assigned)

| Mount | Disposition | Why |
|---|---|---|
| `/data` (`mind-data`) | **`excluded`** | Writable Plane B. Image fork must not claim to roll it back. `immutable_input` is false (BACK writes). `branch_seeded` is a volume clone of the authority — compensable restore, not a materialization. |
| `/state` (bind `.agent/secrets`) | **`excluded`** | `FORBIDDEN_CONTENT` includes `secrets`. |
| `ollama-models` | **`excluded`** | Model cache; reconstructable from the ollama image. Named so it is not silent. |

## C6 / switch secrets

The `/state` bind does **not** refuse by existing. C6 inspects
`contract[:includes]`, not the mount list.

| Contract | What fires |
|---|---|
| `/state` unresolved, `includes: []` | **C4** `:unresolved_writable_volume` first |
| `/state` excluded, `includes: []` | **C6 passes** |
| `includes: [:secrets]` | **C6** `:forbidden_snapshot_content` (once earlier conditions are stripped; C2 still wins first on an `:authoritative` store) |

Exclusion is load-bearing. It is not implied by the path name `.agent/secrets`.

## Snapshot of both, honestly

`validate_contract` with both stores as `:authoritative`, mounts excluded:
**ok: false**. C4 and C6 satisfied; C1, C2, C3, C5, C7, C8, C9 fail. C2 is
`:sole_authority_store` — the plane boundary doing its job.

## What this brief got wrong

1. **“Make both first-class materializations” cannot succeed for a store that
   is the truth.** The gem refuses `:authoritative` on purpose. The honest
   output is Plane B, not a greener role.
2. **“The SQLite store” is not one kind of store.** One file mixes an
   append-only journal and mutable AR. A single `STORE_ROLE` is already a
   coarsening.
3. **`host_volume` + `clone_evidence` ignores `:authoritative`.** Classifier
   returns `:compensable` for a clone of the sole authority. That path is a
   volume restore, and it will go green if someone uses it to “satisfy”
   Phase 2b.
4. **The lie exhibit goes green.** Declaring SQLite a `:projection` of a
   graph that is not in compose makes Classifier `:compensable`. That is
   exactly the false rollback point this exercise exists to prevent.
5. **C6 does not see bind mounts.** Claude’s suspicion that `/state` alone
   refuses the snapshot is half-right: only if we *declare* `secrets` in
   `includes`, or fail to `exclude` the mount (C4). The path name does no
   work.

No Dockerfiles, compose files, or images were modified.
