# Row 10 — MIND serves `/_cpcp/rpc`: is the row-14 block gone?

Measured 2026-09-03 from `d3e7a29`. **Design only. Not built.**

Row 10 reads "blocked by 14". Row 14 closed with
[`CPCP_BEHAVIOUR.md`](CPCP_BEHAVIOUR.md) (324 lines, 63 `file:line`
citations, 16 SPECIFIED vs 38 OBSERVED). The question this document
answers: does that closure unblock row 10? **Half.**

## What 0048 demanded, and what exists

0048's prerequisite: *"a written CPCP contract plus a conformance suite
that BOTH the Rails seam and the Python seam must pass."*

| Prerequisite half | Status |
|---|---|
| Written behavioural contract | **Exists as prose.** `CPCP_BEHAVIOUR.md` specifies envelope, idempotency, method registry shape. It is a document, not a suite — nothing executes it against a second implementation. |
| Shape distribution to non-Ruby | **Built since.** `ROLE=shape` serves TTL by digest (ADR 0049); `pyshacl==0.40.1` pinned. The 0048-correction prerequisite ("the TTL at runtime") is met. |
| NOOA push/pull mapping | **Unscoped.** 0048 names it; no method set, no caller, no authority statement exists. `harness.py` (174 lines) only *calls* BACK (`session.context`, `session.observe`); nothing describes what MIND would *serve*. |
| Cross-language conformance | **Absent.** `test/mind_boundary_test.py` (0048's stand-in) tests the client-only boundary. There is no fixture both seams must pass. |
| Prompt truth | **Pinned against change.** `mind_agent.py:58` ("no second socket") is false since 0048 and now pinned by `check_mind_prompt.py` (ADR 0059). Serving a seam needs a pin update plus re-audit against `GAP62_PROMPT.md` — a second workstream, not a drive-by edit. |
| Container + allowlist | **Unbuilt.** No `EXPOSE`, no server, no caller allowlist (0048: pod-internal, 0046-kind decision owed). |

## Verdict

**The row-14 block as written is gone; row 10 is not thereby buildable.**
The remaining blockers are smaller and named: method set, authority
statement, conformance execution, prompt re-audit, allowlist. None is a
research problem; together they are not one turn.

## Slices, in order

Slice 1 is approved in [`ROW10_SLICE1.md`](ROW10_SLICE1.md) (3 methods kept,
BACK may pull bounded-with-fallback, callers are conformance + debug +
config-admin). Slice 2 is built ([`GAP10_SEAM.md`](../archive/findings/GAP10_SEAM.md): stdlib
seam, gate, live proof). Slices 3–5 remain.

1. **Method set + authority (scope, small).** Which RPC methods MIND
   serves, and what each is authoritative for (0048's table has one live
   row and one blank). Until this is written, "BACK is the sole writer"
   stays unreadable literally — say so in the seam authority record,
   do not build around it.
2. **Stdlib seam + plant.** `http.server`, one method shape, unpublished,
   caller-allowlisted; a plant proves it serves the NOOA mapping and
   nothing else (0048's route-gate equivalent). No FastAPI/uvicorn —
   0048's constraint stands.
3. **Conformance execution.** Shared fixtures both seams pass (Python
   cases can run against BACK's seam as oracle first, MIND's second).
   This is the half of 0048's prerequisite that prose cannot satisfy.
4. **Prompt re-audit.** Pin update + `GAP62_PROMPT.md` re-audit. Gated by
   `mind-prompt.yml`; do not touch wording without it.
5. **Deploy + records.** Internal `EXPOSE`, compose wiring (no publish),
   `seam_authority.json` live row, `cpcp_callers.json` server entry,
   `role_routes.json`, `domain_writers.json` (MIND writes nothing new —
   assert it), entrypoint branch.

## Owner decisions this document will not take

| Decision | Why it is not mine |
|---|---|
| The method set and authority statement | Slice 1; phrases the contract. |
| The caller allowlist | 0046-kind call, per 0048. |
| Whether NOOA push, pull, or both map first | Shapes the seam surface. |
| Prompt wording | ADR 0059 + re-audit. |
| Amending 0048's "must be stated" row | Amendment, when slice 1 lands. |

## What this is not

- Not the seam. Not a method. Not a port.
- Not a second authority over domain state.
- Not a Python rewrite of the Rails envelope from prose alone.
- Not row 41, 48, or 11 work.
