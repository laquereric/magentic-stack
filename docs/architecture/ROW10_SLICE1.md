# Row 10, slice 1 (DRAFT for owner approval): MIND seam method set + authority

Follows [`ROW10.md`](ROW10.md). Nothing here is decided until approved;
nothing here is built.

## 1. What "push and pull" actually names

NOOA's own vocabulary is **remember/recall** (`nooa-memory` manager), not
push/pull. In 0048 and `harness.py`, push/pull name the harness cycle
*directions against BACK*: PULL context (`session.latest`,
`session.context`), PUSH proposal (`session.observe`). A MIND seam
therefore exposes the same two directions with MIND as the far side:

| Direction | Meaning on MIND's seam |
|---|---|
| Pull | ask MIND what it read and proposed (its outputs, by reference) |
| Push | ask MIND to run cognition on given rows (its inputs, bounded) |

## 2. Proposed methods (3)

| Method | Params | Returns | Authority |
|---|---|---|---|
| `mind.reading.latest` | `{}` | last cognition output: `reading` (typed proposal), `grounded_in`, `operationId`, `committed_by_back`, NOOA version/commit — or `recorded:false` before the first cycle | what MIND read and proposed |
| `mind.cognition.request` | `{session_iri, generation, rows[]}` (bounded, same shape BACK already serves MIND) | a receipt `{accepted, request_id}`; the reading lands where `latest` serves it | admission of a cognition job, not its result |
| `mind.up` | `{}` | liveness + NOOA version/commit (same shape as back/bus/shape `up`) | nothing; health only |

`request` is **admit, not execute**: a cognition cycle calls SWITCH and
takes minutes; holding a synchronous RPC open for it would couple the
caller to LLM latency. The harness loop picks up admitted requests ahead
of its BACK poll. Ordering between a pushed request and the session poll
is FIFO per request_id; generation mismatches are refused, not repaired
(`grounded_in` discipline — a reading that cannot name its ground is a
claim about nothing).

Refusals are non-200 plus envelope (row 49 KEEP BOTH), same as
vault/bus/persist. Unknown methods 400. No method writes domain state,
the journal, placements, or GRAPH — MIND writes only its own NOOA file
(third kind of state, ADR 0057) and stdout logs.

## 3. Authority statement (for `seam_authority.json` when built)

> MIND's seam is authoritative for **what MIND read and proposed**: the
> last reading, its ground, and whether BACK committed it. It is an
> **adapter surface over NOOA outputs**, not a second authority — a
> reading is a lead, not a fact (prompt doctrine), and shared truth stays
> what BACK admitted. Not domain state. Not the journal. Not placement.

Until this ships, "BACK is the sole writer" stays unreadable literally
(0048) — quote it with that caveat or not at all.

## 4. Caller allowlist (shape, identities later)

Pod-internal only, unpublished (0048). `MIND_CALLERS` env,
`{id: {token, operations}}`, empty fails closed at boot (0046 pattern).
First callers: the conformance suite (slice 3) and operator debug. BACK
does **not** call MIND's seam — the current direction (MIND dials BACK)
stands; inverting it would put BACK's completion behind MIND's
availability and needs its own decision, not a side effect of this one.

## 5. What approval unlocks, in order (ROW10 slices 2–5)

2. Stdlib `http.server` seam + plant (serves the 3 methods, nothing
   else). 3. Shared fixtures both seams pass (Python cases against
   BACK's seam as oracle first). 4. Prompt re-audit (`mind_agent.py:58`
   "no second socket" dies; `mind-prompt.yml` gates the wording).
5. Deploy (internal expose, compose, seam/route/census records) +
   entrypoint branch. None of 2–5 starts before this draft is approved.

## 6. Explicitly not proposed

* BACK pulling readings on demand (inverts the dial direction).
* Streaming/progress RPCs (one receipt, one result).
* Provider keys or model names on MIND (SWITCH owns those; unchanged).
* Writing anything outside the NOOA file (DomainWriters has no mind role
  because there is no Rails there — assert it stays that way).
* FastAPI/uvicorn (0048's stdlib constraint stands).
