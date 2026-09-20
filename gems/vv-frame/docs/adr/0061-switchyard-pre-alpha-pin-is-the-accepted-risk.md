---
type: Architecture Decision
title: "The Switchyard pin is the accepted pre-alpha risk, and it cannot move without a re-review"
adr_id: "0061"
status: accepted
date: "2026-09-03"
description: "The risk is accepted."
okf_version: "0.2"
tags: [upstreams, expand, rung-2, silver, pin, nemo-switchyard, switch]
resource: "magentic-stack/docs/adr/0061-switchyard-pre-alpha-pin-is-the-accepted-risk.md"
sources:
  - magentic-stack/docs/adr/0061-switchyard-pre-alpha-pin-is-the-accepted-risk.md
frame:
  layer: upstreams
  phase: expand
  freezes_at_rung: 2
  evidence: silver
  instrument: pin
paths:
  - upstreams/nemo-switchyard
  - upstreams/manifests/nemo-switchyard.pin.json
  - tooling/pins/check_switchyard_pin.py
enforced_by:
  - tooling/pins/check_switchyard_pin.py
  - .github/workflows/switchyard-pin.yml
generated:
  by: claude-opus-5/claude-code
  at: 2026-09-19
---

# ADR 0061 — The Switchyard pin is the accepted pre-alpha risk, and it cannot move without a re-review

## Decision

**The risk is accepted. The pin is what contains it.** 1. The originally accepted SHA is `47babb1a933e952bc6997b9ea208b5903c61a48c` (`accepted_pin` in this frontmatter). That SHA does not change when the live pin later moves; this body is not the live register. 2. The live pin is `upstreams/manifests/nemo-switchyard.pin.json` `pinned_revision`. The committed gitlink `upstreams/nemo-switchyard/src` must equal that field. Disagreeing records are a failure, not a migration. 3. A **working-tree drift** (populated `src/` HEAD ≠ gitlink) is also a failure, and a different fault from a deliberate gitlink move: someone checked out another commit without recording it. An unpopulated `src/` (git worktrees do not init submodules by default) is a checkout fact, not a pin move, and is not a pass of the HEAD check. 4. **A pin move** is `pinned_revision` ≠ this ADR's `accepted_pin`. …

## Context

Row 19 asked whether putting the pod's LLM plane on NVIDIA Switchyard was an unnoticed bet. Upstream says, in its own README under **Maturity** (`upstreams/nemo-switchyard/src/README.md`): Switchyard is pre-alpha software that is evolving rapidly. The API and algorithms are expected to change significantly before we reach v1.0. > [!WARNING] > Experimental software. Not for production use. The submodule is `upstreams/nemo-switchyard/src`, url `https://github.com/NVIDIA-NeMo/Switchyard` (`shallow = true`). …

## Frame

Layer **upstreams** (`upstreams/` — pinned, never forked) · phase **expand** · freezes at **rung 2** · evidence **silver** · instrument **pin**.

* [Instrument — pin](../frame.md#instrument-pin) — The canonical pin: the risk is accepted and the pin is what contains it.
* [The futures ledger](../frame.md#the-futures-ledger) — The accepted revision is write-once and does not move when the live pin moves — record beside query, in a pin.
* [The freeze ladder](../frame.md#the-freeze-ladder) — It cannot move without a re-review, which is the cascade priced before acceptance.

## Enforcement

A paid entry in the futures ledger — the constraint has a gate:

* `tooling/pins/check_switchyard_pin.py`
* `.github/workflows/switchyard-pin.yml`

## Source

* Full record: `magentic-stack/docs/adr/0061-switchyard-pre-alpha-pin-is-the-accepted-risk.md`
* Frame: [One Frame](../frame.md)
