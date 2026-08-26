---
id: "0015"
title: Platform models get one canonical home
status: accepted
date: 2026-08-26
subject_kind: gem
subject: vv-base
components: [vv-base]
paths:
  - gems/vv-base/lib
  - gems/vv-base/db
enforced_by:
  - gems/vv-base/spec/vv_base_spec.rb
supersedes: null
superseded_by: null
---

## Context

Actor, Persona, Journey, Flow, Mission and Vision were sitting in
`runtimes/mind-pod/app/app/models` -- inside one runtime -- while being shared
across profiles. Each of the six already carried a comment saying *canonical
home, shared by P9 GHIS and P10 INTENT*, which is a model telling you it is in
the wrong place.

A shared model living inside one consumer means the second consumer either
reaches into that runtime or copies the class. Both are worse than moving it.

## Decision

The six platform models have their canonical ActiveRecord home in `vv-base`.
Consumers depend on the gem.

## Consequences

- A schema change happens once, where the model is defined.
- `vv-base` is a dependency of anything using the platform vocabulary, including
  runtimes that previously owned these classes.
- The comment and the location now agree, so the next reader is not being warned
  about something they then have to act on themselves.
