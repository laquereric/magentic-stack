---
id: "0049"
title: ROLE=shape serves shape services from the gems already in the Rails image
status: accepted
date: 2026-08-31
subject_kind: topology
subject: shape services
components: [shapes-level-8, shapes-application, rails-osi-level-8, rails-cpcp, app-shacl-store]
paths:
  - gems/shapes-level-8
  - gems/shapes-application
  - gems/rails-osi-level-8
enforced_by:
  - tooling/shacl/check_catalog_manifest.py
  - docs/architecture/ROLE_SHAPE.md
supersedes: null
superseded_by: null
---

# ROLE=shape serves from mounted gems

## Decision

**Prior to `app-shacl-store` assembly, the Rails image provides shape services
through the gems it already carries**, exposed by a `ROLE=shape` container.

This closes the open item in `COVERAGE_GAPS.md` A2, which flagged a `shape`
container as contradicting ADR 0045. It does not contradict it: 0045 made
`rails-cpcp` the Stage 2 shape container and `app-shacl-store` the Stage 3
surface. `ROLE=shape` is the **interim serving surface between them**, built
from what is already in the image.

## The distinction that makes this safe

Two different things get called "shape services", and **only one of them can
move**.

| | Where it lives | Can it move to ROLE=shape? |
|---|---|---|
| **Shape ENFORCEMENT** -- closed-shape checking at admission | in-process in BACK: `RailsOsiLevel8::CpcpAdapter.wrap` in the initializers, calling `Grounding.closed_shape_violations` | **NO** |
| **Shape SERVICES** -- publication, retrieval, compilation, compatibility evidence (ADR 0045's list) | **nowhere; no HTTP surface exists today** | **YES -- this is the new work** |

Enforcement runs inside BACK's admission path. Moving it to another container
would put a network hop between a request and the decision to admit it, and
would make BACK's refusal depend on another container being up. **BACK keeps
the shape gems loaded regardless of `ROLE=shape`.**

So `ROLE=shape` is **additive, not a relocation**. If a later reader takes
"shape services live in ROLE=shape" to mean BACK no longer needs shapes,
admission breaks. That is the misreading this section exists to prevent.

## What is actually in the image today (measured at ba4864c)

- `gems/shapes-level-8` and `gems/shapes-application` are **Rails-free plain
  gems**. They are **bundled, not mounted** -- neither is an engine. "Mounted
  gems" is precise for `rails-osi-level-8` and `rails-cpcp`; for these two the
  word is bundled.
- Their own top-level seam is still a stub: `Shapes::Level8.catalog` returns
  `{}` and `bundle(version)` always answers `unknown_bundle ... catalog is
  empty (step 4 skeletons)`.
- **But the payload is real and is read today.** The live resolver is
  `RailsOsiLevel8::ProfileCatalog::SHAPE_MAP` (ADR 0044's per-shape map): 16
  shapes resolved to files inside those two gems, via `Gem.loaded_specs` with a
  `gems/<name>` fallback. 7 TTL are in place -- 2 in `shapes-level-8/bundles`,
  5 in `shapes-application/contracts/mind-pod`.
- `rails-osi-level-8` **is an engine but declares no controllers and no
  routes**. `rails-cpcp`'s engine draws only `rpc`, `cid.json`, `up`.

**There is therefore no shape HTTP surface anywhere in the stack.**
`ROLE=shape` is not exposing something that exists; it is the first place shape
services become reachable over HTTP.

## Gaps this opens

1. **The surface has to be designed, not just routed.** ADR 0045 lists what the
   Stage 2 container owns -- publication, retrieval, trust metadata,
   compilation, compatibility evidence, translation-profile metadata. None of
   it has an HTTP shape yet. Design it against 0045's list, not ad hoc.
2. **`osi.example` becomes externally visible.** `SHAPE_MAP` resolves eleven
   shapes under `https://osi.example/shapes/...`, a placeholder that does not
   resolve. Serving those IRIs from a shape *service* publishes the defect
   instead of merely storing it. The namespace decision, already open, is now
   on this path.
3. **Route-gating.** Per ADR 0047 amendment 2, `ROLE=shape` needs its own
   branch in `routes.rb`, drawing only the shape surface -- and BACK must keep
   drawing `/_cpcp` while still loading the shape gems in-process.
4. **52 TTL remain in `gems/osi-level-8-profiles`.** Only 7 have moved into the
   two shape gems. Whether the shape service serves the moved set only, or the
   whole catalogue, is undecided -- and step 10 of the shape arc (retire the
   legacy payload) has not run.

## What this does not decide

`app-shacl-store` remains the Stage 3 commercial surface and is unaffected.
This ADR is explicitly about the period **before** it is assembled.
