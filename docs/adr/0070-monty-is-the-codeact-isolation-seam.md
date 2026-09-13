---
id: "0070"
title: Monty is the accepted CodeAct isolation seam, and it cannot move without a re-review
status: accepted
date: 2026-09-13
subject_kind: pin
subject: monty
components: [mind, adapters]
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
accepted_pin: "adc986b362e3961f407868cb118a99fe831b9e61"
---
# ADR 0070 — Monty is the CodeAct isolation seam

## Context

NOOA CodeAct executes model-written Python. Its own README calls the
in-process AST checks "a linter, not a sandbox." MIND is distroless, which
removes the shell, not the interpreter: `open()`, `socket`, and
`os.environ` still exist, so a cell can read `DB_PATH` SQLite and reach
the SWITCH egress path.

pydantic/monty is a Rust Python-subset VM. The filesystem, environment,
and network do not exist inside the sandbox except through the functions
and mounts the caller passes in. That is a CPCP Effect surface. It is
pre-V1 ("Hack Monty").

## Decision

1. **Monty is the isolation seam for CodeAct.** Wrap NOOA's CodeAct
   strategy; do not replace NOOA.
2. **The pin is gitlinked.** `upstreams/monty/src` at
   `adc986b3…` (2026-09-12), rollback `9fc149b4…`. Gate 4 round-trips
   that gitlink. The PyPI wheel `pydantic-monty==0.0.23` is how a MIND
   image *obtains the binary*; it is not a second pin. Distroless PATH
   omits `/deps/bin`, so the image sets `MONTY_BIN=/deps/bin/monty`.
3. **Reach only through `gems/adapters/monty/`.** Same rule as Switchyard
   (ADR 0030). `run()` never raises; CPython is not a fallback.
   MIND wraps NOOA via `event_manager.intercept("execute_python", …)`
   and does not call `nxt`.
4. **A SHA that merely appears in the tree is not a re-review.** Moving
   `pinned_revision` requires a `reviews[]` row (`sha/from_sha/at/by/looked_at/because`).

## Consequences

- Distroless remains the container boundary. Monty is the *interpreter*
  boundary inside it.
- Python *subset*: a cell that uses an unsupported construct is a typed
  refusal, not a fallback to CPython.
- Satellite mortality in the pydantic org (gateway archived, FastUI
  dormant) is why this is behind an adapter with its own ADR — the same
  treatment Switchyard got in ADR 0061.
- `enforced_by` names the pin checker, its plants, and the workflow.
  The live MIND image installs `pydantic-monty`. Compose named context
  `monty_adapter` COPYs `gems/adapters/monty` onto `PYTHONPATH`
  (`/opt/magentic/adapters`); that is owned source, not a prepare plant.
  The intercept is registered even if the adapter is missing: the cell
  is a typed refusal, not a return to `nxt`. CPython is not a fallback.
