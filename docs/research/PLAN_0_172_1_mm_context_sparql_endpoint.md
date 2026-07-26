---
"@context":
  "@vocab": urn:mm:vocab/
  mm: 'urn:mm:'
  epic: 'urn:mm:epic:'
  plan: 'urn:mm:plan:'
  inEpic:
    "@id": urn:mm:vocab/inEpic
    "@type": "@id"
  concepts:
    "@id": urn:mmg:curation/mentions
    "@type": "@id"
    "@container": "@set"
"@id": urn:mm:plan:PLAN_0_172_1_mm_context_sparql_endpoint
"@type": Plan
inEpic: urn:mm:epic:epic_17_oxirs_graph_engine
concepts:
- urn:mmg:curation:concept:epic:epic_17_oxirs_graph_engine
- urn:mmg:curation:concept:term:context
- urn:mmg:curation:concept:term:slice
- urn:mmg:curation:concept:term:user
- urn:mmg:curation:concept:term:domain
- urn:mmg:curation:concept:term:graph
---

# PLAN_0_172_1 — mm-context-sparql endpoint

**Status:** open
**Opened:** 2026-06-12
**Sibling:** [PLAN_0_172_0 vv-webmcp](PLAN_0_172_0_vv_webmcp_rails_gem.md) — publisher side; this plan owns the per-user-Context query side.
**Research basis:** [docs/research/RailsWebMcp.md](../research/RailsWebMcp.md), Tier 2 findings (Manus 2026-06-12).
**Memory:** [[project_webmcp_w3c_draft_actionmcp_compose]], [[mm_usp_anonymous_persistent_sparql_for_browser_webmcp]], [[mm_promise_browser_llm_triples_sparql]].

## Why

From the **"MM invites you"** funnel, this is steps 5–7: user composes a Context from N registered domains; the substrate serves a per-Context SPARQL endpoint to the user's webpage; Lua/MM Components consume it.

Manus pinned the architecture: **browser-resident SPARQL ceiling is ~200k quads for sub-second response.** Beyond that, latency degrades; memory issues at ~35M triples. So the **v0 architecture is substrate-served per-Context endpoint with query-rewriting**, not per-user SQLite-wasm. Browser-resident remains a small-Context optimization for v1.

## What `mm-context-sparql` is

Three things:

1. **Per-Context graph projection** — a Context is a set of `(domain, weight, last_synced)` triples-source records owned by a user. The substrate maintains a per-Context derived graph by unioning the named graphs of subscribed domains.
2. **CORS-enabled SPARQL endpoint per `(user, context)`** — one stable URL the user's webpage can query. Query-rewriting injects `GRAPH <context_uri>` so the user only sees the Contexts they own.
3. **Backend graph store** — not in-process SQLite. Use Oxigraph (Rust, embeddable) or a long-running graph service. Substrate ingests triples from `vv-webmcp` domains and writes them into the right per-domain graph; the per-Context views are query-time unions.

## What it is *not*

- Not a public anonymous SPARQL endpoint (that's a separate concern for a later plan).
- Not browser-resident in v0 (small-Context browser-resident is v1).
- Not a federation hub for arbitrary RDF data — only triples from registered `vv-webmcp` domains.
- Not a write surface for the user (Contexts are user-curated source-lists, not user-authored triples).

## Slice sequence

### Slice 1 — backend graph store selection + ingestion path

- Spike Oxigraph as embedded Rust crate consumed by the substrate. (Alternatives to bench: rdf-rs, GraphDB.)
- New MCB action `triples_ingest_from_domain(domain:, triples:, verification_token:)` — verifies the domain registration ([[PLAN_0_172_0 slice 3]]) and writes triples into the per-domain named graph.
- Specs: ingestion lands the right triples in the right graph; bad verification rejected.
- **Blocker:** PLAN_0_172_0 slice 3 (`mm-cli domain register`) must land first to have verification tokens.

### Slice 2 — Context AR model + curation MCB actions

- `Mm::UserContext` AR model: `owner_pd_id`, `name`, `slug` (used in URL), `created_at`.
- `Mm::ContextSource` join: `user_context_id`, `domain`, `weight`, `last_synced_at`, `enabled`.
- MCB actions: `context_create`, `context_add_source`, `context_remove_source`, `context_list`, `context_show`.
- Specs.
- **Blocker:** none.

### Slice 3 — per-Context SPARQL endpoint (read-only, query-rewriting)

- HTTP route `GET /sparql/:user/:context_slug?query=...` (CORS-enabled, capability-token-protected).
- Query rewriting: parse the user's SPARQL query and inject `GRAPH <urn:mm:context:user-id:slug:source-domain>` for each source the Context subscribes to; UNION the results.
- Backend: Oxigraph (per slice 1).
- Specs against a fixture user + 2 fixture domains + a known query.
- **Blocker:** slices 1 + 2.

### Slice 4 — Web Component (`<mm-sparql-query>` or similar)

- Tiny JS Web Component the user drops into their webpage; auto-resolves the endpoint URL from a capability token; executes a SPARQL query; renders results in a slot.
- Specs: jest/web-test-runner against a mock endpoint.
- **Blocker:** slice 3.

### Slice 5 — Lua/MM Component integration

- DX trio integration: components in the MM canvas consume the per-Context endpoint via the same Web Component or a Lua wrapper.
- **Blocker:** slice 4 + DX trio plan ([[project_mm_dx_trio]]).

### Slice 6 — browser-resident option for small Contexts

- For Contexts under ~200k quads (Manus's ceiling), serve the full named graph as a downloadable blob; Web Component swaps to Comunica-on-IndexedDB for sub-50ms queries.
- Heuristic decision: if `total_quads < threshold`, ship the data; otherwise stay endpoint-backed.
- **Blocker:** slices 3 + 4. v1 work; do not pursue until v0 ships.

## Out of scope (defer or never)

- Federated SPARQL across multiple MM substrates (separate plan once multi-substrate is live).
- Write-side SPARQL UPDATE (Contexts are source-lists, not user-authored triples; v0 is read-only).
- Anonymous-session-no-account SPARQL (the public-anonymous USP is a separate plan).
- Multi-vocabulary translation (one MM-canonical context in v0).

## Open questions

- **Backend choice:** Oxigraph (embedded Rust) vs GraphDB (java, separate process) vs in-house SPARQL-over-SQLite (we already have `mm-hyper-source`). Spike all three in slice 1.
- **Endpoint auth:** capability-token-in-URL vs OAuth bearer vs substrate-pair-code. Capability-token-in-URL is simplest for drop-in Web Component but leaks via referer.
- **Refresh cadence:** when does a Context re-pull triples from each source? On-write push from `vv-webmcp`? Periodic pull? Both?
- **CEUR-WS paper** may inform PKG architecture and federation primitives. Read before locking slice 1.

## Acceptance for the plan

- A user with two registered domains in a Context can run a SPARQL query from their own webpage and see joined results across both domains.
- Browser-side latency under 200ms for queries returning < 1000 triples.
- The endpoint is CORS-correct against the user's webpage origin (not the platform origin).
- The capability-token URL scheme is documented and the user can revoke a token without invalidating others.

## Strategy-hint alignment

This plan is **Infrastructure** in the Alpha vocabulary — it underpins AlphaBuilder (the user composing Contexts) and AlphaSocial (groups sharing Context curation patterns). Mark as `urn:mm:strategy:Infrastructure`.
