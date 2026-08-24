---
id: PLAN_0_166_10
kind: slice
parent: PLAN_0_166_6
status: scoped
turn_class: doctrine
strategy: Product
authored_by: Claude (device-68-raven, SUPERDEV)
---

# PLAN_0_166_10 — Dynamic search-at-scale UX

> **Status:** filed; no slice briefs yet — fleet authors slice 1 brief next.
> **Parent:** [[PLAN_0_166_6]] — The MM Promise arc (plan-of-plans)
> **Doctrine:** [[mm_promise_browser_llm_triples_sparql]] +
> [[mm_usp_anonymous_persistent_sparql_for_browser_webmcp]] +
> [[platform_pov_federates_to_group_pov]] + [[project_input_mode_duality]]

## Why this arc

Threads A (browser-LLM + ephemeral SPARQL primitive, PLAN_0_166_7), B
(domain-scoped triples corpus, PLAN_0_166_8) and C (AT-Trade seed,
PLAN_0_166_9) are PLATFORM machinery. None of them are something a
user opens. **This plan is the surface.**

The operator's framing of the MM Promise ends with:

> _MM wires itself into a dynamic search experience at scale._

"Dynamic search at scale" is not a search bar. It is: a user opens a
browser tab, a domain-scoped corpus lazy-loads, a tiny in-browser LLM
answers questions grounded by SPARQL queries against that corpus, and
when the in-browser scale runs out the substrate transparently serves
the heavier query. The user does not see threads A/B/C — they see one
fast, private, queryable experience.

This plan owns the user-facing wrapping of A+B+C and the federation
hook that lets each group's POV shape what "answering a question in
this domain" actually means. PLAN_0_166_0 (AndrewT VIBE/SME arc)
becomes one instantiation of this UX; the trader-group instantiation
(PLAN_0_166_9 + this) is the smoke test that the same shape generalises.

## The arc (3 slices)

### Slice 1 — UX cut: single page; domain selector; query composer

Deliverables:

- One route in the substrate (Mm:: namespace, `mm:*` view contract)
  that renders a single-page search experience. URL shape:
  `/search?domain=<slug>` with hash routing for in-page state
  (preserves Back per [[feedback_browser_back_always_works]]).
- Three UI primitives, both as **gamified canvas** AND **traditional
  form** per [[project_input_mode_duality]]:
  - **Domain selector** — visible chooser, defaults to a domain
    inferred from query string or last-used.
  - **Query composer** — natural-language input that becomes the
    browser-LLM's instruction. Power users can flip to a SPARQL
    textarea (shows the query the LLM would have built).
  - **Answer surface** — streaming model output + a sidebar showing
    the SPARQL queries that grounded the answer + the IRIs of the
    blobs cited.
- Visual grammar reuses the Alpha component library per
  [[shared_alpha_visual_grammar]]; no new design tokens here.
- No live corpus yet — slice 1 ships against a **fixture domain**
  (`urn:mm:domain:fixture-demo`) with a hand-written triples bundle
  so the UI can be exercised in isolation while threads A and B race.
- Smoke: operator opens `/search?domain=fixture-demo`, asks a
  question, sees a streamed answer with linked SPARQL + cited blob
  IRIs.

Acceptance:

- Page loads with no flash of unstyled content and works with browser
  Back across query/domain changes.
- The same component tree renders in both gamified-canvas mode and
  traditional-form mode (a single mode toggle in the chrome).
- Answer surface clearly shows: (a) the natural-language answer, (b)
  the SPARQL queries the agent ran, (c) the cited blob IRIs. Removing
  any one of the three would degrade the UX cut — all three are
  load-bearing for trust + audit.
- The fixture-domain path is unwired from PLAN_0_166_7/_8/_9 — slice
  1 can ship on top of mocks; threads A/B/C land independently and
  swap in at slice 2.

Out of scope for slice 1: real corpus loading, real browser-LLM
inference, federation, multi-domain switching mid-session.

### Slice 2 — Lazy corpus loading + subgraph fetch + browser-LLM wiring

Deliverables:

- Replace the fixture domain with the **real** PLAN_0_166_7 primitive
  (browser-LLM + ephemeral SPARQL endpoint) and the real PLAN_0_166_8
  corpus pipeline (domain IRI → hypersource blob set).
- Corpus loading is **lazy + progressive**:
  - On domain selection, fetch the domain manifest (IRI list +
    ontology head) — small, bounded.
  - On first query, fetch only the subgraph the LLM's plan touches
    (SPARQL describes which IRIs it needs; substrate streams matching
    blobs).
  - Background-prefetch frequently-co-queried subgraphs based on a
    per-domain access pattern (the substrate already has the data
    from per-Turn observation — vv-learn surfaces it, see
    [[vv_learn_vs_vv_policy]]).
- When the in-browser SPARQL store can't satisfy a query (size cap,
  cross-domain join, freshness), fall through to the **substrate-
  side SPARQL** transparently — same query shape, different endpoint.
  User sees a small "answered with substrate help" affordance, not
  a different UI.
- The query composer's natural-language → SPARQL hop runs in the
  in-browser LLM by default; substrate-side LLM is the fallback only
  if the local engine is unavailable (per PLAN_0_166_7 slice 3's
  adapter contract).
- Smoke: operator opens the search page against the AT-Trade domain
  (PLAN_0_166_9 output), asks a question that touches one instrument,
  sees the answer ground in real corpus triples + cite real blob IRIs.

Acceptance:

- Cold-load of a new domain transfers under a configurable byte budget
  (default 1 MB manifest + initial subgraph) before first answer.
- A query that fits in the in-browser store answers without a
  substrate round-trip (verifiable: no `/sparql` request in network
  panel for that query).
- A query that overflows the in-browser store transparently falls
  through to substrate without UX regression — same answer surface,
  same cite shape, only the affordance differs.
- AT-Trade smoke: a one-sentence question about an IB-Gateway-tracked
  instrument returns an answer citing PLAN_0_166_9-seeded blobs.

Out of scope for slice 2: federation, group-owned policy, cross-
domain federation queries.

### Slice 3 — Federation hook: group POV shapes results

Deliverables:

- Each domain corpus (per PLAN_0_166_8) carries a **policy graph**
  written by the GROUP that owns the domain, per
  [[platform_pov_federates_to_group_pov]]. The policy graph is
  itself triples in hypersource; loaded with the domain manifest.
- Three federation hook points the UX must honour:
  1. **Query rewriting** — the group can attach SPARQL rewriting
     rules that the in-browser SPARQL store applies before execution
     (e.g. "a trader-group query for `?instrument` must filter by
     the group's compliance whitelist").
  2. **Answer shaping** — the group can attach instructions the
     browser-LLM concatenates into the system prompt for that domain
     (e.g. "refuse questions the group has marked out-of-policy",
     per the sycophancy-resistance lineage in
     [[platform_pov_federates_to_group_pov]]).
  3. **Result decoration** — the group can attach UI hints that the
     answer surface honours (e.g. "render `:Trade` cites with a
     P&L badge"; a per-group decorator registry mapped to the
     shared component library).
- Group identity flows through the substrate session — anonymous
  sessions see only the platform-default policy; signed-in group
  members see their group's policy stacked on top per
  [[mm_usp_anonymous_persistent_sparql_for_browser_webmcp]].
- Multiple groups can override the SAME domain — the substrate
  resolves per-session by group membership; conflicts surface as a
  group-pick chooser, not a silent merge.
- Smoke: a paid trader group (per [[andrewt_sales_call_arc]]) opens
  the AT-Trade search experience and sees a query rewrite, a
  refused-out-of-policy question, and a P&L-decorated trade cite
  that an anonymous session does NOT see for the same query.

Acceptance:

- Anonymous session on AT-Trade vs. paid-trader-group session on
  AT-Trade produce DEMONSTRABLY DIFFERENT answers + decorations for
  the same natural-language question — without the UX layer growing
  group-specific code paths.
- Federation hooks are GRAPH-driven (the group edits its policy
  triples; the UX picks up the change next session). No code deploy
  required per group, per [[name_vs_meaning_doctrine]].
- A user belonging to two groups overriding the same domain sees an
  explicit group-pick chooser, never an arbitrary merge.

Out of scope for slice 3: building the group authoring tools for the
policy graph (that is its own arc under the Alpha Social surface).

## Federation hook — where group POV lives

Federation is a slice-3 deliverable above, but the SHAPE is fixed
from slice 1 so we don't have to re-shape the component tree later:

- The answer surface ALWAYS asks the substrate session for a
  `policy_handle` (slice 1: always the platform default; slice 3:
  group-resolved).
- The query composer ALWAYS passes the `policy_handle` to the
  in-browser LLM and the in-browser SPARQL store; the LLM treats it
  as a system-prompt prefix, the SPARQL store treats it as a query-
  rewriting rule set.
- Slice 1 and 2 set the policy_handle to a no-op; slice 3 turns it on.

This matches the pattern in PLAN_0_166_5 slice 3 (research backend
federation) and PLAN_0_166_8 (per-domain policy + ownership): the
platform owns the SHAPE of the hook; the group owns the CONTENT.

## Dependencies

- **Requires (for full functionality):**
  - PLAN_0_166_7 — browser-LLM + ephemeral SPARQL primitive (slice 2
    swaps the fixture for this)
  - PLAN_0_166_8 — domain corpus pipeline (slice 2 reads from this)
  - PLAN_0_166_9 — AT-Trade seed (slice 2 smoke targets this domain)
- **Soft-requires:**
  - PLAN_0_166_3 — memory persistence (per-user query history lives
    here)
  - PLAN_0_166_5 — research delegate (a query the in-browser engine
    cannot answer can escalate to the research backend)
- **Slice 1 requires NONE** — fixture-domain path lets the UX cut
  ship in parallel with A/B/C.

## Enables

- PLAN_0_166_0 — AndrewT VIBE/SME DX path: AndrewT's conversational
  app-building experience consumes this UX as the discovery surface
  for the AT-Trade KG.
- Future domain plans (post-AT-Trade): every new domain shipped via
  PLAN_0_166_8 gets a working search-at-scale UX for free.
- Alpha Social + Builder surfaces per [[alpha_strategy_2026_06_08]]
  — both consume domain-search as a primitive; this plan ships the
  primitive.

## Out of scope (whole plan)

- Authoring tools for the per-group policy graph (its own plan).
- The corpus-discovery / domain-marketplace UX ("which domains are
  available?") — slice 1 takes a domain from the URL; the discovery
  surface is a separate B2C concern.
- Mobile-specific layout. The component library handles responsive
  behaviour; this plan does not add mobile-only paths.
- Offline mode. Lazy corpus loading is online-only in this arc; an
  offline cache is a follow-on under PLAN_0_166_3 territory.
- The browser-LLM model picker UI (PLAN_0_166_7 slice 3 owns the
  adapter; this plan consumes whatever PLAN_0_166_7 exposes).

## Related doctrine / plans / memory

- Parent: PLAN_0_166_6 — the MM Promise arc (plan-of-plans)
- Sibling: PLAN_0_166_7 — browser-LLM + ephemeral SPARQL primitive
- Sibling: PLAN_0_166_8 — WebMcp scrape → domain-scoped corpus
- Sibling: PLAN_0_166_9 — AT-Trade semantic KG (slice 2 smoke target)
- PLAN_0_166_0 — AndrewT VIBE/SME DX (the prototype consumer)
- PLAN_0_166_5 — research delegate (the escalation backend)
- Memory: [[mm_promise_browser_llm_triples_sparql]] — the doctrine
- Memory: [[mm_usp_anonymous_persistent_sparql_for_browser_webmcp]]
  — anonymous session is a first-class user of this UX
- Memory: [[platform_pov_federates_to_group_pov]] — slice 3's hook
- Memory: [[project_input_mode_duality]] — gamified + traditional
  modes are both first-class in slice 1
- Memory: [[shared_alpha_visual_grammar]] — UI reuse discipline; no
  new design tokens
- Memory: [[ui_pov_tea_nexus_component_unapologetic]] — TEA + NEXUS
  + component arch is the implementation grammar; refuse code that
  doesn't align
- Memory: [[feedback_browser_back_always_works]] — every nav must
  leave Back working; slice 1 acceptance enforces it
- Memory: [[andrewt_sales_call_arc]] — slice 3 smoke targets the
  paid-trader-group experience
- Memory: [[alpha_strategy_2026_06_08]] — both Alpha Social + Builder
  consume domain-search
- Memory: [[name_vs_meaning_doctrine]] — federation is graph-edited,
  not code-edited
- Memory: [[vv_learn_vs_vv_policy]] — slice 2's pre-fetch heuristic
  reads from vv-learn observations

## Status

- Coordinator plan PLAN_0_166_6 references this as Thread D.
- Slice 1 brief: not yet authored; SuperDev or the assigned pane
  files `docs/orchestration/briefs/plan_166_10_search_ux_slice1.md`
  next dispatch cycle.
- No code changes from this Turn; plan-authoring only per the
  parent brief.
