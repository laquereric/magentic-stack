---
type: Architecture Decision
title: "DB_PATH is controlled through CPCP effects, not deploy configuration"
adr_id: "0051"
status: accepted
date: "2026-08-31"
description: "Control of DBPATH for SQLite -- in MIND and in every Rails container -- moves to /cpcp effects."
okf_version: "0.2"
tags: [runtimes, expand, rung-2, silver, ledger, back, backjob, front, vault]
resource: "magentic-stack/docs/adr/0051-db-path-is-a-cpcp-effect.md"
sources:
  - magentic-stack/docs/adr/0051-db-path-is-a-cpcp-effect.md
frame:
  layer: runtimes
  phase: expand
  freezes_at_rung: 2
  evidence: silver
  instrument: ledger
paths:
  - runtimes/mind-pod/app/config/database.yml
  - runtimes/mind-pod/mind
enforced_by:
  - tooling/compose/check_store_bindings.py
  - tooling/cpcp/check_role_persist.py
unenforced: true
generated:
  by: claude-opus-5/claude-code
  at: 2026-09-19
---

# ADR 0051 — DB_PATH is controlled through CPCP effects, not deploy configuration

## Decision

**Control of `DB_PATH` for SQLite -- in MIND and in every Rails container -- moves to `/_cpcp` effects.** Where a container writes its database stops being a deploy-time constant and becomes a governed operation: admitted through a shape, carrying an `operationId`, producing a receipt. This is coherent with Flexible Determinism: storage location becomes an explicit, auditable fact at the deterministic plane instead of a property of whoever last edited compose.

## Frame

Layer **runtimes** (`runtimes/` — the governed pod) · phase **expand** · freezes at **rung 2** · evidence **silver** · instrument **ledger entry**.

* [The futures ledger](../frame.md#the-futures-ledger) — Where a container writes stops being a deploy-time constant and becomes a governed, admitted operation.

## Enforcement

A paid entry in the futures ledger — the constraint has a gate:

* `tooling/compose/check_store_bindings.py`
* `tooling/cpcp/check_role_persist.py`

**Declared unenforced** — a futures liability, booked rather than silent. See [The futures ledger](../frame.md#the-futures-ledger).


> DB_PATH as a CPCP effect records through ROLE=persist (persist.path.set/get, row 8) against the closed set (row 39, gated); applying a placement is still a restart, and no production caller exists yet. Stand-in for application is the compose env that binds the path. Scope: docs/archive/findings/ROW41.md.

## Source

* Full record: `magentic-stack/docs/adr/0051-db-path-is-a-cpcp-effect.md`
* Frame: [One Frame](../frame.md)
