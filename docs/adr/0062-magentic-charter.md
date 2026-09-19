---
type: Architecture Decision
title: "Magentic charter -- the stable core and where it lives"
adr_id: "0062"
status: accepted
date: "2026-09-03"
description: "Ownership tiers (ADR 0001, repo closed per 0038) 2."
okf_version: "0.2"
tags: [repo, extract, rung-4, gold, ledger, grammar, gems, runtimes, tooling]
resource: "magentic-stack/docs/adr/0062-magentic-charter.md"
sources:
  - magentic-stack/docs/adr/0062-magentic-charter.md
frame:
  layer: repo
  phase: extract
  freezes_at_rung: 4
  evidence: gold
  instrument: ledger
paths:
  - grammar/
  - gems/
  - runtimes/
  - tooling/
  - upstreams/
unenforced: true
generated:
  by: claude-opus-5/claude-code
  at: 2026-09-19
---

# ADR 0062 — Magentic charter -- the stable core and where it lives

## Decision

### 1. Ownership tiers (ADR 0001, repo closed per 0038) | Tier | Areas | Rule | |---|---|---| | OWN IT | `grammar/`, `gems/`, `runtimes/` | Deliberate, versioned, contract-driven. Breaking changes need an ADR. | | OFFICIAL | `apps/`, `plugins/` | Product velocity, but consumes owned contracts, never bypasses. | | FOLLOW THEM | `upstreams/` | Pinned, never forked. Pin moves need `reviews[]` re-review (0061). | ### 2. Grounding constructs * **Language (OSI Level 8).** Shapes are normative; Ruby reproduces them by hand; `pyshacl` + drift gates keep the two in step. Contract wins over code on disagreement. * **Governance pod.** One Rails app under many ROLEs plus MIND (Python), SwitchYard (NVIDIA Rust + CPCP endpoint), oxigraph. Twelve containers, four images. * **Adoption flywheel.** SwitchYard routes, ThreeDot grounds calls in the editor, MagenticMarket verifies offers -- all over CPCP. …

## Context

Sixty-plus ADRs record how the stack got here, including dead ends that were deliberately declined (RES, live swap, monads, second sqlite stores that never existed). New readers drown in deliberation; agents need the standing decisions in one place. This ADR promotes the stable core and points at the corpus. It decides nothing new. History lives in `docs/archive/` (reviews, closed findings). …

## Frame

Layer **repo** (repository / boundary doctrine) · phase **extract** · freezes at **rung 4** · evidence **gold** · instrument **ledger entry**.

* [Thesis](../frame.md#thesis) — The charter states the stable core: what is owned, what is followed, and why the split holds.
* [Layers](../frame.md#layers) — The tier table, restated as doctrine rather than as a directory listing.
* [The futures ledger](../frame.md#the-futures-ledger) — Declared as doctrine with its enforcement still outstanding.

## Enforcement

No gate named in the source record. The constraint is carried by the record alone.

**Declared unenforced** — a futures liability, booked rather than silent. See [The futures ledger](../frame.md#the-futures-ledger).


> Charter states; enforcement is per-area (boundary sweep, seam gates, writer gates, pin gates). No single mechanism enforces a charter.

## Source

* Full record: `magentic-stack/docs/adr/0062-magentic-charter.md`
* Frame: [One Frame](../frame.md)
