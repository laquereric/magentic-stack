# Gap 59: the envelope already has non-Ruby callers

Census of the token `_cpcp/rpc` in py/js/mjs/rb plus `bin/backjob`.
Not docs. Not `tooling/`. 22 files. "Nine callers" does not survive
the split.

## Kinds

| kind | n | meaning |
|---|---:|---|
| **caller** | **5** | HTTP client of BACK's rails-cpcp envelope |
| **server** | 4 | serves a `/_cpcp` HTTP surface |
| **config** | 4 | path constant, comment, or template; no HTTP |
| **tooling** | 9 | spec / test |

## Callers of BACK (the envelope that must not change silently)

| file | lang | role |
|---|---|---|
| `runtimes/mind-pod/mind/harness.py` | Python | production MIND |
| `gems/rails-cpcp/front/app.py` | Python | gem **reference** FRONT; the deployed FRONT is Rails |
| `runtimes/mind-pod/app/app/controllers/home_controller.rb` | Ruby | deployed FRONT notes |
| `runtimes/mind-pod/app/app/services/back_cpcp_client.rb` | Ruby | deployed FRONT governance |
| `runtimes/mind-pod/app/bin/backjob` | Ruby | BACKJOB `l8.execution.complete` |

**Two Python callers of BACK. Zero JavaScript callers of BACK.**

ADR 0048 treated a non-Ruby implementation as future. The two Python
callers are present tense. JS is not a third caller of this envelope.

## Servers (do not count as callers)

- BACK: `rails-cpcp` `rpc_controller.rb` — the live envelope.
- `switchyard-offline` (`server.mjs`, `contract.js`, `service-worker.js`)
  serves a **local** CPCP-shaped API (`switchyard.route`, `cpcp.ready`).
  It does not POST to BACK. Counting it as a caller of the Rails
  envelope is how "nine" and "JS callers" got inflated.

MIND `/_cpcp/rpc` (0048) is unbuilt and is not in this census.

## How the five consume the envelope

- `harness.py` `unwrap`s `result` then checks `result["ok"]`. The
  never-raise flag lives on the **envelope**, not the result. A top-level
  `{ok:false, error:{reason,because}}` can look like a missing session.
  Not fixed here (census).
- `front/app.py` reads `r.get("ok")` on the envelope (correct layer),
  then `raise RuntimeError` on failure.
- `HomeController` digs `result` and does not check `ok` on create.
- `BackCpcpClient` checks `body["ok"] == true` and maps `error`.
- `backjob` parses JSON; transport failure becomes a local
  `{ok:false, error:{reason,because}}`.

An envelope-shape change has to be walked against these five, not
against nine, and not against the JS server.

## Gate

`tooling/cpcp/cpcp_callers.json` + `check_cpcp_callers.py`. A new
`_cpcp/rpc` site in product code that is not classified fails.
Plants: empty CHECK_ROOT; drop `harness.py` from the inventory; plant
a new Python POST. Population: 22 live + 22 inventory.

Did not change any caller. Did not start row 20.
