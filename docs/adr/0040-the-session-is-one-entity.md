---
type: Architecture Decision
title: "One Session across human and agent actors, and it is not authorization"
adr_id: "0040"
status: accepted
date: "2026-08-28"
description: "One Vv::Base::Session whose actorkind is human or agent, sharing one graph."
okf_version: "0.2"
tags: [gems, extract, rung-2, gold, refusal, vv-base, mind-pod]
resource: "magentic-stack/docs/adr/0040-the-session-is-one-entity.md"
sources:
  - magentic-stack/docs/adr/0040-the-session-is-one-entity.md
frame:
  layer: gems
  phase: extract
  freezes_at_rung: 2
  evidence: gold
  instrument: refusal
paths:
  - gems/vv-base/lib/vv/base/session.rb
  - runtimes/mind-pod/app/app/services/session_cycle.rb
  - runtimes/mind-pod/mind/harness.py
enforced_by:
  - gems/vv-base/spec/session_spec.rb
  - runtimes/mind-pod/test/session_cycle_test.py
generated:
  by: claude-opus-5/claude-code
  at: 2026-09-19
---

# ADR 0040 — One Session across human and agent actors, and it is not authorization

## Decision

One `Vv::Base::Session` whose `actor_kind` is `human` or `agent`, sharing one graph. A person's visit and the MIND loop reasoning about it are the same session, because Level 8 is about the pairing rather than about either half. Splitting the model would put the cyborg pairing in a join table, where it becomes a thing you can forget to look at. MIND therefore attaches to a session already open rather than minting its own; `MIND_OPEN_SESSION=1` opts into a private one for a pod with no human in it.

## Context

The pod had no session of any kind. Adding one raised a real fork: is a user session a human's visit to FRONT, or a MIND cognition loop?

## Frame

Layer **gems** (`gems/` — owned packages) · phase **extract** · freezes at **rung 2** · evidence **gold** · instrument **refusal**.

* [Instrument — refusal](../frame.md#instrument-refusal) — One session across human and agent actors, and it is explicitly not authorization — a second authority refused by name.
* [Layers](../frame.md#layers) — Level 8 is about the pairing rather than about either half.
* [Trajectory](../frame.md#trajectory) — One session across human and agent actors, sharing one graph — a person's visit and the loop reasoning about it are the same path.

## Enforcement

A paid entry in the futures ledger — the constraint has a gate:

* `gems/vv-base/spec/session_spec.rb`
* `runtimes/mind-pod/test/session_cycle_test.py`

## Source

* Full record: `magentic-stack/docs/adr/0040-the-session-is-one-entity.md`
* Frame: [One Frame](../frame.md)
