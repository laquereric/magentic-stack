---
type: Architecture Decision
title: "Marketplace delivery proceeds as numbered OKF overlays, in order"
adr_id: "0073"
status: accepted
date: "2026-09-18"
description: "Marketplace work ships as overlays 01–06, in delivery order: brief, Gate 3 offers, scheduling, trust ledger, matcher, billing."
okf_version: "0.2"
tags: [overlay, expand, rung-1, silver, rung, magentic-market]
resource: "magentic-stack/docs/adr/0073-marketplace-overlays-are-the-delivery-surface.md"
sources:
  - magentic-stack/docs/adr/0073-marketplace-overlays-are-the-delivery-surface.md
frame:
  layer: overlay
  phase: expand
  freezes_at_rung: 1
  evidence: silver
  instrument: rung
paths:
  - docs/overlays/index.md
  - docs/overlays/01-brief.md
  - docs/overlays/02-offers.md
  - docs/overlays/03-scheduling.md
  - docs/overlays/04-trust-ledger.md
  - docs/overlays/05-matcher.md
enforced_by:
  - docs/overlays/index.md
  - test/integration/gating_test.rb
  - test/integration/accounts_flow_test.rb
  - test/integration/status_bar_test.rb
  - test/integration/creation_page_test.rb
generated:
  by: claude-opus-5/claude-code
  at: 2026-09-19
---

# ADR 0073 — Marketplace delivery proceeds as numbered OKF overlays, in order

## Decision

1. **Marketplace work ships as overlays 01–06, in delivery order**: brief, Gate 3 offers, scheduling, trust ledger, matcher, billing. The index records the order; 03 and 04 may swap, nothing else moves. 2. **Each overlay is one OKF document** with substrate, overlay work, acceptance, and a call-to-action leaf. An overlay is done when its acceptance list holds, not when its code merges. 3. **No overlay claims a landing promise beyond its acceptance list.** Placeholders (`[PRICE]`, `[N]`) and early-access CTAs stay until the overlay that owns them lands; billing (06) removes the brackets last. 4. **The matcher (05) does not start before 01, 02, and 04 hold.** Fit ranking over unverified offers or without vouches and reviews to weight is the exact failure this order exists to prevent. 5. **Any content-reading in ranking is disclosed** in "How we use AI" as part of overlay 05. …

## Context

The people-marketplace landing promises twelve sections; two are real (brief-draft via modal, sponsored identity) and ten are commitments backed by early-access CTAs. Ad-hoc delivery against that surface has two failure modes, both already observed: work lands out of order (a matcher with nothing to rank, billing with nothing to charge for), and landing copy claims behavior no code exhibits. …

## Frame

Layer **overlay** (overlay — consumes the substrate) · phase **expand** · freezes at **rung 1** · evidence **silver** · instrument **freeze rung**.

* [Overlays](../frame.md#overlays) — The temporal overlay: numbered layers, in order, each done when its acceptance list holds.
* [Phases](../frame.md#phases) — The ordering rule is a rule against premature Extract — ranking before there is anything to rank.
* [The futures ledger](../frame.md#the-futures-ledger) — Declares its own chain break rather than leaving it silent.
* [Trajectory](../frame.md#trajectory) — An acceptance list is a slice's aim written where the next agent will read it.
* [The freeze ladder](../frame.md#the-freeze-ladder) — Uses the freeze rung instrument.

## Enforcement

A paid entry in the futures ledger — the constraint has a gate:

* `docs/overlays/index.md`
* `test/integration/gating_test.rb`
* `test/integration/accounts_flow_test.rb`
* `test/integration/status_bar_test.rb`
* `test/integration/creation_page_test.rb`

## Source

* Full record: `magentic-stack/docs/adr/0073-marketplace-overlays-are-the-delivery-surface.md`
* Frame: [One Frame](../frame.md)
