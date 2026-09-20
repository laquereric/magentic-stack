---
type: Architecture Decision
title: "SWITCH becomes SwitchYard (NVIDIA upstream + a CPCP endpoint); the bus and persistence become Rails ROLEs"
adr_id: "0050"
status: accepted
date: "2026-08-31"
description: "switch is renamed SwitchYard and contains ONLY NVIDIA Switchyard plus a /cpcp/rpc endpoint."
okf_version: "0.2"
tags: [runtimes, expand, rung-2, silver, pin, switch, nemo-switchyard, adapters, bus]
resource: "magentic-stack/docs/adr/0050-switchyard-is-the-upstream-plus-bus-and-persist-roles.md"
sources:
  - magentic-stack/docs/adr/0050-switchyard-is-the-upstream-plus-bus-and-persist-roles.md
frame:
  layer: runtimes
  phase: expand
  freezes_at_rung: 2
  evidence: silver
  instrument: pin
paths:
  - runtimes/switch
  - upstreams/nemo-switchyard
  - gems/adapters
  - tooling/cpcp/check_role_bus.py
  - runtimes/mind-pod/app/app/controllers/bus_cpcp_controller.rb
enforced_by:
  - tooling/cpcp/check_seam_authority.py
  - tooling/cpcp/check_role_bus.py
  - tooling/cpcp/check_withdrawn_quotes.py
unenforced: true
generated:
  by: claude-opus-5/claude-code
  at: 2026-09-19
---

# ADR 0050 — SWITCH becomes SwitchYard (NVIDIA upstream + a CPCP endpoint); the bus and persistence become Rails ROLEs

## Decision

1. **`switch` is renamed `SwitchYard` and contains ONLY NVIDIA Switchyard plus a `/_cpcp/rpc` endpoint.** We consume the upstream; we do not write our own router. 2. **New `ROLE=persist`** on the Rails image. 3. **New `ROLE=bus`** on the Rails image: ~~Rails Event Store, with a CPCP interface.~~ *(withdrawn, amendment 2)* ~~The RES bus therefore **moves out of SwitchYard into Rails**.~~ *(withdrawn, amendment 2)* ADR 0047's amendment said "SWITCH is the RES bus AND the LLM plane"; under this ADR SwitchYard is the LLM plane only. **Target is now 12 containers, 4 images** -- nine Rails ROLEs, MIND, SwitchYard, oxigraph.

## Frame

Layer **runtimes** (`runtimes/` — the governed pod) · phase **expand** · freezes at **rung 2** · evidence **silver** · instrument **pin**.

* [Instrument — pin](../frame.md#instrument-pin) — We consume the upstream; we do not write our own router.
* [Layers](../frame.md#layers) — Bus and persistence become roles on an image that already exists.
* [The futures ledger](../frame.md#the-futures-ledger) — Declared unenforced: a futures liability booked rather than left silent.

## Enforcement

A paid entry in the futures ledger — the constraint has a gate:

* `tooling/cpcp/check_seam_authority.py`
* `tooling/cpcp/check_role_bus.py`
* `tooling/cpcp/check_withdrawn_quotes.py`

**Declared unenforced** — a futures liability, booked rather than silent. See [The futures ledger](../frame.md#the-futures-ledger).


> Partial (gap 97). Enforced: per-seam authority (check_seam_authority.py); ROLE=bus seam and no-RES-as-job (check_role_bus.py, row 18). Unbuilt: ROLE=persist (row 8), SwitchYard replacement (row 11). Row 17 RES adoption is evaluated and declined (ROW17.md).

## Source

* Full record: `magentic-stack/docs/adr/0050-switchyard-is-the-upstream-plus-bus-and-persist-roles.md`
* Frame: [One Frame](../frame.md)
