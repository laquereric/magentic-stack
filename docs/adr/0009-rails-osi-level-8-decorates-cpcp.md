---
id: "0009"
title: rails-osi-level-8 decorates rails-cpcp rather than competing with it
status: accepted
date: 2026-08-26
subject_kind: gem
subject: rails-osi-level-8
components: [rails-osi-level-8]
paths:
  - gems/rails-osi-level-8/lib
  - gems/rails-osi-level-8/db
enforced_by:
  - gems/rails-osi-level-8/spec/rails_osi_level_8_spec.rb
supersedes: null
superseded_by: null
---

## Context

Grounding, ledger placement and profile evidence all need a place to live in a
Rails app. The obvious move -- a second engine with its own mount point and its
own RPC surface -- gives an agent two doors into the same system, and two doors
means the guarantees of one can be reached around via the other.

## Decision

`rails-osi-level-8` is **additive**: it mounts alongside `rails-cpcp` in the
BACK app and adds grounding (closed-SHACL validation), the three-ledger
discipline, and profile evidence. It never becomes a competing surface;
`/_cpcp` stays the single public seam.

SHACL shapes and normative profiles are authoritative; code derives from them.
Shape digests are pinned at load, so a shape correction is visible in evidence
rather than silently changing what validates.

## Consequences

- An app can adopt CPCP first and grounding later without changing its client.
- There is exactly one place to ask what a caller is allowed to do.
- The engine is useless without a host app. That is correct -- it is a semantic
  adapter, not a service.
