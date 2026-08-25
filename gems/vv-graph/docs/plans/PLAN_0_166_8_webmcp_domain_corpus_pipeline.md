---
id: PLAN_0_166_8
kind: slice
parent: PLAN_0_166_6
status: scoped
turn_class: doctrine
strategy: Infrastructure
authored_by: Claude (device-68-raven, SUPERDEV)
---

# PLAN_0_166_8 — WebMcp scrape → domain-scoped triples corpus pipeline

> **Status:** filed; no slice briefs yet — fleet authors slice 1 brief next.
> **Parent:** [[PLAN_0_166_6]] — The MM Promise arc (plan-of-plans)
> **Doctrine:** [[mm_promise_browser_llm_triples_sparql]] +
> [[mm_usp_anonymous_persistent_sparql_for_browser_webmcp]] +
> [[platform_pov_federates_to_group_pov]] + [[name_vs_meaning_doctrine]]

## Why this arc

The MM Promise reduces the WebMcp problem to three lines:

> 1. Scrape WebMcp content per domain.
> 2. Store those triples in MM by domain.
> 3. Deliver search experience through web and through sqlite-sparql
>    ephemeral endpoints.

PLAN_0_166_7 owns line 3 (the queryable endpoint). PLAN_0_166_10 owns
the wrapping experience. **This plan owns lines 1 and 2 — the corpus
pipeline.** It is the only thing in the Promise arc that produces
triples; without it, the platform primitive has nothing to host and
the search UX has nothing to render.

The USP framing in
[[mm_usp_anonymous_persistent_sparql_for_browser_webmcp]] is explicit:
Google is shipping WebMCP + Nano + WebNN + WebGPU as a browser runtime,
but **PERSISTENCE** is the missing piece. The browser scrapes WebMCP
content; MM is the per-domain SEMANTIC STORE that persists it.

This plan also locks in the **graph-edited, not code-edited**
discipline. Per [[name_vs_meaning_doctrine]], domains are IRIs—
opaque, stable, and the place meaning is asserted. We do not rename
domains to express new shape; we add triples to their corpus.

## Why now

Three substrate primitives are already shipped or in flight, and the
seam between them is exactly where this plan sits:

- `vendor/mm-hyper-source/` — hypersource CAS already addresses blobs
  by IRI (per [[project_blob_cache_architecture]]).
- PLAN_0_166_2 — CI already consumes hypersource blobs by IRI rather
  than by git path; this plan extends the same IRI-not-bytes pattern
  to per-domain content.
- PLAN_0_166_5 — Manus research delegate routes through Browser IO
  against the operator's logged-in session, per
  [[manus_two_surfaces_browser_io_then_api]]. The SAME transport is
  reusable as one of three scrape transports in slice 2.
- Chrome WebMCP origin trial is live (raw URL list in
  `docs/research/ChromeEtc.md`); the substrate can read WebMCP-
  surfaced content from real Chrome sessions today.

The operator's framing of MM as a **dynamic search service at scale**
is only realisable if domain corpora exist. This plan is the engine
that turns the web into those corpora.

## The arc (3 slices)

### Slice 1 — Domain IRI scheme + corpus model

Deliverables:

- A domain IRI scheme: `urn:mm:domain:<slug>` (matching the example
  PLAN_0_166_6 uses for AT-Trade: `urn:mm:domain:financial-trading`).
  Slugs are kebab-case, stable, and OPAQUE — per
  [[name_vs_meaning_doctrine]], the slug does not express meaning;
  the corpus does.
- A domain manifest schema (RDF, hypersource-stored) recording, per
  domain:
  - `urn:mm:domain:<slug>` — the canonical IRI.
  - Owning group IRI (or `urn:mm:platform` for unowned platform
    domains) per [[platform_pov_federates_to_group_pov]].
  - Ontology head: the IRI of the domain's ontology blob (small,
    bounded — the manifest fetcher reads this first).
  - Corpus shard set: IRIs of the triples blobs the manifest binds.
  - Policy graph IRI (slice 3's hook; declared but no-op in slice 1).
  - Provenance: scrape source IRIs, last-scraped timestamps, scraper
    identity.
- A pair of MCB actions:
  - `domain_manifest_get(domain_iri) → manifest` (cheap, cached).
  - `domain_corpus_list(domain_iri) → [blob_iri, ...]` (the shard IRIs
    a SPARQL endpoint loads).
- An RDF-based corpus registry stored AS triples in hypersource, NOT
  as a sidecar database — the registry is itself queryable through
  PLAN_0_166_7's SPARQL primitive.
- Smoke: a fixture domain (`urn:mm:domain:fixture-demo`) gets a
  hand-authored manifest + a single triples shard; `domain_manifest_get`
  + `domain_corpus_list` return the expected IRI set; the result can
  be loaded into PLAN_0_166_7 slice 1's in-page store.

Acceptance:

- Two distinct fixture domains coexist with disjoint corpora — a query
  scoped to one domain cannot "leak" triples from the other through
  the manifest API.
- The same fixture domain re-registered through the manifest API
  produces the SAME blob IRIs (content-addressed; idempotent), per
  [[project_blob_cache_architecture]].
- A domain with no policy graph yet still works (the policy slot is
  declared null, not absent) — slice 3 will fill it without re-shaping
  the manifest.
- The fixture-demo manifest is loadable by PLAN_0_166_10 slice 1's
  fixture path without any other slice of this plan landing first.

Out of scope for slice 1: any scrape; cross-domain joins; manifest
authoring UI (groups will get an authoring surface; that is an Alpha
Social arc).

### Slice 2 — Scrape transport (three adapters: Browser IO, headless Chrome, substrate workers)

Deliverables:

- One MCB action `domain_scrape_enqueue(domain_iri, source_iri,
  transport_hint?)` that takes a domain + source URL and enqueues a
  scrape job. The job's result lands as new shard blobs added to the
  domain manifest.
- Three transport adapters BEHIND the same `domain_scrape_enqueue`
  surface (so callers do not pick the transport unless they want to):
  1. **Manus Browser IO** — reuses the operator's logged-in browser
     session per PLAN_0_166_5 slice 1 + [[manus_two_surfaces_browser_io_then_api]].
     Right transport for sites the operator is already authenticated
     into (research portals, paid sources). Cost lands on operator's
     subscription, not MM's bill.
  2. **Headless Chrome** — substrate-side Chrome (CDP-driven, per the
     existing browser-harness pattern). Right transport for public
     pages with no auth requirement.
  3. **Substrate workers** — direct HTTP for static / sitemap-driven
     sources. Right transport for bulk, unauthenticated, well-formed
     content.
- A scrape → triples translator. WebMCP surfaces structured content;
  the translator emits N-Triples per the domain's ontology head. The
  translator is **per-domain**: each domain registers its own
  scrape→triples mapping (a small DSL or, initially, a Ruby strategy
  class per domain).
- Idempotency: re-scraping a URL whose source hash is unchanged is a
  no-op (the hypersource CAS already dedupes; the scraper additionally
  skips the LLM-extraction step when input bytes match).
- Per-scrape provenance: every emitted triple carries (or is grouped
  under) a quad whose graph IRI names the (source IRI, scrape
  timestamp, transport) tuple — so federation policy in slice 3 can
  filter by source.
- Smoke: a public-page source URL is enqueued against the fixture
  domain via the headless-Chrome transport; new shard IRIs appear in
  the manifest; PLAN_0_166_7's SPARQL primitive can query the new
  content immediately.

Acceptance:

- Each of the three transports successfully scrapes a representative
  source: a paid-source authenticated page (Manus Browser IO), a
  public site (headless Chrome), and a sitemap of static pages
  (substrate workers). All three produce shards that load into the
  same domain.
- Re-running the same scrape produces a no-op (zero new blob IRIs,
  zero LLM calls) when the source hash is unchanged.
- The Manus Browser IO path surfaces a structured
  `please re-login` event on session expiry per PLAN_0_166_5 slice 1
  — it does not silently fail.
- A scrape that fails in any of the three transports returns a
  `{ ok: false, reason, because }` envelope with the failed source
  IRI — substrate-side never-raise applies to the scrape boundary the
  same as elsewhere.

Out of scope for slice 2: change-detection beyond input-byte hashing
(stale-source detection / freshness invalidation is a follow-on);
multi-page "crawl" behaviour (slice 2 takes one source IRI per call;
the brief author orchestrates breadth); WebMCP-output → ontology
auto-mapping (slice 2 requires a per-domain translator; auto-mapping
is a future ML concern that vv-learn can inform).

### Slice 3 — Per-domain federation policy hook

Deliverables:

- Every domain manifest's `policy_graph_iri` slot (slice 1 declared,
  slice 3 wires) names a hypersource blob containing the domain's
  **policy triples** — written by the OWNING GROUP per
  [[platform_pov_federates_to_group_pov]].
- Three federation hook points the corpus pipeline must honour:
  1. **Scrape policy** — the group can attach allow/deny rules over
     source IRIs; `domain_scrape_enqueue` refuses scrapes its
     domain's policy disallows.
  2. **Translator override** — the group can pin a specific
     scrape→triples translator IRI (a different strategy class or
     ontology), so two groups owning shadow corpora of the same source
     URLs can extract DIFFERENT triples without code forks.
  3. **Visibility policy** — the group can mark shards as
     `public` / `group-only` / `member-only`. The corpus list returned
     by `domain_corpus_list` is filtered by the requesting session's
     group membership.
- Multiple groups can shadow-own the SAME `urn:mm:domain:<slug>` —
  the substrate resolves the policy graph per requesting session
  identity; conflicts surface as a group-pick chooser (same shape as
  PLAN_0_166_10 slice 3's chooser), never an arbitrary merge.
- Anonymous sessions see only the **platform-default** policy per
  [[mm_usp_anonymous_persistent_sparql_for_browser_webmcp]] (the
  USP is anonymous-but-persistent; persistence does not require
  identity).
- Smoke: a paid-trader group attaches a visibility policy marking
  certain trade-detail shards as `member-only`. An anonymous session
  on the AT-Trade domain receives only public shards from
  `domain_corpus_list`; a group-member session receives the full set.

Acceptance:

- Policy is **graph-driven**, not code-driven: a group edits its
  policy triples; the next scrape / query picks up the change with
  no code deploy. Matches the
  [[platform_pov_federates_to_group_pov]] doctrine end-to-end.
- Two groups shadow-owning the same source URLs with different
  translators produce demonstrably different triples for the same
  scrape — enforced by per-group policy graph, not by per-group
  hard-coded paths.
- A session belonging to two groups whose policies conflict on the
  same domain sees an explicit group-pick chooser, never a silent
  merge.
- The policy graph format is documented enough that an Alpha Social
  authoring tool (separate plan) can edit it; this slice does NOT
  ship that authoring tool.

Out of scope for slice 3: the group-side policy authoring UI; multi-
platform federation (cross-substrate corpus exchange); legal /
rights-management triples (a related but separate concern under the
[[project_l_as_audit_primitive]] arc).

## Federation hook — where group POV lives

Federation in this plan lives at THREE layers, all consolidated under
slice 3's `policy_graph_iri`:

- **Manifest layer** — visibility policy filters which shards a
  caller sees.
- **Scrape layer** — scrape policy controls which sources can flow
  into the corpus, and which translator processes them.
- **Identity layer** — group membership resolves WHICH policy graph
  applies per session; anonymous sessions default to platform policy.

The SHAPE is platform-owned (this plan); the CONTENT is group-owned.
The policy graph is itself a triples blob in hypersource — a corpus
editing itself, the same primitive on both sides of the boundary.

This pairs with PLAN_0_166_7's `policy_handle` (the runtime parameter
the SPARQL store and browser-LLM both read). Federation thus has
exactly two surfaces in the Promise arc: **policy graphs** (authored,
persistent, here) and **policy handles** (resolved per request,
there). PLAN_0_166_10 slice 3 ties them together.

## Dependencies

- **Requires (already shipped):**
  - `vendor/mm-hyper-source/` — blob CAS (per
    [[project_blob_cache_architecture]]).
  - PLAN_0_166_2 — CI consumes blobs by IRI (same IRI-not-bytes
    pattern; this plan reuses the hypersource client surfaces).
- **Requires (in flight):**
  - PLAN_0_166_6 — the Promise arc coordinator (this plan's parent).
  - PLAN_0_166_5 — Manus Browser IO transport (slice 2's first
    transport adapter reuses PLAN_0_166_5's harness).
- **Soft-requires:**
  - PLAN_0_166_3 — memory persistence (corpora are a kind of memory;
    the registry storage policy aligns).
  - PLAN_0_166_7 — the SPARQL primitive eventually queries the
    corpora this pipeline writes (no hard dep; this plan can ship
    against the in-page WASM store of PLAN_0_166_7 slice 1).

## Enables

- PLAN_0_166_9 — AT-Trade semantic KG is the first concrete domain
  through this pipeline; the slice-2 transports import
  `other/ibkr_api` + `other/multicharts-api` content into
  `urn:mm:domain:financial-trading`.
- PLAN_0_166_10 — the search-at-scale UX reads `domain_manifest_get`
  on every domain-selector change; slice 2 of PLAN_0_166_10 replaces
  its fixture manifest with the output of slice 1 here.
- All future domain plans — every new `urn:mm:domain:<slug>` flows
  through this pipeline. The marginal cost of adding a domain is the
  ontology head + one translator + a scrape source list.
- Alpha Splash / Builder / Social per [[alpha_strategy_2026_06_08]]
  — all three Alpha surfaces consume per-domain corpora; this plan
  is the only producer.

## Out of scope (whole plan)

- Group-side policy authoring UI. Groups will need a way to write
  their policy graph; that lives in a separate Alpha Social arc.
- Freshness / change-detection beyond input-byte hashing. A scraped
  page that changes between scrapes will be re-scraped; smarter
  scheduling (TTL by source type, ETag honour, push notifications) is
  a follow-on.
- WebMCP-output → ontology auto-mapping. Each domain registers its
  own translator; automatic ontology induction is future research,
  not slice scope here.
- Cross-substrate corpus federation (one MM exchanging corpora with
  another MM). The substrate-internal federation hook above ships;
  inter-substrate is its own threat model.
- Legal / rights-management metadata. Domains that need it can model
  it in their ontology; the platform does not impose a rights schema
  here.

## Related doctrine / plans / memory

- Parent: PLAN_0_166_6 — the MM Promise arc (plan-of-plans)
- Sibling: PLAN_0_166_7 — browser-LLM + ephemeral SPARQL primitive
  (consumes the corpora this plan produces)
- Sibling: PLAN_0_166_9 — AT-Trade semantic KG (first concrete
  domain through this pipeline)
- Sibling: PLAN_0_166_10 — Dynamic search-at-scale UX (reads
  manifests this plan writes)
- PLAN_0_166_2 — CI submodules via blob IRI (same IRI-not-bytes
  pattern)
- PLAN_0_166_5 — Manus research delegate (slice 2 reuses the
  Browser IO transport)
- PLAN_0_166_3 — memory persistence (the registry lives in the
  substrate semantic store)
- Memory: [[mm_promise_browser_llm_triples_sparql]] — the doctrine
- Memory: [[mm_usp_anonymous_persistent_sparql_for_browser_webmcp]]
  — the USP this pipeline realises
- Memory: [[platform_pov_federates_to_group_pov]] — slice 3's hook
- Memory: [[name_vs_meaning_doctrine]] — domain IRIs are opaque;
  meaning is asserted in the corpus
- Memory: [[project_blob_cache_architecture]] — hypersource is the
  substrate
- Memory: [[manus_two_surfaces_browser_io_then_api]] — slice 2's
  Browser IO transport
- Memory: [[project_brief_iri_cas_always]] — sources, shards, and
  policy graphs are all referenced by IRI
- Memory: [[alpha_strategy_2026_06_08]] — all three Alpha surfaces
  consume per-domain corpora
- Memory: [[project_l_as_audit_primitive]] — the scrape provenance
  triples this plan writes are auditable inputs to L

## Status

- Coordinator plan PLAN_0_166_6 references this as Thread B.
- Slice 1 brief: not yet authored; fleet or SuperDev files
  `docs/orchestration/briefs/plan_166_8_domain_iri_slice1.md` at the
  next dispatch cycle.
- No code changes from this Turn; plan-authoring only per the parent
  brief.
