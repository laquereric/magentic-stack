---
id: "0050"
title: SWITCH becomes SwitchYard (NVIDIA upstream + a CPCP endpoint); the bus and persistence become Rails ROLEs
status: accepted
date: 2026-08-31
subject_kind: topology
subject: SwitchYard, bus, persist
components: [switch, nemo-switchyard, adapters, bus, persist]
paths:
  - runtimes/switch
  - upstreams/nemo-switchyard
  - gems/adapters
enforced_by:
  - tooling/cpcp/check_seam_authority.py
stand_in:
  - runtimes/switch/Dockerfile
  - upstreams/nemo-switchyard
  - docs/architecture/SWITCHYARD.md
  - docs/architecture/ROW17.md
unenforced: true
unenforced_because: "Partial (gap 97). Per-seam authority is gated by check_seam_authority.py (gap 20). ROLE=bus, ROLE=persist, and SwitchYard replacement are unbuilt (rows 9, 11). Row 11 scope is docs/architecture/SWITCHYARD.md. Row 17 RES adoption is unevaluated-as-built; analysis is docs/architecture/ROW17.md."
supersedes: null
superseded_by: null
---

# SwitchYard is the upstream; the bus is Rails

## Decision

1. **`switch` is renamed `SwitchYard` and contains ONLY NVIDIA Switchyard plus
   a `/_cpcp/rpc` endpoint.** We consume the upstream; we do not write our own
   router.
2. **New `ROLE=persist`** on the Rails image.
3. **New `ROLE=bus`** on the Rails image: Rails Event Store, with a CPCP
   interface.

The RES bus therefore **moves out of SwitchYard into Rails**. ADR 0047's
amendment said "SWITCH is the RES bus AND the LLM plane"; under this ADR
SwitchYard is the LLM plane only.

**Target is now 12 containers, 4 images** -- nine Rails ROLEs, MIND, SwitchYard,
oxigraph.

## What this resolves

| Was | Now |
|---|---|
| gap 12: no durable event repository anywhere | `ROLE=bus` (RES) + `ROLE=persist` |
| gap 13: write our own Rust, or consume NVIDIA's? | **consume**; our own `.rs` count stays zero, and that is now correct rather than a gap |

## Feature parity: what the upstream actually covers

Upstream describes itself as a Rust proxy for LLM traffic that routes across
providers, translates between OpenAI Chat / Anthropic Messages / OpenAI
Responses, and exposes Prometheus metrics. Crates include `switchyard-server`,
`switchyard-translation`, `libsy-llm-client`, `protocol`.

Against our Node service's seventeen `.mjs`:

| Our module | Upstream | Verdict |
|---|---|---|
| `router.mjs` | multi-backend routing algorithms | covered |
| `translate.mjs` | protocol translation, the same three formats | covered |
| `providers.mjs` | multi-backend client | likely covered |
| 8789 data plane | that is what the proxy IS | covered |
| `sources.mjs` (key + source config) | out of scope for a proxy | -> `vault` + `config-admin` |
| `ui/` + the 8790 admin API | not an upstream feature | -> `config-admin` |
| `catalog.mjs`, `discovery.mjs` | **not described** | **PARITY GAP** |
| `verify.mjs` | **not described** | **PARITY GAP** |

Catalogue, discovery and verification have no identified upstream home. They
either move to `config-admin`, become adapter code, or are dropped -- and that
is a decision, not a detail.

## Three things this ADR does not settle

### 1. What language is the `/_cpcp/rpc` endpoint, and does it fork?

"ONLY NVIDIA SwitchYard **and** a `/_cpcp/rpc` endpoint" is two things in one
container. ADR 0038 and the `adapters-sole-path-to-upstreams` gate forbid
forking, so the endpoint may not be a patch to upstream source. It is therefore
either a Rust crate built alongside `switchyard-server` -- Rust we write, which
sits awkwardly against "ONLY NVIDIA" -- or a separate adapter process in front
of the proxy, which could be Ruby and would keep our `.rs` count at zero.

`gems/adapters/` is named in ADR 0038 as the sole governed path to upstreams
and today **contains one file, a README**. Whichever way this goes, that is
where it lands.

### 2. Bus versus persist: RES *is* a repository

Rails Event Store writes events to a database. Memo `2026-08-30d` held that the
bus must not own the durable event repository and that PERSIST should. If
`ROLE=bus` runs RES, then either the bus owns the repository -- contradicting
that -- or the tables RES writes to are owned by `ROLE=persist`, which needs a
stated boundary between the two. **Undecided.**

### 3. The upstream calls itself pre-alpha

Upstream's own README: experimental, evolving rapidly, API expected to change
significantly before v1.0, and an explicit "not for production use" warning.
We would be putting the pod's entire LLM plane on it. That may well be the
right trade -- consuming it beats maintaining our own router -- but it should
be an accepted risk with a stated fallback, not an unnoticed one. The Node
service works today.

## Consequence: CPCP is now the universal interface, and the old invariant is dead

Seams after this ADR: BACK, MIND (0048), SwitchYard, and `ROLE=bus`. **Four.**

Every statement in the tree that the `/_cpcp` seam is *the only write path* was
written when there was one. That sentence is now false wherever it appears and
should be rewritten to say what it actually means: **BACK is the only writer of
domain state.** Each additional seam must state what it is authoritative for,
or "sole writer" degrades into folklore.

## New dependency

`rails_event_store` has **zero hits** in this repository. `ROLE=bus` adopts it.
Per memo `2026-08-30h`, that is adoption of new infrastructure, not relocation
of something we already run.

---

# Amendment: how bus and persist divide (closes gap 16)

> **BUS implements RES. PERSIST determines the filesystem write location for the
> Event Store.**

| Role | Owns | Does not own |
|---|---|---|
| `bus` | Rails Event Store: the event log's content, streams, append semantics, pub/sub, the CPCP interface | **where the log is written** |
| `persist` | the write-location decision, as a governed, admitted act | the events themselves; any query or delivery path |

## Why this is coherent, where "persist owns storage" was not

Gap 44 asked whether `persist` survives at all. It stalled on a hard fact:
**SQLite has no server**, so "persist owns physical storage" meant either a
database-engine migration or an API in front of ActiveRecord. Both are enormous;
neither was in scope.

This split avoids that entirely. `persist` is not a data server and never holds
an event. It is the **authority over placement** — the answer to *where does this
store write*, held in one place, changed only by an admitted operation.

`persist` therefore survives with a job it can actually do, and **gap 44 is
closed**.

## It unifies with ADR 0051

ADR 0051 made `DB_PATH` a CPCP effect and left an open question: gap 39 requires
the path parameter to be a **closed set** rather than a free-form string, and did
not say who holds that set.

**`persist` holds it.** The closed set of permitted write locations is exactly
the thing `persist` is authoritative for, and a `DB_PATH` change is an effect
`persist` admits or refuses. Gap 43 -- that a settable path makes
two-writers-on-one-file a runtime operation -- becomes `persist`'s invariant to
enforce, not a property scattered across callers.

## Departure from memo 2026-08-30d, deliberately

Memo `2026-08-30d` held that the bus must not own the durable event repository
and that PERSIST should. Under this amendment the bus **does** own the
repository's content.

That memo was reasoning about SWITCH-as-bus: a Rust router that also held every
provider credential, where combining routing with durable authority meant one
compromise took both. ADR 0050 moved the bus into Rails and left the credentials
in `vault`. The premise moved, so the conclusion does not carry. What the memo
was protecting -- that no single component holds credentials *and* durable truth
-- still holds, by a different arrangement.

## The one question this leaves

The decision names **the Event Store**. ADR 0051 makes `DB_PATH` an effect for
*every* Rails container and MIND. So: is `persist` the placement authority for
all of those -- the domain SQLite, NOOA's store -- or only for the event log?

The generalisation is the obvious reading and would be the more useful one, but
it is not what was said, and "one role decides where every store writes" is a
larger claim than "one role decides where the event log writes". **Recorded as
open (gap 48), not assumed.**

---

# Terminology: "the SWITCH ecosystem"

**"The SWITCH ecosystem" means the `SwitchYard` container TOGETHER WITH
`ROLE=bus`.** It does not mean Rails Event Store running inside SwitchYard.

This ADR moved RES out of SwitchYard into a Rails role, and ADR 0047 assigns
Rust to SWITCH — so RES *inside* SwitchYard would put Ruby in the Rust
container. The charter covers both components; the container boundary between
them stands.

## Naming note: the "Anthropic" in SwitchYard is a protocol, not an author

Asked and answered 2026-08-31: the SwitchYard container is **NVIDIA's
nemo-switchyard**, as this ADR records. `upstreams/nemo-switchyard/src` points at
`NVIDIA-NeMo/Switchyard`.

The confusion is worth writing down because it will recur: the upstream's
headline feature is **translating between OpenAI Chat, Anthropic Messages and
OpenAI Responses formats**, and `gems/switchyard-offline` — our own Chrome MV3
router — also speaks Anthropic Messages. "Anthropic" in this codebase names an
**API format being translated**, never an authorship.

That is now three things wearing the SwitchYard name: the NVIDIA upstream, our
Node `switch`, and `gems/switchyard-offline`. The rename in ADR 0047 was aimed at
two of them.
