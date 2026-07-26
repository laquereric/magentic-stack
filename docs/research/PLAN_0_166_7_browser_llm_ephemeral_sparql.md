---
id: PLAN_0_166_7
kind: slice
parent: PLAN_0_166_6
status: scoped
turn_class: doctrine
strategy: Infrastructure
authored_by: Claude (device-68-raven, SUPERDEV)
---

# PLAN_0_166_7 — Browser-LLM + ephemeral sqlite-sparql endpoint

> **Status:** filed; no slice briefs yet — fleet authors slice 1 brief next.
> **Parent:** [[PLAN_0_166_6]] — The MM Promise arc (plan-of-plans)
> **Doctrine:** [[mm_promise_browser_llm_triples_sparql]] +
> [[mm_usp_anonymous_persistent_sparql_for_browser_webmcp]] +
> [[platform_pov_federates_to_group_pov]] + [[project_webtransport_is_the_target]]

## Why this arc

This plan owns the **PLATFORM PRIMITIVE** named in the MM Promise:

> _Having an LLM (even a small one like NANO) in the browser with a
> compact set of triples + a service that turns a set of triples into
> a queryable graph IS the MM promise._ —
> [[mm_promise_browser_llm_triples_sparql]]

Three distinct things have to land before any domain UX (PLAN_0_166_10),
any corpus pipeline (PLAN_0_166_8), or any seeded application
(PLAN_0_166_9) has anywhere to plug in:

1. A **SPARQL store the browser can query** — without round-tripping
   to a server for every join.
2. A **substrate-side ephemeral SPARQL endpoint** that exists for the
   life of a Turn and vanishes when the Turn closes — so the heavier
   queries never leak corpus across Turns, and there is nothing
   server-side to garbage-collect manually.
3. A **browser-LLM** that drives both — Chrome built-in Nano when
   available, WebLLM as the universal fallback, and an adapter that
   the rest of the system treats as one engine.

This is the foundation. Everything Thread B, C, D ships consumes the
shapes this plan defines. The USP framing — **anonymous-session
Graph→SPARQL endpoint with persistence**, per
[[mm_usp_anonymous_persistent_sparql_for_browser_webmcp]] — only works
if this primitive is real.

## Why now

The in-substrate side is already further along than it looks:

- `vendor/sqlite-sparql/` ships an Oxigraph-backed SQL extension
  already wired through `bin/code-search`.
- `vendor/mm-hyper-source/` already assembles per-Turn `.nt` bundles
  (per [[project_blob_cache_architecture]]) — the substrate already
  produces the triples; the browser side just has to query them.
- Chrome's Nano + WebNN + WebGPU stack landed in 2026; WebLLM is the
  documented fallback for non-Chrome.

The missing piece is the **bridge** — the contract that lets a tiny
in-browser LLM run SPARQL it didn't generate over a corpus it didn't
load itself.

## The arc (3 slices)

### Slice 1 — WASM sqlite-sparql in-page round-trip

Deliverables:

- Build a WASM target of `vendor/sqlite-sparql/` callable from a
  browser page (Worker thread; no main-thread blocking).
- A tiny JS adapter (`mm-sparql-client`, under the existing component
  vocabulary per [[ui_pov_tea_nexus_component_unapologetic]]) that
  loads a `.nt` blob (or an array of blob IRIs the substrate streams)
  into the in-page store and exposes one method:
  `sparql(query, policy_handle) → { rows, citations[] }`.
- The store is **per-Turn, in-memory only** — no IndexedDB persistence
  in slice 1. Closing the tab drops the corpus. (Persistence is a
  follow-on under PLAN_0_166_3 territory.)
- Citations are blob IRIs, not file paths, per [[project_brief_iri_cas_always]].
- Smoke: a static HTML page loads a 100-triple fixture bundle via the
  `mm-sparql-client`, runs a SELECT, renders the row set + the IRI of
  every blob the SPARQL touched.

Acceptance:

- Cold-load + first SELECT under 500 ms on a 10 K-triple fixture on
  the operator's reference machine.
- The adapter is callable from BOTH the gamified-canvas mode and the
  traditional-form mode (per [[project_input_mode_duality]]) without
  a code fork — same JS surface, different host.
- A SPARQL syntax error returns a `{ ok: false, reason, because }`
  envelope; never throws. Matches the substrate-side never-raise
  doctrine.
- The `policy_handle` parameter exists from slice 1 — even though it
  is a no-op until PLAN_0_166_10 slice 3 wires federation. Locking
  the shape now keeps the federation hook from re-shaping the API
  later.

Out of scope for slice 1: substrate-side endpoint, browser-LLM, model
adapter, IndexedDB persistence, cross-Turn corpora.

### Slice 2 — Substrate-side ephemeral SPARQL endpoint (per-Turn lifetime)

Deliverables:

- A new MCB action `sparql_open` that returns a `{ endpoint_url,
  endpoint_token, expires_at }` envelope. The substrate spins up a
  per-Turn sqlite-sparql process (or attaches a per-Turn DB to a long-
  lived process) loaded with the Turn's corpus IRIs.
- A new MCB action `sparql_close` that tears the endpoint down. The
  Turn-protocol layer calls `sparql_close` automatically at
  `turn_close` time, per [[project_turn_protocol_owns_git]] and the
  per-Turn-one-brief pattern in [[feedback_per_pane_one_brief_resilient]].
- HTTP/3 + WebTransport per [[project_webtransport_is_the_target]] is
  the **target** wire (the prior empirical-verification note,
  [[reference_webtransport_verified_2026_06_06]], makes this
  actionable today). Fall back to HTTPS + SSE / fetch streams for
  browsers without WT support; same query envelope on both wires.
- The `endpoint_token` is single-Turn, single-origin — no static API
  keys, per the [[mm_usp_anonymous_persistent_sparql_for_browser_webmcp]]
  anonymous-session shape.
- Same `sparql(query, policy_handle)` surface as slice 1; the JS
  client picks in-page WASM vs substrate endpoint per a size
  heuristic (initially: small corpora in-page, large or cross-domain
  on substrate).
- Smoke: a fleet pane calls `sparql_open` against a fixture corpus,
  receives an endpoint URL, makes a query from the browser, gets rows
  back, closes the Turn, observes the endpoint is gone (next request
  returns `endpoint_expired`).

Acceptance:

- `sparql_open` → query → `sparql_close` round-trips under 200 ms
  RTT (substrate-local browser).
- Endpoints are **strictly Turn-scoped**: a `sparql_close` (or Turn
  timeout) wipes the in-memory corpus AND the token. A second request
  with the same token after close returns `endpoint_expired`, never
  silently re-uses a stale store.
- WebTransport path is the default when the browser advertises it;
  the SSE/fetch fallback is bit-for-bit interchangeable from the
  client perspective (same row envelope, same citation shape).
- The `policy_handle` flows through the substrate endpoint exactly as
  it does in slice 1's in-page store — the LLM does not see WHICH
  store answered.

Out of scope for slice 2: cross-Turn caching (a sibling concern under
[[project_blob_cache_architecture]]); multi-tenant endpoint sharing
(each Turn gets its own); SPARQL UPDATE (read-only in this slice;
write-back is its own arc).

### Slice 3 — Browser-LLM adapter (Chrome Nano + WebLLM fallback) + bridge

Deliverables:

- A `mm-browser-llm` adapter that exposes one method:
  `infer(prompt, { sparql_client, policy_handle }) → stream`.
- The adapter detects, in order:
  1. Chrome built-in `window.ai` (Nano) — preferred when available.
  2. WebLLM (WebGPU + a small instruction-tuned model the substrate
     pins per [[vv_learn_vs_vv_policy]] policy).
  3. Substrate-LLM fallback (calls a substrate MCB action that runs
     a small model server-side) — only if neither in-browser engine
     is available. This fallback is the ONLY path that leaves the
     browser; everything else stays on-device.
- The bridge: when the LLM emits a SPARQL call (per a documented
  tool-call shape), the adapter routes it through the `sparql_client`
  (slice 1 in-page OR slice 2 substrate endpoint — the LLM doesn't
  know which) with the `policy_handle` attached, streams rows back
  into the model's context, and resumes generation.
- The adapter records per-call `{ engine, tokens_in, tokens_out,
  sparql_calls, ms_total }` so [[project_unified_loss_signal_v01]]
  can score browser-LLM Turns alongside fleet Turns.
- Smoke: a fixture page asks `"How many trades did instrument X have
  in the seed corpus?"` against a fixture trading bundle. The model
  emits a SPARQL call, the bridge runs it, the model returns the
  natural-language answer + the row count + the cited blob IRIs.

Acceptance:

- Chrome Nano path runs the smoke end-to-end on a 10 K-triple corpus
  in under 3 s on the operator's reference Chrome.
- WebLLM fallback runs the same smoke on the same corpus on a fresh
  Firefox profile (no Nano available) without code changes — engine
  selection is runtime, not build-time.
- The substrate-LLM fallback is **observably distinct** in the UI
  (per the [[ui_pov_tea_nexus_component_unapologetic]] convention) so
  the user knows when the answer left their browser — privacy is a
  first-class affordance, not a hidden detail.
- Removing any one of the three engine paths still leaves a working
  smoke on at least one browser the fleet can verify on.

Out of scope for slice 3: model-picker UI (consumed by PLAN_0_166_10
but owned here as an adapter-level config); fine-tuning or LoRA
adaptation of the in-browser model; multi-turn agent loops longer than
one brief (single-Turn scoping per
[[feedback_per_pane_one_brief_resilient]]).

## Federation hook — where group POV lives

The federation hook in this plan is the `policy_handle` parameter
threaded through every layer:

- The in-page WASM store (slice 1) accepts a `policy_handle` and the
  SPARQL adapter treats it as a query-rewriting hook (slice 1: no-op;
  PLAN_0_166_10 slice 3 wires it).
- The substrate-side endpoint (slice 2) accepts the same
  `policy_handle` on `sparql_open` and applies the same rewriting
  rules server-side — so the SAME query produces the SAME shape of
  result whether it ran in-page or on the substrate.
- The browser-LLM adapter (slice 3) accepts a `policy_handle` and
  treats it as a system-prompt prefix — the group's POV shapes BOTH
  what the model says AND what the SPARQL returns.

The SHAPE is platform-owned (this plan); the CONTENT is group-owned
(per [[platform_pov_federates_to_group_pov]] and PLAN_0_166_8's
policy graph). Group-edited policy triples flow through the
[[name_vs_meaning_doctrine]] graph rather than code — no per-group
deploy.

This matches the federation pattern PLAN_0_166_5 slice 3 uses for
research backend choice and PLAN_0_166_10 slice 3 uses for answer
shaping: same hook, three consumers.

## Dependencies

- **Requires (already shipped):**
  - `vendor/sqlite-sparql/` — Oxigraph SQL extension (built).
  - `vendor/mm-hyper-source/` — per-Turn `.nt` assemble (shipped per
    [[project_blob_cache_architecture]]).
- **Requires (in flight):**
  - PLAN_0_166_6 — the Promise arc coordinator (this plan's parent).
- **Soft-requires:**
  - [[reference_webtransport_verified_2026_06_06]] — empirical proof
    WT is actionable today; slice 2 uses it.
  - [[project_unified_loss_signal_v01]] — slice 3 records adapter
    metrics into this signal.

## Enables

- PLAN_0_166_8 — the corpus pipeline produces blobs this primitive
  queries; nothing to query without 8, but 8 ships in parallel.
- PLAN_0_166_9 — AT-Trade is the first concrete corpus this primitive
  queries; the slice-3 smoke targets the trading-domain fixture once
  9 lands a seed bundle.
- PLAN_0_166_10 — the search-at-scale UX consumes the slice-3
  `infer()` + `sparql()` API as its only data path. Slice 2 of
  PLAN_0_166_10 explicitly swaps its fixture for this plan's output.
- Any future B2C domain UX (post-AT-Trade) consumes this primitive
  unchanged.

## Out of scope (whole plan)

- Cross-Turn corpus persistence in the browser. Slice 1 is RAM-only.
  Persistence is a follow-on; the right home is PLAN_0_166_3 territory.
- SPARQL UPDATE — read-only in this plan; corpus updates flow through
  the PLAN_0_166_8 pipeline, not via direct SPARQL writes from the
  browser.
- Multi-tenant endpoint sharing. Each Turn gets its own ephemeral
  endpoint; sharing is a future optimization with its own threat
  model.
- A model-picker UI. Slice 3 ships engine selection as runtime config;
  the picker UI is PLAN_0_166_10's concern (and even there, it is
  scoped out of the first slice).
- LoRA / per-domain fine-tuning of the in-browser model. The bridge
  is the unit of customization in this plan — group-specific behaviour
  comes from the `policy_handle`, not from per-group weights.

## Related doctrine / plans / memory

- Parent: PLAN_0_166_6 — the MM Promise arc (plan-of-plans)
- Sibling: PLAN_0_166_8 — WebMcp scrape → domain-scoped corpus
  (produces the blobs this primitive queries)
- Sibling: PLAN_0_166_9 — AT-Trade semantic KG (the first concrete
  corpus this primitive answers questions over)
- Sibling: PLAN_0_166_10 — Dynamic search-at-scale UX (the user-
  facing wrapper that consumes this primitive)
- Memory: [[mm_promise_browser_llm_triples_sparql]] — the doctrine
- Memory: [[mm_usp_anonymous_persistent_sparql_for_browser_webmcp]]
  — the USP framing this primitive realises
- Memory: [[platform_pov_federates_to_group_pov]] — federation
  flows through `policy_handle`
- Memory: [[project_blob_cache_architecture]] — hypersource is the
  substrate this plan reads from
- Memory: [[project_webtransport_is_the_target]] — slice 2's wire
- Memory: [[reference_webtransport_verified_2026_06_06]] — empirical
  evidence WT is actionable
- Memory: [[project_brief_iri_cas_always]] — citations are blob IRIs,
  never inline content
- Memory: [[project_input_mode_duality]] — gamified + traditional
  modes both consume the adapter without a fork
- Memory: [[ui_pov_tea_nexus_component_unapologetic]] — TEA + NEXUS
  + component arch is the implementation grammar
- Memory: [[feedback_per_pane_one_brief_resilient]] — Turn-scoped
  endpoint lifetime matches per-Turn-one-brief
- Memory: [[project_turn_protocol_owns_git]] — Turn protocol calls
  `sparql_close` automatically
- Memory: [[project_unified_loss_signal_v01]] — slice 3's metrics
  surface here
- Memory: [[vv_learn_vs_vv_policy]] — the WebLLM model pin is a
  vv-policy decision derived from vv-learn observations
- Memory: [[name_vs_meaning_doctrine]] — `policy_handle` is an IRI,
  not a rename target

## Status

- Coordinator plan PLAN_0_166_6 references this as Thread A.
- Slice 1 brief: not yet authored; fleet or SuperDev files
  `docs/orchestration/briefs/plan_166_7_wasm_sparql_slice1.md` at the
  next dispatch cycle.
- No code changes from this Turn; plan-authoring only per the parent
  brief.
