---
type: Architecture Decision
title: "The seam refuses what the protocol forbids"
adr_id: "0042"
status: accepted
date: "2026-08-29"
description: "Close the Ruby to match the TTL."
okf_version: "0.2"
tags: [gems, extract, rung-3, gold, refusal, rails-osi-level-8, osi-level-8-profiles]
resource: "magentic-stack/docs/adr/0042-close-the-ruby-to-the-ttl.md"
sources:
  - magentic-stack/docs/adr/0042-close-the-ruby-to-the-ttl.md
frame:
  layer: gems
  phase: extract
  freezes_at_rung: 3
  evidence: gold
  instrument: refusal
paths:
  - gems/rails-osi-level-8/lib/rails_osi_level_8/grounding.rb
  - gems/rails-osi-level-8/data/osi-level-8
  - tooling/shacl/shape_compiler.py
enforced_by:
  - tooling/shacl/check_shape_runtime_artifact.py
generated:
  by: claude-opus-5/claude-code
  at: 2026-09-19
---

# ADR 0042 — The seam refuses what the protocol forbids

## Decision

**Close the Ruby to match the TTL.** Where a shape declares `sh:closed true`, Grounding refuses keys outside the declared set. The recorded divergence count goes to zero by changing the enforcement, not by relaxing the declaration. The alternative -- relax the TTL to describe what Ruby actually does -- was rejected. It would make the protocol document the implementation rather than constrain it, and `sh:closed` on a request shape exists precisely so a client cannot smuggle in fields the server never agreed to.

## Context

Step 5 built a compiler interface that compiles TTL and Ruby to a common IR and compares them at the seven live wrap sites. It recorded **11 divergences** and reconciled none, because reconciling is an owner decision. The substantive one: `osi:P1NoteCreateEffectShape` declares `sh:closed true` and enumerates its allowed paths. The Ruby branch checks the idempotency key, the title, and refuses a client-supplied `ledgerPlacement` -- and never rejects an unknown key. The code says so itself: `# Closed-ish`. …

## Frame

Layer **gems** (`gems/` — owned packages) · phase **extract** · freezes at **rung 3** · evidence **gold** · instrument **refusal**.

* [Instrument — refusal](../frame.md#instrument-refusal) — The canonical form: close the code to match the declaration, and drive divergence to zero by enforcing rather than relaxing.
* [The evidence ladder](../frame.md#the-evidence-ladder) — A declaration the runtime does not enforce is not Gold, whatever it says.

## Enforcement

A paid entry in the futures ledger — the constraint has a gate:

* `tooling/shacl/check_shape_runtime_artifact.py`

## Source

* Full record: `magentic-stack/docs/adr/0042-close-the-ruby-to-the-ttl.md`
* Frame: [One Frame](../frame.md)
