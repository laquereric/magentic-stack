---
id: "0040"
title: One Session across human and agent actors, and it is not authorization
status: accepted
date: 2026-08-28
subject_kind: gem
subject: vv-base
components: [vv-base, mind-pod]
paths:
  - gems/vv-base/lib/vv/base/session.rb
  - runtimes/mind-pod/app/app/services/session_cycle.rb
  - runtimes/mind-pod/mind/harness.py
enforced_by:
  - gems/vv-base/spec/session_spec.rb
  - runtimes/mind-pod/test/session_cycle_test.py
supersedes: null
superseded_by: null
---

## Context

The pod had no session of any kind. Adding one raised a real fork: is a user
session a human's visit to FRONT, or a MIND cognition loop?

## Decision

One `Vv::Base::Session` whose `actor_kind` is `human` or `agent`, sharing one
graph.

A person's visit and the MIND loop reasoning about it are the same session,
because Level 8 is about the pairing rather than about either half. Splitting the
model would put the cyborg pairing in a join table, where it becomes a thing you
can forget to look at. MIND therefore attaches to a session already open rather
than minting its own; `MIND_OPEN_SESSION=1` opts into a private one for a pod with
no human in it.

## What a Session is NOT

**It is not authorization.** The pod has no authentication. `actor_id` is
nullable, unconstrained, and asserted by whoever opened the session -- so a Session
identifies a SCOPE, not a principal. `session.open` returns `actor_proven: false`
and the model says the same thing in its own comment, because a Session looks like
an identity and would otherwise be read as one.

P6 authorization-evidence is NOT satisfied by a session existing. Anything needing
a proven actor must say so and fail closed until there is one.

A `NOT NULL` on `actor_id` would have forced callers to invent an actor, and an
invented actor reads as evidence. That is worse than a missing one.

## Notes

`Session` is deliberately absent from `Vv::Base::BARE_NAMES`. That list exists so
hosts can keep the OLD mind-pod top-level names; Session is new, has no legacy
name to preserve, and `Object::Session` is exactly the collision that list's own
comment warns about.
