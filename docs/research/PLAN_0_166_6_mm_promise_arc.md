---
id: PLAN_0_166_6
kind: coordinator
parent: PLAN_0_166_0
status: scoped
turn_class: doctrine
strategy: Infrastructure
authored_by: Claude (device-68-raven, SUPERDEV)
---

# PLAN_0_166_6 — The MM Promise arc (plan-of-plans)

> **Status:** master coordinator filed; four child plans + brief for the fleet at
> `docs/orchestration/briefs/plan_166_6_author_child_plans.md`.
> **Doctrine:** [[mm_promise_browser_llm_triples_sparql]]

## The Promise (operator's words, 2026-06-12)

> **Having an LLM (even a small one like NANO) in the browser with a
> compact set of triples (see all work to date) with a service that
> turns a set of triples into a queryable graph IS the MM promise.**
>
> The WebMcp problem is reduced to:
> 1. Scrape WebMcp content per domain.
> 2. Store those triples in MM by domain.
> 3. Deliver search experience through web and through sqlite-sparql
>    ephemeral endpoints.
>
> **MM wires itself into a dynamic search experience at scale.**

## Why this is a plan-of-plans (not one big plan)

Four distinct arcs, each big enough to deserve its own plan + brief +
slicing, but ALL serving the same MM Promise. A single plan would
blur the seams; four child plans + one coordinator preserves the
seams while making the THROUGH-LINE explicit.

## The four threads

### Thread A — The Promise as primitive
**Plan:** PLAN_0_166_7 — Browser-LLM + ephemeral sqlite-sparql endpoint

- LLM in the browser (Chrome built-in Nano, WebLLM, or operator-of-the-day
  choice). Cheap, fast, private.
- sqlite-sparql either WASM-built in the page OR served by a
  substrate-side ephemeral endpoint that vanishes when the Turn closes.
- The bridge: browser-LLM queries the ephemeral SPARQL endpoint; results
  flow back into the model's context. Substrate hosts the corpus; browser
  hosts the agent.
- This is the canonical PLATFORM PRIMITIVE — every subsequent domain
  consumes this.

### Thread B — The corpus pipeline
**Plan:** PLAN_0_166_8 — WebMcp scrape → domain-scoped triples corpus

- WebMcp content gets scraped per-domain (Manus browser-IO, headless
  Chrome, or substrate-side workers — transport TBD).
- Triples land in hypersource CAS, organized by **domain IRI** (not
  per-file like the code path).
- Idempotent: re-scrape produces same blobs (content-addressed); change
  detection drives delta updates.
- Domains get policy + ownership per `platform_pov_federates_to_group_pov`
  (federation makes group-owned corpora possible).

### Thread C — First application: AT-Trade semantic KG
**Plan:** PLAN_0_166_9 — AT-Trade semantic KG (trading domain seed)

- Seed sources: `other/ibkr_api` and `other/multicharts-api` private
  submodules + public market-data ontologies.
- Domain IRI: `urn:mm:domain:financial-trading` (or similar).
- Application: `vendor/app-at-trade` consumes the KG to render
  instrument cards, trade hypotheses, and live P&L grounded in the
  semantic graph.
- **This is AT-Trade's VALUE PROPOSITION** — not the UI, not the IB
  Gateway connection: the semantic KG over financial trading. Anyone
  can wire IB Gateway; only MM gives AT-Trade a queryable trading KG.
- First domain through the pipeline = proof the pipeline works.

### Thread D — The realized experience
**Plan:** PLAN_0_166_10 — Dynamic search-at-scale UX

- User-facing UI that wraps threads A+B+C into ONE experience:
  - User opens browser.
  - Domain-scoped corpus loads (or partial; lazy).
  - Browser-LLM agent answers queries against the corpus.
  - Substrate serves SPARQL when in-browser scale runs out.
- **MM at scale** — millions of browsers, each running a tiny LLM +
  a tiny corpus, federated through MM substrate for the heavy lifts.
- This is THE B2C surface. PLAN_0_166_0 (AndrewT VIBE/SME) becomes one
  instantiation; every domain group gets the same shape with their POV.

## How the threads connect

```
  [A: Promise primitive]    ← platform substrate; everyone uses it
          ↑
          │
  [B: Corpus pipeline]      ← feeds A with per-domain triples
          ↑
          │
  [C: AT-Trade seed]        ← first concrete corpus through B,
          │                    consumed by A
          ↓
  [D: Search-at-scale UX]   ← wraps A+B+C into the user-facing
                              dynamic search experience
```

Dependency order for shipping: A is foundational; B can ship in parallel
for any domain; C is the FIRST-DOMAIN smoke that proves A+B; D is the
UX that wraps everything but doesn't block A/B/C individually.

## Pre-existing substrate dependencies (already shipped or in flight)

- **Hypersource** (`vendor/mm-hyper-source/`) — blob CAS + per-Turn
  assemble (PLAN_0_165 family, already shipped).
- **sqlite-sparql** (`vendor/sqlite-sparql/`) — SQL-loadable Oxigraph
  extension (built, already wired through `bin/code-search`).
- **PLAN_0_166_2** — CI submodules via hypersource IRIs (lets CI consume
  `other/ibkr_api` content for slice C without git creds).
- **PLAN_0_166_3** — Memory persistence (substrate-side typed semantic
  storage; the corpus pipeline writes there).
- **PLAN_0_166_5** — Manus research delegate via Browser IO (B2B path to
  enrich domain corpora with deep research).
- **PLAN_0_166_4** — NVIDIA deep-research engine (the open-source
  complement; produces enrichment corpora).

This plan REQUIRES NONE of the in-flight plans to ship FIRST — the
four child plans can start whenever the fleet is ready.

## What each child plan must contain

**Every child plan follows the established template:**
- Why this arc + the slice list (3-ish slices each).
- Acceptance criteria per slice (the fleet can test against).
- Out-of-scope discipline.
- Related memory + plans for context.
- Status section at the bottom.

**Plus, per the THROUGH-LINE:**
- Each child plan references PLAN_0_166_6 as parent (this doc).
- Each child names the OTHER child plans it depends on + which it
  enables.
- Domain handling for A/B/D goes through `platform_pov_federates_to_group_pov`
  (groups own their corpora + policy).

## Operator-side decisions still open

- **Browser-LLM choice** (A): Chrome built-in Nano (assumes Chrome
  Canary or Chrome 127+) vs WebLLM vs both. Default: both — substrate
  detects, falls back.
- **SPARQL transport** (A): in-page WASM sqlite-sparql vs substrate
  HTTP endpoint vs WebTransport (per `project_webtransport_is_the_target`).
  Default for slice 1: in-page WASM; substrate HTTP for amplification.
- **Scraping transport** (B): Manus Browser IO (PLAN_0_166_5) vs
  headless Chrome from substrate vs operator's browser-harness. Pick
  per-domain in slice 2 of B.
- **First domain after AT-Trade** (B follow-on): operator-named; not
  scoped here.

## Related doctrine / plans / memory

- Memory: [[mm_promise_browser_llm_triples_sparql]] — the doctrine
- Memory: [[platform_pov_federates_to_group_pov]] — group-owned corpora
- Memory: [[mm_two_faces_b2c_b2b]] — the Promise is the B2C narrative
- Memory: [[project_blob_cache_architecture]] — hypersource is the substrate
- Memory: [[project_vibe_programmer_andrewt]] — AndrewT consumes AT-Trade
- PLAN_0_166_0 (AndrewT VIBE/SME DX) — the prototype consumer
- PLAN_0_164_0 (substrate manages git via blobs) — same family of
  IRI-not-bytes thinking
- PLAN_0_163_0 (L as audit primitive) — L observes which paths work best
- All the PLAN_0_166_* plans filed today — enabling primitives

## Status

- Coordinator: this doc.
- Brief asking fleet to author the four child plans:
  `docs/orchestration/briefs/plan_166_6_author_child_plans.md`.
- Child plans (to be authored by fleet): PLAN_0_166_7 / _8 / _9 / _10.
- No code changes from this Turn; SuperDev plan-of-plans cut.
