# MIND — the Magentic cognition container (NOOA, as-published)

MIND is one of the six containers of the pod (FRONT · BACK · BACKJOB · SWITCH ·
GRAPH · **MIND**). It **hosts NVIDIA NOOA** (NVIDIA Object-Oriented Agents) *exactly as
published* — pinned and unmodified from `upstreams/nooa/src` (commit `8b3c719`).
MIND is **not** a web service and owns **no UI** (FRONT, a Rails slice, owns all
UI) and **no durable state** (BACK/GRAPH own truth).

## What it does

A NOOA agent is an ordinary Python object: fields are state, the docstring is the
prompt, the typed return is the contract, and a `...` method body is the LLM loop
(`mind_agent.py`). The **harness** (`harness.py`) is the only seam around it:

1. **PULL** — reads Context *by reference* from BACK over the `/_cpcp` seam
   (`note.list`); the full records stay in BACK.
2. **Cognition** — runs the NOOA agent, via SWITCH, to produce a typed
   `NoteInsight` *proposal*. There is **no** deterministic fallback: with no
   tool-capable source configured, SWITCH refuses (`no_capable_model`) and the
   cycle logs `mind_error`. NOOA's contract IS a tool call, so a model that
   cannot call tools is not a degraded option, it is no option.
3. **PUSH** — proposes the Effect back over the same seam (`note.create`).
   BACK validates and commits it — **MIND cannot mark an Effect committed**.
   Domain state is written by BACK and BACKJOB (ADR 0056), not by MIND.
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

## The image is distroless

MIND runs the upstream agent and is the container this pod trusts least, so the
runtime stage carries a Python interpreter and nothing else. `/bin` and
`/usr/bin` hold only `python3.13` and glibc utilities — no shell, no `apt`/`dpkg`,
no `pip`, no compiler, not even `perl`. Code execution here has no `/bin/sh` to
reach for.

The `/_cpcp` seam was always what gated BACK; this is about how much is reachable
inside the box we already chose not to trust.

**The interpreter version is chosen by the base, not by us.** `gcr.io/distroless/
python3-debian13` ships 3.13, and NOOA requires `>=3.12,<3.14` — which is why
debian**12** (Python 3.11) cannot be used here. The builder stage must pin the
same minor version or the cp313 wheels will not import. **Bump both stages
together, never one.**

Debugging note: there is no shell, so `docker exec <container> sh` fails by
design. Use the interpreter directly:
`docker exec mind-pod-demo-mind-1 /usr/bin/python3.13 -c '...'`.
