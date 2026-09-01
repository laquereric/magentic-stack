---
id: "0041"
title: Two shape gems, split by role not namespace
status: accepted
date: 2026-08-29
subject_kind: protocol
subject: shapes-level-8
components: [osi-level-8-profiles, rails-osi-level-8]
paths:
  - gems/osi-level-8-profiles
  - gems/rails-osi-level-8/data/osi-level-8
enforced_by:
  - tooling/shacl/check_shape_gem_deps.py
  - tooling/shacl/check_shape_consumer_deps.py
  - .github/workflows/shacl-conformance.yml
supersedes: "0022"
superseded_by: null
---

# ADR 0041 — Two shape gems, split by role not namespace

Status: **proposed**. No files have been moved. No gem has been created.
This draft supersedes ADR 0022's *packaging* decision (one profiles gem next
to frozen grammar) with a two-gem destination. It **retains** ADR 0022's
decision that `grammar/osi-level-8` stays where it is, as normative prose.

Review: `docs/reviews/2026-08-29a-two-shape-gems-manus.md`.

## Context

Four TTL homes exist today: the canonical profiles package, the runtime pin
tree under `config.shape_root`, grammar prose with zero TTL, and ad-hoc
copies. Phase 0 named 171 NodeShapes. A namespace-only move of those 171
into `shapes-level-8` vs `shapes-application` would treat the current
coincidence — all 40 `bound_runtime` shapes live in application-side
namespaces, all 66 `bound_ci_only` shapes live in Level-8-side namespaces —
as a governing rule. That coincidence is a migration *signal*, not a
definition. A protocol shape can be runtime-enforced. A second application
needs its own contract.

ADR 0022 moved `osi-level-8-profiles` into `gems/` and kept
`grammar/osi-level-8` as the base spec. That grammar/profile split remains
correct. What 0022 did not decide is how many *shape* gems there are, or
what owns a shape whose IRI namespace disagrees with its role.

## Decision

Package shapes by **artifact role**. Record enforcement as metadata.

> A shape belongs in `gems/shapes-level-8` if its normative subject is an
> OSI Level 8 protocol profile or reusable protocol vocabulary, **and** its
> validity does not depend on one application's routes, persistence model,
> adapter behavior, or deployment configuration.
>
> A shape belongs in `gems/shapes-application` if its normative subject is
> an application's accepted request/response contract or an
> application-specific refinement of a protocol shape.

Runtime vs CI binding (`execution = runtime | ci | none`) is not the
ownership rule. Status (`active | quarantined | deprecated`) is not the
ownership rule. Authority (`source | generated`) is not the ownership rule.

`grammar/osi-level-8` is frozen in place and redirected, not deleted, not
moved into a gem. New protocol requirements are not added there.

The application gem may depend on the protocol gem. The protocol gem must
not depend on the application gem.

`osi.example/shapes` is an ownership defect. Those IRIs are quarantined
until a namespace ADR names successors. They are not silently renamed.

## Schema (every NodeShape, one row)

| field | values | decided by |
|---|---|---|
| `owner` | `level-8` \| `application` | the role rule above |
| `execution` | `runtime` \| `ci` \| `none` | call-site manifest (Phase 0) |
| `status` | `active` \| `quarantined` \| `deprecated` | lifecycle; default for unowned is quarantined, not deleted |
| `authority` | `source` \| `generated` | whether this TTL is the selected source or a compiled/runtime artifact |

Applied to all 171 shapes at `tooling/shacl/shape_owner_candidates.json`.

## Namespace + quarantine

The measured namespace partition (ux/session/meaning/osi.example = 103
application-side; remaining canonical profiles = 68 Level-8-side) is the
*starting inventory*, not the destination. Shapes where `owner` disagrees
with that partition are the migration risk and are listed, not reclassified
to look tidy.

Unowned shapes enter time-bounded quarantine with one row each. Deletion
requires zero references, no target, no generated output, no required
fixture, and signed evidence. The default is quarantine.

## Artifact identity

Historical `shape_digest` (SHA-256 of a file under `config.shape_root`)
stays immutable for old admission records. A move that preserves bytes
preserves the digest. A merge or canonicalization may not. Do not reinterpret
the field. Future work (not this step) introduces `shape_digest_v2` and
`shape_artifact_id` with dual-write.

## Consequences

- ADR 0022's "shapes are a gem, grammar stays" still holds; there are now
  two shape gems instead of one profiles package.
- Gate 2 continues to validate; it is not repointed in this step.
- A second application consumes `shapes-level-8` and ships its own
  `shapes-application/<app>/` contract. See `docs/architecture/SHAPE_GEMS.md`.
- This ADR does not create either gem, move any TTL, or change
  `config.shape_root`.
