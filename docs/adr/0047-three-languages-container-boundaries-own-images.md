---
id: "0047"
title: Three languages, container boundaries only, one image per container
status: accepted
date: 2026-08-30
subject_kind: doctrine
subject: developer cognitive load
components: [mind, switch, back, backjob, front, vault, config-admin, persist, projector]
paths:
  - runtimes
  - gems
  - tooling
enforced_by: []
supersedes: null
superseded_by: null
---

# Three languages, container boundaries only, one image per container

## The principle

**Optimize for minimum developer cognitive load.** Where a choice trades
developer coherence against execution efficiency, coherence wins. This is the
tie-breaker for every decision below and it is deliberately not hedged.

## Decision

### 1. Three languages, assigned by container

| Language | Container | Rationale |
|---|---|---|
| Python | `MIND` | the agent client; the NVIDIA/NOOA world is Python |
| Rust | `SWITCH` | the routing/bus plane |
| Ruby, in **Rails form** | everything else | one framework, one idiom, one test harness |

"Rails form" is not "Ruby somewhere". A new component is a Rails application
or a Rails engine, with the conventions that implies.

### 2. Boundaries are containers, exclusively

We do not express an architectural boundary as a role, a thread, a supervised
process group, or a module convention. If two things need a boundary, they are
two containers. If they do not, they are one.

This closes the `ROLE=X` question from `docs/reviews/2026-08-30h`. `ROLE` may
remain as a **start-up selector** where it exists today, but it is not a
boundary and no new boundary may be built on it.

### 3. One image per container

Every container ships its **own image**. Today `back`, `backjob` and `front`
all run `mind-pod:latest`; that ends.

This is what makes **hot-patch deployment** possible: a fix to one container is
built, pinned and rolled without rebuilding or redeploying the others. It is
also the direct answer to the coupling cost named in 2026-08-30h -- a shared
image means any gem change redeploys every role and a CVE anywhere touches
everything.

One image per container costs us the single-digest simplicity that memo (f)
liked about OCI provenance. We accept that: provenance gets N digests and a
manifest, which is a solved problem; coupled rollback is not.

## Carve-out: the browser is not a language choice

Code that executes **in a browser** is JavaScript because there is no other
option in that runtime. This is not a violation of the three-language rule; it
is outside it, because these are not containers.

- `gems/switchyard-offline` -- a Chrome MV3 extension plus a loopback listener
- `gems/vv-html-components` -- web components (`dist/*.js`, `test/*.mjs`)
- `gems/rails-osi-level-8/data/osi-level-8/ux-host-layout.js` -- a browser asset

Without this carve-out the rule is unimplementable. With it, the rule is about
the five or six things we actually deploy.

## Gap analysis (measured 2026-08-30 at d86881c)

| Component | Today | Target | Gap |
|---|---|---|---|
| `mind` | Python, own image | Python, own image | **conforms** |
| `switch` | **Node**, 17 `.mjs`, own image | **Rust** | largest gap; we have **zero** `.rs` files and `Cargo.toml` declares `members = []` |
| `back` | Rails, shared `mind-pod:latest` | Rails, **own image** | image split |
| `backjob` | Rails, shared image | Rails, own image | image split |
| `front` | Rails, shared image | Rails, own image | image split |
| `graph` | oxigraph, third-party pinned image | unchanged | third-party datastore, not our code |
| `vault` | does not exist | **Rails**, own image | build (ADR 0046) |
| `config-admin` | inside the Node switch | **Rails**, own image | build; NOT a Node split |
| `persist` | does not exist | Rails, own image | unauthorized, deferred |
| `projector` | does not exist | Rails, own image | unauthorized, deferred |

## The consequence this ADR does NOT resolve

**23 Python files under `tooling/` are our release gates.** Under "everything
else Ruby" they are out of policy. That includes `check_boundary`,
`check_closed`, `check_base_digests`, `check_loopback_env`, `population.py`,
and the whole `tooling/shacl` suite -- plus 4 validators in
`gems/osi-level-8-profiles`.

They are not containers, so the container-language rule does not reach them on
its own terms. But they are also not browser code, so the carve-out does not
cover them either. Rewriting them in Ruby is a real cost against gates that
currently work and that we have been hardening all week.

**This is recorded as an open decision, not silently exempted.** Naming it is
the point: a doctrine with an unexamined 23-file exception is not a doctrine.

## The open question this ADR does NOT answer

**What SWITCH is.** Three readings are live and they imply different Rust
services:

1. the LLM data plane (what today's `switch` does)
2. a RES-inspired pub/sub event bus (the operator's earlier framing, and
   memo (d)'s "SWITCH as bus")
3. both

And separately: its relationship to `upstreams/nemo-switchyard`, which is
NVIDIA's Rust Switchyard under a do-not-fork boundary (ADR 0038). Adopting
Rust for SWITCH makes that upstream newly relevant and newly dangerous.

No Rust may be written until this is answered.

## Amends ADR 0046

0046 said "the Node service is `llm-plane`" and assumed `config-admin` would be
split out of the Node process. Under this ADR:

- `config-admin` is a **Rails** application in its own container. It is built,
  not split out.
- `vault` is a **Rails** application in its own container. Every condition of
  0046 stands unchanged: authenticated allowlisted API, no default caller
  token, fail-closed boot, read-back asymmetry.
- SWITCH is Rust, pending the question above.
