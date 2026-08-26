---
id: "0021"
title: bin holds the repository's executable surface and builds no consumer
status: accepted
date: 2026-08-26
subject_kind: tooling
subject: bin
components: [bin]
paths:
  - bin/build-baselines
  - bin/docker-containers
  - bin/prereq
  - bootstrap
enforced_by:
  - bin/prereq
supersedes: null
superseded_by: null
---

## Context

Operational knowledge that lives in a README is knowledge that gets typed
differently by each person who reads it, and drifts from the repository the
moment either changes. It is also invisible to an agent as anything executable.

Two specific hazards shape what these scripts may do. A baseline image that
knows about a consumer inverts the dependency -- the thing meant to be depended
*upon* now depends on its dependant. And the VPS has 3.8GiB of RAM and ten
running containers, which makes a Rails bundle with native gems the worst thing
to build on it.

## Decision

`bin/` is the executable surface, and it is small on purpose:

- **`prereq`** checks tools and exits non-zero when any is missing, so a failure
  is a named missing tool rather than an error from deep inside a build.
- **`build-baselines`** builds the pod's baseline images and **may never
  reference a consumer**. A consumer such as `app-oriented-translation` builds a
  thin image `FROM` a baseline **by digest**, in its own repo. Cross-building
  happens here rather than on the VPS.
- **`docker-containers`** manages the demo pod lifecycle (`prereq|up|down|status`).

Three images cover five of the six containers -- back, backjob and front are one
image selected by `$ROLE`. `graph` is **pulled and pinned by index digest**,
never built.

## Consequences

- The bootstrap path is executable and reviewable, not prose.
- A consumer-specific build step has nowhere to go here, which is the intent.
- The one-image-three-roles choice means a change to any of the three rebuilds
  all three. Accepted: the alternative is three images that drift.
- `enforced_by` names `bin/prereq` itself. That is honest but weak -- it checks
  the environment, not the rules above. Nothing currently fails a build that
  makes `build-baselines` reference a consumer.
