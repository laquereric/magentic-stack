---
id: "0045"
title: CPCP is the Stage 2 SHAPE container; app-shacl-store is the Stage 3 surface
status: accepted
date: 2026-08-30
subject_kind: protocol
subject: shape package control plane
components: [rails-cpcp, rails-osi-level-8, app-shacl-store]
paths:
  - gems/rails-cpcp
  - runtimes/mind-pod/app/config/initializers
enforced_by: []
supersedes: null
superseded_by: null
---

# CPCP is the Stage 2 SHAPE container

## The question this closes

The Manus review of 2026-08-29b separated **Stage 2** (a SHAPE container inside
the pod) from **Stage 3** (shacl.store, the product), and left open which thing
`app-shacl-store` was. `docs/plans/app_shacl_store.md` recorded it as an owner
decision and deliberately did not choose. The follow-on review of 2026-08-30a
sharpened it but still deferred.

## Decision

- **`rails-cpcp` is the Stage 2 SHAPE container.**
- **`app-shacl-store` is the Stage 3 commercial surface**, and is not the
  container.

## Why this is not a new component

CPCP is already the thing a SHAPE container would have to be. In the MIND pod:

```ruby
# BACK role: the /_cpcp seam (rails-cpcp) is the ONLY write path.
mount RailsCpcp::Engine => "/_cpcp"
```

All seven live `CpcpAdapter.wrap` sites are there, and shape admission already
happens at that seam -- `Grounding` validates every inbound and outbound
document against a declared profile, closed-shape enforcement included.

So Stage 2 is **completing what exists**, not introducing something. Building a
separate SHAPE container would have created a **second seam**, and "`/_cpcp/rpc`
is the only pod seam" is an invariant this substrate has held through the entire
shape arc. A control plane that bypassed it to serve shape artifacts would have
been the highest-risk component in the pod by accident -- exactly what the
2026-08-29b review warned against under "do not build a seven-service
super-container".

## What each side owns

| | Stage 2: `rails-cpcp` | Stage 3: `app-shacl-store` |
|---|---|---|
| Where | inside the pod, at the only seam | outside, over the same contract |
| Owns | publication, retrieval, trust metadata, compilation, compatibility evidence, translation-profile metadata for versioned packages | namespaces, organizations, access control, discovery, the commercial surface |
| Never | a commercial or multi-tenant surface | pod-internal responsibilities, a second write path |

Both consume the **same format core**, which is why that core was built first and
as plain Ruby with no Rails: `PackageId`, `Closure`, `Manifest`, `Trust`,
`Translation`. Manus put the constraint precisely -- Stage 3 should be "an
externalized gateway/commercial layer over the same stable contract, not a
replacement for it."

## What this forecloses, deliberately

- `app-shacl-store` must not grow pod-internal responsibilities. If it needs to
  reach into the pod, the answer is a CPCP action, not a bypass.
- `rails-cpcp` must not grow tenancy, billing, or a public registry surface.
- Neither may become a second write path. BACK remains the sole writer; GRAPH
  remains the projection and is not the registry database; SWITCH keeps
  credentials.

## Open, and not decided here

**Dependency direction across repositories.** `rails-cpcp` lives in
`magentic-stack`; the format core lives in `magentic-market-ai/gems/app-shacl-store`.
If CPCP consumes the format, that is a cross-repository dependency from the
stack into the substrate galaxy, and the format may belong somewhere neutral --
or may need extracting from `app-shacl-store` so the Stage 3 surface and the
Stage 2 container depend on a shared artifact rather than on each other. This
ADR records the boundary; it does not choose the packaging.

**Prerequisites still hold.** 2026-08-30a's condition stands: do not treat this
as authorization to build. The narrow Stage 2 contract comes first, and the
Stage 3 surface waits until the core is exercised by at least two genuinely
independent namespace owners.
