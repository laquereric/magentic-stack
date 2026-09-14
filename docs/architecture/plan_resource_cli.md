# Plan — `switchyard` CLI: digest-addressed resources and what depends on what

**Design only. Not built.** No CLI, no registry, no graph, no VPS reach,
no canvas. This file is the contract an implementation has to keep. The
six decisions it originally parked were closed on 2026-09-13 — see
[§Decisions taken](#decisions-taken--2026-09-13).

Companion to [`DESIGN.md`](DESIGN.md) (the router this repo is named
for) and [`VULNERABILITY_ANALYSIS.md`](VULNERABILITY_ANALYSIS.md). In
magentic-stack: `docs/architecture/plan_vv-code-search.md` (the pin
index this must consume rather than rebuild),
`docs/architecture/plan_sharedai_canvas.md` (where visualization lands),
ADR 0019 (the router is content-blind), ADR 0038 (that repo is closed),
ADR 0063 (overlays consume the substrate).

---

## The decision this file records

**switchyard-offline becomes the local control plane**, not only the
local router. Local Docker and the remote VPSs are managed from here.

That is a scope change and it deserves one paragraph of care rather
than a shrug, because this repo's identity is a **content-blind** LLM
router (ADR 0019: *"a router that reads the prompt to decide where to
send it has read the prompt"*). A resource manager, by contrast, must
read files: lockfiles, pin manifests, compose, `FLOOR.json`.

Those are two surfaces under one roof, and the rule between them is:

> The CLI may read content. **The routing path may not, and must not be
> able to.** They share a repository, a release and an operator. They do
> not share a code path, and nothing the CLI learns may become an input
> to `switchyard.route`.

A gate holds that, not a convention — see §Gates.

---

## The problem, measured

Digest pinning in magentic-stack works. What is missing is any answer to
**"what depends on this, and what breaks if I move it."**

Measured 2026-09-13 in magentic-stack at `849583d`:

| Register | Shape | Holds |
|---|---|---|
| `upstreams/manifests/*.pin.json` | 5 files | git revisions + rollback targets |
| submodule gitlinks | 5 | the revision git actually has |
| `tooling/pins/base_image_digests.json` | 7 images | registry `FROM` digests |
| `runtimes/rails-base/FLOOR.json` | 1 | the declared floor + its known consumers |
| `@sha256:` in compose / Dockerfiles | 9 files | image pins at point of use |
| `tooling/pins/check_*.py` | 8 gates | each checks **one kind, in isolation** |

Six register shapes, eight gates, and **not one of them crosses a
kind**. `check_reversible_pins` proves a git pin can advance and roll
back. `check_base_digests` proves no `FROM` is undigested. Nothing
answers "the floor moved — who is now wrong?"

### The case that motivated this, from the same day

`FLOOR.json` moved to a **local, arm64, unpublished** image because that
was the only build carrying five new gems. The file documented it
honestly. It was still wrong in three ways that no gate could see:

1. Four consumers pin the floor. None can pull a local image.
2. The previous floor was **amd64**; the new one is **arm64**. An
   overlay built against it on an amd64 host fails with *"no match for
   platform in manifest"*, which reads like a bad digest and is not one.
3. Two fields were stale on arrival — `rev` named a commit that did not
   carry the gems, and a note said they "live in the working tree, not
   yet in that commit" after they had been committed.

Every one of those is a **dependency** fact. None of them is checkable
without a graph, which is why this plan is about edges rather than
about digests.

---

## The model: one identity, many placements

The single idea the CLI is built on.

```
RESOURCE            identity            = a digest. Never a tag, never a branch.
  └─ PLACEMENT      where a copy is     = local daemon | registry | a VPS | a git remote
  └─ REFERENCE      who names it        = a line in a file, in some repo
```

A resource is **one** thing with **many** placements. `sha256:8db4d39f`
present in the local Docker daemon, absent from GHCR, and running on
`sharedai.space` is one resource in three placement states — not three
resources. Modelling it the other way is how "it works on my machine"
becomes an architecture.

**Tags are not identity and are never stored as such.** magentic-stack's
`published_images.json` already says this in its own words: *"A mutable
tag is not a pin."* A tag is recorded as a *label observed at a time*,
resolvable to a digest, and never the key.

---

## Three kinds, and the trap in each

| Kind | Identity | The trap |
|---|---|---|
| **github repo** | 40-hex commit | A shallow clone **lies about ancestry**. `merge-base --is-ancestor` and `--contains` answer from local reachability, so a pinned commit can look orphaned when it is not. Ask the remote (compare API), not the checkout. |
| **local image** | image ID / repo digest | The image ID is **not** the registry digest unless the image was pulled. A locally built image has no repo digest until it is pushed, so `index_digest: false` is a real state and must be representable. |
| **remote image** | index digest **or** manifest digest | These are different digests for the same pull, and confusing them is the most expensive mistake here. |

### The index/manifest distinction, spelled out

`FLOOR.json` already carries the scar tissue: a multi-platform tag
resolves to an **index** digest; the index holds one manifest per
platform; and buildx adds an **attestation manifest** reported as
`unknown/unknown` that reads like a second platform to anyone who does
not know.

So the registry model stores, per remote image:

- the index digest, if there is an index
- each platform manifest digest, keyed by `os/arch`
- attestation manifests, marked as such and **excluded from platform
  counts**

A CLI that reports "2 platforms" for a single-platform image with an
attestation has already lost the operator's trust.

---

## Dependency relationships — the core

Edges, not nodes, are the product. Five edge kinds cover what exists
today:

| Edge | Example |
|---|---|
| `derives_from` | an overlay image `FROM` a base digest |
| `declares` | `FLOOR.json` declares the floor; `pinned_revision` declares a git pin |
| `references` | a `Dockerfile.thin` in another repo pins that floor |
| `carries` | a base image carries `vv-canvas 0.1.0` |
| `placed_at` | a digest present on a VPS, a registry, a local daemon |

`declares` and `references` are kept **apart** for the same reason
`vv-code-search` keeps them apart, and it is the reason the reverse
question is answerable at all: the declaration is where you change a
version; the references are what you must re-check *because* it changed.
A maintainer asking "what do I revisit" needs the second set, and a
naive "find the version" search returns only the first.

The three questions the CLI exists to answer:

1. **Forward** — what does this resource depend on, transitively?
2. **Reverse / blast radius** — if this digest moves, which references
   become wrong, in which repos?
3. **Drift** — where does a declared digest disagree with the placement
   that is actually there?

Question 3 is the one that catches the floor case: *declared* arm64
local, *placed* nowhere a consumer can reach.

---

## Do not rebuild the pin index

magentic-stack already ships `vv-code-search`, whose pins dimension
indexes **3,765 pin lines** across that tree, keeps `declares` apart
from `references`, and answers a per-line lookup in well under a
millisecond on a warm index.

**The CLI consumes it. It does not reimplement it.** Reimplementing
would produce a second answer to "which lines carry a pin", and two
answers to one question is how they start to disagree — which is the
same argument ADR 0038 makes about two copies of a gem.

What the CLI **adds** is the half that gem deliberately does not have:

- placements (registries, daemons, hosts — `vv-code-search` indexes
  files, not the world)
- cross-repo edges (it indexes one tree per index)
- resolution against live registries and hosts

Boundary, stated so it does not blur: **`vv-code-search` answers "what
does this line say". The CLI answers "and is that still true, and who
else cares".**

---

## CLI surface (target)

```
switchyard resource ls [--kind repo|local|remote] [--drift]
switchyard resource show <digest|name>        # identity, placements, edges
switchyard deps <digest|name> [--reverse] [--depth N] [--across-repos]
switchyard drift                              # declared vs placed, everywhere
switchyard placement sync <digest> --to <registry|host> [--push]
switchyard graph export --format json|mermaid|dot
```

Every command is **read-only by default**. `placement sync` is the one
that acts, and it moves bytes to a placement; it never edits a
declaration. Changing a pin stays a human edit in the owning repo —
`FLOOR.json` says exactly this about itself, and it is right:

> Edit this file. That is the whole mechanism, and it is deliberately a
> human act rather than something publish-images does on every commit.

`--to` a local daemon or a host **pulls**. Reaching a registry is a
**push**, and an outward act, so it is named explicitly with `--push` and
is never the default. `sync` moves an existing digest and only that: it
does not build and it does not tag. That is enough to fix the floor case
from one place — push the local arm64 build somewhere the four consumers
can reach — without the tool ever doing so on its own initiative.

**No persisted graph.** Every command re-resolves from `vv-code-search`,
the daemon, the registry and the hosts. No cache, no database. It costs
latency and buys the property `drift` is for: there is no stored copy to
go stale, so a reported disagreement is one that is true now.

Never-raise envelopes, reasons from a closed set, matching the CPCP
shape used throughout: `{ok:true, …}` / `{ok:false, reason, because}`.

Distinctions the output must keep (all three are different, and
collapsing them is the failure mode this whole plan is about):

| Result | Means |
|---|---|
| `not_indexed` | we never looked at this repo/host |
| `unreachable` | we looked and could not reach it — **not** evidence of absence |
| `absent` | we looked, reached it, and it is not there |

---

## Local Docker and remote VPSs

Both are **placements**, reached by adapters behind one interface.

| Placement | Reach | Identity it can report |
|---|---|---|
| local daemon | Docker socket | image ID; repo digest only if pulled |
| registry | `imagetools inspect` / registry API | index + per-platform manifests |
| VPS | SSH | what is running, and at which digest |
| git remote | GitHub API | whether a commit is reachable — **ask the remote** |

Rules that are not negotiable:

- **Read-only by default on every host.** A resource manager that can
  restart production because a flag was in the wrong place is a
  different product.
- **No credential is stored here, and none is read here.** SSH material
  lives in **ssh-agent** and nowhere this repo can see. The CLI shells
  out to `ssh` and inherits whatever the agent holds: no key path, no
  passphrase, no bearer parameter, nothing in a config file and nothing
  that can surface in an error path. vault (ADR 0046) stays
  magentic-stack's — depending on it would make a tool that otherwise
  only reads files need a running service to list a host.
- **A host that cannot be reached reports `unreachable`**, never
  `absent`. Silence from a VPS is not evidence its image is gone.

---

## Canvas comes later, and the graph is what it renders

`plan_sharedai_canvas.md` gives the canvas digest-named boards and
`board.put/get/list`. Dependency visualization lands there, and the
split holds:

- **the CLI computes the graph** — nodes, edges, drift, blast radius
- **the canvas renders it** — layout, interaction, a board per view

`graph export` is the seam between them, and it exists from stage 1 so
the canvas is never the only way to see the answer. A graph you can only
look at is one you cannot diff, grep, or put in CI.

One property to design for now rather than retrofit: **a board is
digest-named**, so an exported graph is itself a digest-addressed
resource. The dependency graph becomes a node in the dependency graph.
That is fine and worth doing deliberately — it is how "which view of the
world was this decision made against" stays answerable.

---

## Decisions taken — 2026-09-13

Six decisions were parked when this file was written, each because it
belonged to an owner rather than to a design. All six are now answered.
Recorded with what each one costs, because a decision written down
without its cost reads later as a free choice, and someone re-opens it.

| Decision | Choice | Costs / buys |
|---|---|---|
| Entry point | **Standalone Ruby, never boots Rails.** Packaged as a gem: `gem/vv-dependency-orch/`. | Costs a fourth entry point in a Rails-at-root repo and no reuse of app config. Buys the content-blind split as a *structural* fact, and a thing testable without the app. |
| CPCP seam | **None.** Local only. | Costs the canvas a live call; it reads an exported file instead. Buys this repo's "serves no seam" claim intact, and no content-reading surface on the network. |
| Graph storage | **Stateless.** Resolve live on every command. | Costs latency per call and transitive closure for free. Buys a `drift` that cannot be stale, which is most of what `drift` is for. Revisit at S6. |
| VPS credentials | **ssh-agent only.** | Costs unattended use without an agent. Buys a no-credential gate true by construction rather than by review. |
| `placement sync` push | **Allowed, behind an explicit `--push`.** Never default; moves an existing digest, never builds or tags. | Costs an outward act inside a read-mostly tool. Buys the floor case fixable from one place. |
| magentic-stack's registers | **Stay where they are.** Read across repos in v1. | Costs cross-repo reads. Buys leaving load-bearing files load-bearing. |

The entry-point row carries one amendment made when implementation
started: **the first surface is rake tasks, not a CLI.** A CLI is a
presentation of the model, and building it first makes the model's shape
a consequence of argument parsing. Order is model → rake → CLI → CPCP.
See [`plan_vv_dependency_orch.md`](plan_vv_dependency_orch.md).

What the stages may still reopen: **graph storage**, at S6, when
`deps --across-repos` first has a corpus large enough that re-resolving
hurts. Nothing else above is expected to move.

---

## Stages

| Stage | Ships | Acceptance (observable) |
|---|---|---|
| **S1** | Resource model + read-only inventory of the **local** daemon and this repo's declarations. `resource ls`, `resource show`. | A locally built image with no repo digest is represented honestly, `index_digest: false`, not as a missing digest. |
| **S2** | Registry adapter. Index vs per-platform manifests, attestations excluded from platform counts. | A single-platform image with a buildx attestation reports **one** platform. |
| **S3** | `deps` forward and reverse, over one repo, consuming `vv-code-search`'s pins dimension. | `declares` and `references` come back as disjoint sets. |
| **S4** | `drift`. Declared vs placed, across local + registry. | The floor case reproduces: declared local/arm64, no reachable placement for a named consumer → one finding, with the consumer named. |
| **S5** | VPS placement adapter, read-only, over SSH. | An unreachable host reports `unreachable`, never `absent`. |
| **S6** | Cross-repo edges: the known consumers of the floor. | Moving the floor lists the four repos that reference it. |
| **S7** | `graph export`. JSON first, mermaid second. | The export is diffable in CI, before any canvas exists. |
| **S8** | Canvas boards over the exported graph. | Visualization adds no fact the export does not already carry. |

Do not start at S8. Do not start at the VPS.

---

## Non-goals

- A container orchestrator. This reports and syncs; it does not schedule.
- A second pin index. `vv-code-search` has that job.
- Editing pins. Declarations are human edits in the owning repo.
- Storing credentials.
- A mutable `:latest` anywhere in the model.
- Making routing aware of any of this.
- Moving magentic-stack's registers here in v1.

---

## Gates (when it is built, not now)

- **Routing stays content-blind.** Plant: make a routing decision depend
  on a CLI-derived fact and prove the gate refuses it. This is ADR 0019's
  invariant and the one this plan puts most at risk.
- **No credential in the repo or in a log.** Plant: a secret in a
  placement config, and in an error path.
- **`unreachable` is not `absent`.** Plant: a host that times out must
  not report the image missing.
- **Tags are never identity.** Plant: a resource keyed by tag fails.
- **Attestations are not platforms.** Plant: an index with one platform
  plus an attestation reports one.
- **Shallow clones do not decide ancestry.** Plant: a shallow checkout
  that would answer "orphaned" must be refused or resolved against the
  remote.
- **`declares` and `references` stay disjoint.** Plant: collapse them and
  the reverse query loses the set a reviewer needs.
- **Read-only by default.** Plant: a write reached without an explicit
  flag fails.
- **The graph export is the source for any view.** Plant: a canvas board
  asserting an edge absent from the export.
- Zero jobs is a fail. A checker that has never been planted is not a
  gate.
