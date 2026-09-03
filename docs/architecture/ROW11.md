# Row 11 remainder — SwitchYard consolidation: keys to vault, UI to config-admin, retire `:13001`

Measured 2026-09-03 from `1c29d66`. Slices A–C built ([`GAP11_KEYS.md`](GAP11_KEYS.md), [`GAP11_UI.md`](GAP11_UI.md), [`GAP11_RETIRE.md`](GAP11_RETIRE.md)). **Slice D: design only. Not built.**

Row 11 v1 landed the pin behind the adapter (`37a355d`) and deliberately
deferred four things (gap table: UI move, keys to vault, retire `:13001`,
row 83). This scopes all four. The data plane is not in this document.

## 0. What is actually there

Data plane `:8789` (unpublished, MIND's only LLM path): `POST /v1/*`
reverse-fronts the pin; content-blind routing already gated. **Untouched
by every slice below.**

UI plane `:8790` (host `:13001`), all in `runtimes/switch/` (~900 lines
JS + 274-line UI):

| Endpoint | Function | State touched |
|---|---|---|
| `GET /`, `/ui.js` | browser surface (51 + 223 lines) | — |
| `GET /api/sources` | vendors, readiness, pins, prices (keys never leak — presence only) | read |
| `POST /api/sources` | active pin, routerPin, **key set/clear**, enabled, prices | `keys`, rest |
| `POST /api/refresh` | vendor discovery | `discovered` |
| `POST /api/verify-tools` | billed tool probes, enabled models only | `verified` |
| `POST /api/test` | single-model probe | — |

State file `sources.json` on `.agent/secrets:/state` (bind mount):
`{active, routerPin, keys, enabled, prices, discovered, verified}`.
Row 46: convert **neither** bind mount, touch nothing under `.agent/`.
0050 target: vault, which `llm-plane` may `get`.

Key flow today: browser → `:13001` → `state.keys[vendor]` →
`completeRemote` reads it per request. `:13001` is named in QUICKSTART,
both composes, GAP5/61, SWITCHYARD.md, adapter README, ContainerTopology,
POD_PHASE0_INVENTORY, and 0050 — retiring it is a docs sweep, not a
compose edit.

Gates touching switch today: `check_switchyard_algorithms` (12 examined,
content-blind plants), loopback, `check_credential_bind_mounts` (row 46),
`check_language_rule` (Node is a named **violation**, not exemption),
switchyard-pin.

## 1. Slice A — keys to vault (build)

Switch becomes a vault `get` caller (allowlisted `llm-plane`, per 0046 —
`config-admin` still cannot `get`). Key entry moves to the vault UI that
already exists; switch's key form and `state.keys` writes die. Non-key
state (`active/enabled/prices/discovered/verified`) stays in
`sources.json` on the untouched bind mount.

* Fetch path: vault at request time or boot-cached in memory? Request-time
  keeps revocation honest and matches `completeRemote`'s per-request read;
  failure (vault down, refused) surfaces as today's `missing_credential`
  refusal — never a fallback key, never an empty-string credential.
* Discovery/verify use the same fetch — one key path, not two.
* Gate: no key material in `/state` (plant a key in `sources.json`,
  expect fail) alongside the standing row-46 gate. `switchyard-pin`
  untouched.

## 2. Slice B — UI to config-admin (build)

Config-admin shows sources + test results (SWITCHYARD.md's retirement
condition), calling switch's `/api/*` server-side over the pod network —
browser never touches switch. Mirrors the placements build (row 41):
client, controller, views, routes, env, fail-closed boot, gate, census,
specs. Key entry is NOT mirrored (vault UI owns it). Verify/test stay on
switch (row 15 stands); config triggers and displays, on demand with
confirm — probes are billed calls, not page loads.

## 3. Slice C — retire `:13001` (build + docs)

Unpublish `8790` in both composes when slice B's display exists (the
documented condition — not before). Loopback healthcheck stays internal.
Sweep QUICKSTART, compose comments, GAP5/61, adapter README, topology
docs. Gate the absence: a host-published 8790 fails (same shape as the
bus/persist unpublished plants). **No new host port** (gap 61); data
plane stays unpublished throughout.

## 4. Slice D — row 83 cache-attest (verdict, probably not a build)

Row 83 decided the router owns reuse attestation. Against the pre-alpha
pin the adapter can only attest what it observes — and the identity
components (weights, tokenizer, template, sampling, adapter, cache
format) are still **not established** for the pinned server. If the pin
gives the adapter nothing to attest with, the honest output of this
slice is "blocked on upstream, conditions named" — **do not fake-attest**
(REFUSE reuse is already the safe default). Slice D may close as
decided-blocked rather than built.

## Owner decisions this document will not take

| Decision | Why it is not mine |
|---|---|
| Vault slot naming per vendor (5 key slots) | Credential layout; operator reversibility. |
| Vault allowlist membership for switch | Operator config, like all callers. |
| Fetch-at-request vs boot-cache for keys | Revocation honesty vs availability. |
| UI parity scope (all 6 endpoints or subset) | Product surface; cost of verify/test. |
| Cache-attest acceptance criteria | Decides whether slice D builds. |
| Touching `.agent/secrets` or converting the mount | Forbidden by row 46, not open. |

## What this is not

* Not the data plane (`:8789`, pin, algorithms — all v1, all standing).
* Not catalog/discovery/verify relocation (row 15 stands).
* Not a bind-mount conversion or a `.agent` touch (row 46 stands).
* Not a new host port (gap 61 stands).
* Not authorization to drop `:13001` before config replaces the display.
