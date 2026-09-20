---
type: Architecture Decision
title: "Monty is the accepted CodeAct isolation seam, and it cannot move without a re-review"
adr_id: "0071"
status: accepted
date: "2026-09-13"
description: "Monty is the isolation seam for CodeAct."
okf_version: "0.2"
tags: [upstreams, expand, rung-2, silver, pin, mind, adapters]
resource: "magentic-stack/docs/adr/0071-monty-is-the-codeact-isolation-seam.md"
sources:
  - magentic-stack/docs/adr/0071-monty-is-the-codeact-isolation-seam.md
frame:
  layer: upstreams
  phase: expand
  freezes_at_rung: 2
  evidence: silver
  instrument: pin
paths:
  - upstreams/manifests/monty.pin.json
  - gems/adapters/monty
  - runtimes/mind-pod/mind/requirements.txt
  - runtimes/mind-pod/mind/Dockerfile
  - docs/pydantic-upgrades.md
enforced_by:
  - tooling/pins/check_monty_pin.py
  - tooling/pins/plant_monty_pin.py
  - .github/workflows/monty-pin.yml
generated:
  by: claude-opus-5/claude-code
  at: 2026-09-19
---

# ADR 0071 — Monty is the accepted CodeAct isolation seam, and it cannot move without a re-review

## Decision

1. **Monty is the isolation seam for CodeAct.** Wrap NOOA's CodeAct strategy; do not replace NOOA. 2. **The pin is gitlinked.** `upstreams/monty/src` at `adc986b3…` (2026-09-12), rollback `9fc149b4…`. Gate 4 round-trips that gitlink. The PyPI wheel `pydantic-monty==0.0.23` is how a MIND image *obtains the binary*; it is not a second pin. Distroless PATH omits `/deps/bin`, so the image sets `MONTY_BIN=/deps/bin/monty`. 3. **Reach only through `gems/adapters/monty/`.** Same rule as Switchyard (ADR 0030). `run()` never raises; CPython is not a fallback. MIND wraps NOOA via `event_manager.intercept("execute_python", …)` and does not call `nxt`. 4. **A SHA that merely appears in the tree is not a re-review.** Moving `pinned_revision` requires a `reviews[]` row (`sha/from_sha/at/by/looked_at/because`).

## Context

NOOA CodeAct executes model-written Python. Its own README calls the in-process AST checks "a linter, not a sandbox." MIND is distroless, which removes the shell, not the interpreter: `open()`, `socket`, and `os.environ` still exist, so a cell can read `DB_PATH` SQLite and reach the SWITCH egress path. pydantic/monty is a Rust Python-subset VM. The filesystem, environment, and network do not exist inside the sandbox except through the functions and mounts the caller passes in. That is a CPCP Effect surface. …

## Frame

Layer **upstreams** (`upstreams/` — pinned, never forked) · phase **expand** · freezes at **rung 2** · evidence **silver** · instrument **pin**.

* [Instrument — pin](../frame.md#instrument-pin) — A gitlinked pin with a named rollback, round-tripped by a gate.
* [Layers](../frame.md#layers) — Wrap the upstream strategy; do not replace the upstream.

## Enforcement

A paid entry in the futures ledger — the constraint has a gate:

* `tooling/pins/check_monty_pin.py`
* `tooling/pins/plant_monty_pin.py`
* `.github/workflows/monty-pin.yml`

## Source

* Full record: `magentic-stack/docs/adr/0071-monty-is-the-codeact-isolation-seam.md`
* Frame: [One Frame](../frame.md)
