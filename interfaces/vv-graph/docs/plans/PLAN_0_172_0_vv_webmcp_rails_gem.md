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
"@id": urn:mm:plan:PLAN_0_172_0_vv_webmcp_rails_gem
"@type": Plan
inEpic: urn:mm:epic:epic_11_vibe_demand_flow
concepts:
- urn:mmg:curation:concept:epic:epic_11_vibe_demand_flow
- urn:mmg:curation:concept:term:rail
- urn:mmg:curation:concept:term:slice
- urn:mmg:curation:concept:term:app
- urn:mmg:curation:concept:term:vv-webmcp
- urn:mmg:curation:concept:term:actionmcp
---

# PLAN_0_172_0 — vv-webmcp Rails gem

**Status:** open
**Opened:** 2026-06-12
**Parent arc:** [PLAN_0_166_6 MM Promise](PLAN_0_166_6_mm_promise_arc.md), [PLAN_0_168_1 Google/WebMCP tracker](PLAN_0_168_1_google_webmcp_tracker.md)
**Sibling:** [PLAN_0_172_1](PLAN_0_172_1_mm_context_sparql_endpoint.md) — the substrate-served per-Context SPARQL endpoint this gem feeds.
**Research basis:** [docs/research/RailsWebMcp.md](../research/RailsWebMcp.md) (Manus 2026-06-12).
**Memory:** [[project_webmcp_w3c_draft_actionmcp_compose]], [[mm_invites_you_summary_of_charter]], [[mm_usp_anonymous_persistent_sparql_for_browser_webmcp]].

## Why

Manus confirmed: **WebMCP is a real W3C Draft Community Group Report (Feb 2026); `actionmcp` is the Rails-native MCP transport (54k+ downloads); `json-ld` + `rdf` are mature serializers; what is *missing* is a zero-config ActiveRecord-to-JSON-LD + federation-handshake layer.** That gap is exactly `vv-webmcp`.

The gem is the Rails-dev entry point to the **"MM invites you"** funnel: one `gem` line + one macro + one `mm-cli domain register` and a Rails app is federated. No Semantic Web vocabulary in the dev's face.

## What `vv-webmcp` is *not*

- Not an MCP transport — depend on `actionmcp`.
- Not a JSON-LD serializer — depend on `json-ld` + `rdf`.
- Not a SPARQL endpoint — sibling plan [PLAN_0_172_1](PLAN_0_172_1_mm_context_sparql_endpoint.md) owns that.
- Not a Redis-using gem — Solid Trifecta stance (DHH 2026).
- Not an RDF-vocabulary-exposing gem at the developer surface.

## What `vv-webmcp` *is*

Four things, in priority:

1. **`acts_as_webmcp_resource expose: [...]` macro** on `ActiveRecord::Base` — auto-derives a JSON-LD shape from the declared columns + their AR associations.
2. **`/.well-known/webmcp` manifest** auto-served by a Rails engine route, declaring tools + auth + capabilities per the W3C draft.
3. **`mm-cli domain register` flow** — a WebFinger-inspired + IndieAuth-style OAuth2 handshake to register the Rails app's domain with the MM substrate.
4. **Federation-publish hook** — when an `acts_as_webmcp_resource` record changes, publish triples to the substrate (over `actionmcp`'s wire) so they land in users' Contexts.

## Slice sequence

### Slice 1 — skeleton + macro shape (no transport yet)

- New gem in `vendor/vv-webmcp/` (Rust workspace pattern not relevant; pure Ruby).
- `Vv::WebMcp::Resource` module with `acts_as_webmcp_resource expose: [...]` macro.
- Generates a `to_jsonld` instance method per included model.
- Specs against a fixture `Article` model + assert JSON-LD shape against `json-ld` v3.3.2.
- **Does not** touch `actionmcp` yet; **does not** mount manifest route yet.
- **Blocker:** none. Independent slice.

### Slice 2 — `.well-known/webmcp` manifest endpoint (actionmcp deep-dive required first)

- Read `actionmcp` source (Manus follow-up queued; see below).
- Mount Rails engine route `/.well-known/webmcp` returning JSON manifest.
- Declare each `acts_as_webmcp_resource` model as an available tool per W3C draft.
- Specs: manifest validates against W3C JSON schema (if published).
- **Blocker:** Manus deep-dive on `actionmcp` API surface (so we know whether to register tools through it or alongside it).

### Slice 3 — `mm-cli domain register` handshake

- Substrate side: new MCB action `domain_register` that records `(domain, owner_pd_id, verification_token, registered_at)`.
- Client side: `mm-cli domain register <url>` walks the OAuth2/IndieAuth dance, ends with a verification token the Rails app proves by serving it under `/.well-known/webmcp/verify/:token`.
- Specs against a test Rails app fixture.
- **Blocker:** none (parallel to slice 2).

### Slice 4 — federation-publish hook

- AR callback hook on `acts_as_webmcp_resource` models: on commit, enqueue (Solid Queue) a publish job that pushes triples to the registered MM substrate URL.
- Substrate side: new MCB action `triples_ingest_from_domain` that accepts triples from a verified domain and lands them in the right per-domain graph.
- **Blocker:** slices 1 + 3 must land first.

### Slice 5 — dev-experience polish

- README pitched as **"Make your Rails app an active participant in the Agentic Web in one line"**, not as Semantic Web infrastructure.
- Worked example using `Article` model.
- `vv-webmcp` install generator (Railtie).
- **Blocker:** slices 1–4 must land.

## Out of scope (defer)

- Per-Context SPARQL endpoint (sibling plan).
- Browser-side Comunica integration (later DX trio work).
- Lua/MM Components consuming the endpoint (separate plan once endpoint is live).
- `acts_as_webmcp_action` for write-side tools (slice 6+).
- Multi-vocabulary support (Schema.org / FOAF / custom contexts) — v1 ships with one MM-canonical context.

## Open questions

- **Gem name:** `vv-webmcp` is acceptable but esoteric per Manus + namespace-locust risk. Decide on lock-in before publishing. Candidates: `vv-webmcp`, `acts_as_webmcp` (macro-shape), `webmcp_rails_mm` (anti-collision).
- **Macro name:** `acts_as_webmcp_resource` vs `has_webmcp_context` vs something shorter. Rails convention pulls toward `acts_as_*`.
- **Manifest auth model:** OAuth2 vs IndieAuth vs a substrate-native pair-code-style flow. WebFinger gives discovery; auth is separate.
- **CEUR-WS Sovereign Agentic Web paper** — may inform identity model + how MCP-as-mediation-layer composes with Solid Pods. Read before locking slice 3.

## Manus follow-up queued

1. **`actionmcp` API surface deep-dive** — what does Tool registration look like? Request/response flow? Where is it weak? What's the integration shape for adding custom tools?
2. **Spadea et al. 2026 (CEUR-WS Vol-4210 paper 3)** — read the Sovereign Agentic Web architecture using Solid + MCP + PKGs + SPARQL. Identify what overlaps with MM and what diverges.

## Acceptance for the arc (when this plan can close)

- A Rails dev can: `bundle add vv-webmcp`, `acts_as_webmcp_resource expose: [...]` in one model, `mm-cli domain register https://their-app.com`, and that app's records are queryable from any user's MM Context.
- One demo Rails app at AndrewT-scale ([[project_andrewt_sales_call_arc]]) is federated as a worked example.
- End-to-end test in CI: spin up a fixture Rails app + a substrate + a user webpage; the page's SPARQL endpoint returns the fixture app's records.
