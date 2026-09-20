---
type: Architecture Decision
title: "An observed dataset is never persisted, and the read is the authorization check"
adr_id: "0070"
status: accepted
date: "2026-09-13"
description: "An observed dataset is session-lifetime data that is never persisted, and a viewer's own read is the authorization check."
okf_version: "0.2"
tags: [runtimes, extract, rung-3, gold, operate, adapters, vv-canvas, osi-level-8-profiles, back]
resource: "magentic-stack/docs/adr/0070-never-persist-datasets-and-the-inverted-observer-seam.md"
sources:
  - magentic-stack/docs/adr/0070-never-persist-datasets-and-the-inverted-observer-seam.md
frame:
  layer: runtimes
  phase: extract
  freezes_at_rung: 3
  evidence: gold
  instrument: operate
paths:
  - gems/adapters
  - gems/vv-canvas
  - gems/osi-level-8-profiles/profile-6-enterprise-authorization-evidence
  - gems/osi-level-8-profiles/profile-7-observation-and-outcome
  - gems/vv-base/lib/vv/base/session.rb
unenforced: true
generated:
  by: claude-opus-5/claude-code
  at: 2026-09-19
---

# ADR 0070 — An observed dataset is never persisted, and the read is the authorization check

## Decision

**An observed dataset is session-lifetime data that is never persisted, and a viewer's own read is the authorization check.** 1. **Never persisted.** A dataset obtained through an adapter from an external source exists in the response and in the viewer's browser. It is not written to the BACK/BACKJOB application store, not journalled as content, not projected into a named graph, and not stored as a blob. All four are `dataset_persist_refused`. The closed store set in `runtimes/mind-pod/app/config/store_bindings.json` gains no home for it, because it has none. 2. **The read is the check.** A dataset is fetched **per viewer, per render, with that viewer's own credential**. The source's ACL is the enforcement mechanism, applied by the source. We do not model it, mirror it, cache its verdicts, or ask it hypothetical questions about a third party. …

## Context

Two users open the same shared board. Both see a widget bound to the same query against the same source. They are not entitled to the same rows. Nothing in this repo says what happens next. The pieces that look like they should decide it do not: - **CPCP is silent on authorization.** `grammar/cpcp/` is a README-only scaffold; `grep -i authoriz` over it returns nothing. - **P6 and P7 are `proposed`** (ADR 0026, 0027) — Manus-drafted, no implementation. …

## Frame

Layer **runtimes** (`runtimes/` — the governed pod) · phase **extract** · freezes at **rung 3** · evidence **gold** · instrument **operate**.

* [Instrument — operate](../frame.md#instrument-operate) — Never persisted is the operate move applied to data: session-lifetime, rebuildable, holding no authority.
* [The evidence ladder](../frame.md#the-evidence-ladder) — The viewer's own read is the authorization check, so the record needed to authorize is the one already happening.
* [The futures ledger](../frame.md#the-futures-ledger) — Declared with its enforcement still outstanding.

## Enforcement

No gate named in the source record. The constraint is carried by the record alone.

**Declared unenforced** — a futures liability, booked rather than silent. See [The futures ledger](../frame.md#the-futures-ledger).


> Every gate this decision needs is unbuilt: the `invalid-literal-dataset` fixture, a store gate refusing observed content on the four durable paths, and the canvas binding constraint. It is also blocked on a precondition the repo does not have -- a proven actor (ADR 0040) -- so the per-viewer read cannot be performed for a named viewer today. Recorded as a rule now because the canvas plan is being written against it and would otherwise persist rendered values; see the blocker section.

## Source

* Full record: `magentic-stack/docs/adr/0070-never-persist-datasets-and-the-inverted-observer-seam.md`
* Frame: [One Frame](../frame.md)
