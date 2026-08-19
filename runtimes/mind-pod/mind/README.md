# MIND — the Magentic cognition container (NOOA, as-published)

MIND is one of the five containers of the pod (FRONT · BACK · BACKJOB · GRAPH ·
**MIND**). It **hosts NVIDIA NOOA** (NVIDIA Object-Oriented Agents) *exactly as
published* — pinned and unmodified from `upstreams/nooa/src` (commit `8b3c719`).
MIND is **not** a web service and owns **no UI** (FRONT, a Rails slice, owns all
UI) and **no durable state** (BACK/GRAPH own truth).

## What it does

A NOOA agent is an ordinary Python object: fields are state, the docstring is the
prompt, the typed return is the contract, and a `...` method body is the LLM loop
(`mind_agent.py`). The **harness** (`harness.py`) is the only seam around it:

1. **PULL** — reads Context *by reference* from BACK over the `/_cpcp` seam
   (`note.list`); the full records stay in BACK.
2. **Cognition** — runs the NOOA agent to produce a typed `NoteInsight`
   *proposal* (or a deterministic fallback when no provider key is set).
3. **PUSH** — proposes the Effect back over the same seam (`note.create`).
   BACK validates and commits it — **BACK is the sole writer**; MIND cannot
   mark an Effect committed.
4. **Observation** — emits a bounded JSON projection (incl. the NOOA release
   identity). Not durable truth.

## Invariants (see ../docs/PRELIMINARY_DESIGN.md §1)

- No database credential, no direct GRAPH access.
- **Default-deny egress**: only BACK_URL and, if configured, one provider api_base.
- **Idempotent**: identical Context → same `operationId` → BACK returns the cached
  receipt, so MIND never double-writes.
- **Follow-without-coupling**: NOOA is installed from the pinned immutable source;
  a release is an explicit, recorded selection, never a floating latest.

## Run

```bash
bin/prepare                 # vendor pinned NOOA into vendor/nooa
docker compose up --build mind   # from ../  (needs BACK up)
```

Enable the NOOA LLM path (opt-in; otherwise deterministic cognition runs keyless):

```bash
export MIND_MODEL=... MIND_API_KEY=... MIND_API_BASE=...
```
