# Gap 63 step 2 — one collector, not 29 edits

Measured 2026-08-31 from `ef7f14e`. ADR
[0054](../adr/0054-never-raise-needs-an-observer.md). Census:
[`GAP63_CENSUS.md`](GAP63_CENSUS.md).

## Hypothesis test (before the design)

Claude: 16 of 29 are already on a wire; maybe one collector, not 29
edits.

**Holds, with a correction.** Census returned-wire is **22**, not 16.
They do **not** all go through `Envelope.fail`. `SessionCycle.refuse`
returns a hash that `Dispatcher` wraps in `Envelope.ok`. A collector
that only scraped `ok: false` on the outer envelope would miss
R13–R18.

So the collector watches:

1. outer `Envelope.fail` (`unknown_operation`, parse errors,
   `KnownRefusal` via the dispatcher patch, `handler_error`);
2. nested `{ok:false}` inside `Envelope.ok` (handler refuse hashes).

That is **one** hook in `Dispatcher.call` plus parse-error in
`RpcController`. Not 22 edits.

## How many sites actually change

| | Count | What |
|---|---:|---|
| Collector | 1 | `RailsCpcp::RefusalLog` + dispatcher + rpc parse fail |
| No-context emitters | 6 | publisher `#schedule` / `#drain_pending!`, blob `open`, idempotency store, `bin/backjob` ×2, `BackCpcpClient`, `HomeController` index/create |
| Gate | 1 | `tooling/cpcp/check_refusal_observer.py` |
| **Not edited** | 11 FALLBACK, 8 UNCLEAR | noise / contract change (64, 65) |

R23 (`:error`) is **instrumented**, return value unchanged.
R28 (redirect) is **instrumented**, redirect unchanged. Split from
"give them an envelope" — that would be a contract change. They now
meet the ADR floor without one.

## The durable record (new, not the journal)

JSONL + heartbeat, default `log/cpcp_refusals.jsonl` and
`log/cpcp_refusal_observer.json`. Override with `CPCP_REFUSAL_LOG` /
`CPCP_REFUSAL_HEARTBEAT`.

The journal needs `operation_request_cid`. Publisher, BACK-down,
idempotency, parse errors have none. A second table in osi-l8 would
couple FRONT/backjob to the journal gem. The JSONL is the language
boundary: Python/Rust can append the same shape later.

## Distinguishability

| State | Heartbeat file | Refusal lines |
|---|---|---|
| Observer never ran | **missing** | n/a — gate FAIL "observer did not run" |
| Ran, nothing refused | present `ran:true` | none |
| Ran, refusals | present | one JSON object per refusal |

Zero refusals with a heartbeat ≠ missing heartbeat.

## Observer survives its own failure

`RefusalLog.record` never raises. A write failure tries one
`kind=observer_failed` line. If that fails too, the heartbeat is
stale/missing and the gate fails closed. No second `record_refusal!`.
No infinite regress: the gate is the watcher of the watcher, and the
gate reads files, it does not rescue StandardError into a third log.

## What this does not do

- The 8 UNCLEAR (gaps 64, 65). No `ok` channel.
- FRONT create still redirects; the refusal is now on the log.
- Does not make capability probes chatty.
- Does not raise.
