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
  - docs/pydantic-upgrades.md
enforced_by: []
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
2. **The pin is declared, not gitlinked, until the adapter exists.**
   `upstreams/manifests/monty.pin.json` (`kind: declared`) records
   `adc986b3…` (2026-09-12) with rollback `9fc149b4…`. A gitlink and a
   Gate-4 round-trip land with the adapter, not before.
3. **Reach only through `gems/adapters/monty/`.** Same rule as Switchyard
   (ADR 0030).
4. **A SHA that merely appears in the tree is not a re-review.** Moving
   `pinned_revision` requires a `reviews[]` row (`sha/from_sha/at/by/looked_at/because`)
   once the pin is gitlinked. Until then the ADR `accepted_pin` is the
   claim.

## Consequences

- Distroless remains the container boundary. Monty is the *interpreter*
  boundary inside it.
- Python *subset*: a cell that uses an unsupported construct is a typed
  refusal, not a fallback to CPython.
- Satellite mortality in the pydantic org (gateway archived, FastUI
  dormant) is why this is behind an adapter with its own ADR — the same
  treatment Switchyard got in ADR 0061.
- `enforced_by` is empty until the adapter exists. An unenforced pin is
  recorded as such, not pretended otherwise.
