---
type: Architecture Decision
title: "bin holds the repository's executable surface and builds no consumer"
adr_id: "0021"
status: accepted
date: "2026-08-26"
description: "bin/ is the executable surface, and it is small on purpose: - prereq checks tools and exits non-zero when any is missing, so a failure is a named missing tool rather than an error"
okf_version: "0.2"
tags: [repo, expand, rung-1, silver, refusal, bin]
resource: "magentic-stack/docs/adr/0021-bin-is-the-repos-executable-surface.md"
sources:
  - magentic-stack/docs/adr/0021-bin-is-the-repos-executable-surface.md
frame:
  layer: repo
  phase: expand
  freezes_at_rung: 1
  evidence: silver
  instrument: refusal
paths:
  - bin/build-baselines
  - bin/docker-containers
  - bin/prereq
  - bootstrap
enforced_by:
  - bin/prereq
generated:
  by: claude-opus-5/claude-code
  at: 2026-09-19
---

# ADR 0021 — bin holds the repository's executable surface and builds no consumer

## Decision

`bin/` is the executable surface, and it is small on purpose: - **`prereq`** checks tools and exits non-zero when any is missing, so a failure is a named missing tool rather than an error from deep inside a build. - **`build-baselines`** builds the pod's baseline images and **may never reference a consumer**. A consumer such as `app-oriented-translation` builds a thin image `FROM` a baseline **by digest**, in its own repo. Cross-building happens here rather than on the VPS. - **`docker-containers`** manages the demo pod lifecycle (`prereq|up|down|status`). Three images cover five of the six containers -- back, backjob and front are one image selected by `$ROLE`. `graph` is **pulled and pinned by index digest**, never built.

## Context

Operational knowledge that lives in a README is knowledge that gets typed differently by each person who reads it, and drifts from the repository the moment either changes. It is also invisible to an agent as anything executable. Two specific hazards shape what these scripts may do. A baseline image that knows about a consumer inverts the dependency -- the thing meant to be depended *upon* now depends on its dependant. …

## Frame

Layer **repo** (repository / boundary doctrine) · phase **expand** · freezes at **rung 1** · evidence **silver** · instrument **refusal**.

* [Layers](../frame.md#layers) — The executable surface is small on purpose and builds no consumer.
* [Instrument — refusal](../frame.md#instrument-refusal) — Uses the refusal instrument.

## Enforcement

A paid entry in the futures ledger — the constraint has a gate:

* `bin/prereq`

## Source

* Full record: `magentic-stack/docs/adr/0021-bin-is-the-repos-executable-surface.md`
* Frame: [One Frame](../frame.md)
