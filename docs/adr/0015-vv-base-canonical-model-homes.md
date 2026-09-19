---
type: Architecture Decision
title: "Platform models get one canonical home"
adr_id: "0015"
status: accepted
date: "2026-08-26"
description: "The six platform models have their canonical ActiveRecord home in vv-base."
okf_version: "0.2"
tags: [gems, extract, rung-2, gold, refusal, vv-base]
resource: "magentic-stack/docs/adr/0015-vv-base-canonical-model-homes.md"
sources:
  - magentic-stack/docs/adr/0015-vv-base-canonical-model-homes.md
frame:
  layer: gems
  phase: extract
  freezes_at_rung: 2
  evidence: gold
  instrument: refusal
paths:
  - gems/vv-base/lib
  - gems/vv-base/db
enforced_by:
  - gems/vv-base/spec/vv_base_spec.rb
generated:
  by: claude-opus-5/claude-code
  at: 2026-09-19
---

# ADR 0015 — Platform models get one canonical home

## Decision

The six platform models have their canonical ActiveRecord home in `vv-base`. Consumers depend on the gem.

## Context

Actor, Persona, Journey, Flow, Mission and Vision were sitting in `runtimes/mind-pod/app/app/models` -- inside one runtime -- while being shared across profiles. Each of the six already carried a comment saying *canonical home, shared by P9 GHIS and P10 INTENT*, which is a model telling you it is in the wrong place. A shared model living inside one consumer means the second consumer either reaches into that runtime or copies the class. Both are worse than moving it.

## Frame

Layer **gems** (`gems/` — owned packages) · phase **extract** · freezes at **rung 2** · evidence **gold** · instrument **refusal**.

* [Layers](../frame.md#layers) — One canonical home per model is the layer rule at package granularity.
* [Instrument — refusal](../frame.md#instrument-refusal) — Uses the refusal instrument.

## Enforcement

A paid entry in the futures ledger — the constraint has a gate:

* `gems/vv-base/spec/vv_base_spec.rb`

## Source

* Full record: `magentic-stack/docs/adr/0015-vv-base-canonical-model-homes.md`
* Frame: [One Frame](../frame.md)
