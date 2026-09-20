---
type: Architecture Decision
title: "BUS holds the state between the two halves of an RPC call and maintains integrity"
adr_id: "0055"
status: accepted
date: "2026-08-31"
description: "BUS is the holder of state between the two halves of an RPC call."
okf_version: "0.2"
tags: [runtimes, expand, rung-2, silver, ledger, bus, back, mind, switchyard]
resource: "magentic-stack/docs/adr/0055-bus-holds-the-state-between-rpc-halves.md"
sources:
  - magentic-stack/docs/adr/0055-bus-holds-the-state-between-rpc-halves.md
frame:
  layer: runtimes
  phase: expand
  freezes_at_rung: 2
  evidence: silver
  instrument: ledger
paths:
  - gems/rails-cpcp
  - gems/rails-osi-level-8
unenforced: true
generated:
  by: claude-opus-5/claude-code
  at: 2026-09-19
---

# ADR 0055 — BUS holds the state between the two halves of an RPC call and maintains integrity

## Decision

1. **BUS is the holder of state between the two halves of an RPC call.** It *is* Rails Event Store. 2. **Integrity is maintained by BUS.** 3. **Refusals a container has are a signal about THAT CONTAINER's health and quality**, not about the system. 4. **Participants in BUS JSON-RPC-LD conversations may require recompilation and redeployment when BUS imposes a change.** 5. **An envelope refusal must carry enough semantic content for an intelligent agent — AI or human — to decide how to RESTORE a broken process.**

## Frame

Layer **runtimes** (`runtimes/` — the governed pod) · phase **expand** · freezes at **rung 2** · evidence **silver** · instrument **ledger entry**.

* [Layers](../frame.md#layers) — State between the two halves of a call has an owner, and integrity belongs to that owner.
* [The futures ledger](../frame.md#the-futures-ledger) — A container's refusals are a signal about that container's health — declared, not yet gated.

## Enforcement

No gate named in the source record. The constraint is carried by the record alone.

**Declared unenforced** — a futures liability, booked rather than silent. See [The futures ledger](../frame.md#the-futures-ledger).


> ROLE=bus is accepted and unbuilt (row 9); stand-in is the current BACK seam spec

## Source

* Full record: `magentic-stack/docs/adr/0055-bus-holds-the-state-between-rpc-halves.md`
* Frame: [One Frame](../frame.md)
