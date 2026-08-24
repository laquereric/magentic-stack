# Deploying the pod, and managing it as one thing

Three goals, in the operator's words:

1. Deploy the six-container magentic-stack pod to the VPS.
2. Deploy `app-oriented-translation` as a thin layer on top.
3. Manage the pod as a single entity.

This is the plan and, more usefully, what is actually in the way.

## What is true today

**The VPS is not greenfield.** `31.97.8.47` (x86_64, 3.8 GiB RAM, 31 GB free)
already runs ten containers, including a pod with **back, backjob, front and
graph** up for a week:

| container | image | published |
|---|---|---|
| `mm-pod-cpcp-back` | `mm-component:cpcp-back` | `:38090` |
| `mm-pod-cpcp-backjob` | `mm-component:cpcp-back` | |
| `mm-pod-cpcp-front` | `mm-component:cpcp-front` | `:38091` |
| `mm-pod-cpcp-graph` | `ghcr.io/oxigraph/oxigraph` | |
| `mm-edge` | `caddy:2` | ingress |

plus `rr-todo`, `rr-todo-host`, `rr-landing`, `switchyard-cpcp`,
`switchyard-online-web`. Roughly 873 MiB in use; about 2 GiB free.

**The deploy mechanism lives in a different repo.** `mm-component` / `mm-edge`
naming comes from `mmg-k3s`'s DockerEffector, which is in
`magentic-market-ai/gems/` — the substrate. magentic-stack contains **no**
reference to it. Its only deploy story is `bin/docker-containers`, a local dev
runner. So the thing to deploy and the thing that deploys have no seam between
them.

**The base pins survive the move; the built ones do not.** `ruby:3.3-slim`,
`python:3.13-slim`, distroless and oxigraph are all pinned to **multi-arch index
digests covering `linux/amd64`**, so Phase 1b's work holds on x86_64. But the
built image ids in `phase1b-mind-pod-digests.json` are arm64-local. Rebuild on
the VPS and they all change. **The pod has no identity that survives a rebuild.**
That is goal 3's real problem, and it is not a packaging problem.

## Decisions taken

**magentic-stack gets its own deployer** rather than reaching across to the
substrate's `mmg-k3s`. This keeps the ADR 0001/0002 boundary honest — the pod
definition owns its own lifecycle — at the cost of reimplementing capability
`mmg-k3s` already has (receipts, backup, TLS, health, maintenance). It is the
slowest path to a running pod and the only one where the repo *is* the
deployment.

**The VPS gets its own Fireworks key**, minted separately from the local one so
it can be revoked without touching local work and so spend is attributable per
box. The key is placed by the operator, never by an agent, and lives only in the
bind-mounted `/state`.

## Goal 3 is two goals

Conflating these will waste effort.

**3a — operational single entity.** One command for up / down / status / backup
across all six; one ingress; one place to look. Reachable now, and it falls out
of the deployer if the deployer emits a receipt naming all six by digest.

**3b — identity and rollback.** One signed record of *this pod, this version,
revertible*. **Blocked on real work**, and no packaging will fake it:

- SQLite on `mind-data` is the sole authority and classifies `irreversible`
  (`docs/plans/phase2b-stores.md`).
- GRAPH is deployed but **empty** — the `Storable` projection is not wired.
- There is no whole-store replay, so `reconstructable_from` would name a
  procedure nobody can execute.

Until at least the third is fixed, a "release packet" for this pod would be a
digest attached to a rollback that does not exist. Phase 2c is chasing exactly
this.

## Order

**1. Thin layer (goal 2).** Cheapest and it makes the pod worth deploying.
`app-oriented-translation` is a Rails engine whose only dependencies are
`actionview` and `railties` — no `Mm::`, no `vv-*`, no RDF, no ActiveRecord. The
only `RailsOsiLevel8` references are in `docs/*/bin/` offline build scripts, not
the runtime, and `rails-osi-level-8` is **already vendored into the pod app**.
Mount it like `rails-cpcp`; add a route.

*The catch:* the board is generated offline by `build_board.rb`. Making it live
means the pod app must supply ACIA documents. That work is real and it is not in
the engine — do not let "thin" hide it.

**2. Deployer (goal 1).** `bin/deploy`: build on the box (x86_64, registry-less,
as magenticmarket.ai was), tag, run all six, wire `mm-edge`. Publish nothing but
FRONT. **The switch UI must not be internet-facing** — it is a key-entry form;
it goes behind the edge with auth or is not published at all.

**3. Receipt (goal 3a).** The deployer emits one record naming all six by
digest, plus the pod's ingress and volumes. That record is the single entity.

**4. Replay (goal 3b).** The projection and whole-store replay, so
`reconstructable_from` names something executable and the receipt can honestly
claim a rollback point.

## Watch items

- **Memory.** A second full pod is ~700 MiB against ~2 GiB free. It fits, but the
  `mm-pod-cpcp-*` pod becomes largely redundant once this one runs; retiring it
  is the obvious reclaim.
- **Two lineages.** `mm-component:cpcp-back` and `runtimes/mind-pod/app` are not
  the same build. Once this pod runs, say plainly which one is canonical.
- **Egress.** With a key on the VPS, that box talks to Fireworks. It did not
  before.
