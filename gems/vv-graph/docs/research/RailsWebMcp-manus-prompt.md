# Manus research prompt — Rails + WebMCP + JSON-LD + per-context SPARQL

*Drop the section below into Manus. Operator pastes; output returns as `docs/research/RailsWebMcp.md` (operator-named).*

---

## Context: what I am building, what I need you to find out

I am designing a Ruby gem named **`vv-webmcp`** for Rails apps. The goal of the gem is to give a Rails developer a one-line way to make their site participate in a graph federation: their app exposes its data as RDF triples over a Model Context Protocol (MCP) style endpoint, an upstream platform aggregates triples from many such domains into per-user *Contexts*, and the user's browser eventually gets a per-Context SPARQL endpoint they can query from their own webpage. There is also a component layer (Lua + custom components) that will consume the SPARQL endpoint to render interactive UI.

The seven-step end-to-end shape I am working toward:

1. Rails dev adds `gem "vv-webmcp"` to their Gemfile.
2. They deploy their Rails app to their own domain.
3. They register their domain with the upstream platform (one CLI command).
4. Their domain exposes triples through an MCP-style endpoint, serialized as JSON-LD.
5. End users opt-in to integrate triples from one or more registered domains into a named *Context*. A user has N contexts.
6. The platform serves each user's webpage a SPARQL endpoint scoped to one Context (one URL per Context).
7. Lua / custom components consume the SPARQL endpoint to render interactive UI in the user's webpage.

I want your research to surface what already exists in this space — standards, prior art, active Rails gems, browser-side SPARQL state-of-the-art — so I can build on the right pieces and not reinvent. I am especially interested in *what conventions a Rails developer already expects* so the gem's surface feels native rather than novel.

## Questions, in priority order

### Tier 1 — standards / state of the field

1. **WebMCP / Model Context Protocol — what is the actual current spec landscape?**
   - Is there a draft WebMCP spec from Google or anyone else as of mid-2026?
   - What's the wire format? HTTP? JSON-RPC? streaming?
   - How is a site supposed to declare "I serve MCP" — well-known URL, link header, manifest, something else?
   - Are there reference implementations in any language I can study?
   - Is there a registry / federation model already defined, or is it BYO?

2. **JSON-LD in Rails — the actual idiomatic 2026 path.**
   - What gems are currently used to emit JSON-LD from a Rails app? (rdf-rails, json-ld, schema-rb, hanami-something, etc.) For each: maintained? last release? real adoption signal?
   - Is there a convention for "derive JSON-LD from ActiveRecord schema with zero config"? Any gem already doing this well?
   - What about JSON-LD framing / context distribution — how are Rails sites supposed to publish their `@context`?
   - Any Rails gem that bridges ActiveRecord → RDF triples (e.g., something old like ActiveRDF — is it dead or has a successor emerged)?

3. **Domain-to-aggregator registration — prior art for the federation handshake.**
   - WebFinger, IndieAuth, ActivityPub instance registration, OpenID Connect discovery — what's the closest conceptual ancestor for "site declares itself to a federation hub"?
   - Mastodon / Fediverse model of "my domain joins this network" — what does the handshake actually look like protocol-wise?
   - Solid (Tim Berners-Lee's project) — what's the current state? Anything relevant to "site publishes triples + users compose them"?
   - Are there any active "linked-data fediverse" projects we should know about?

### Tier 2 — browser-side SPARQL + per-context endpoints

4. **Per-context SPARQL endpoint at browser scope — what's possible today?**
   - State of sqlite-wasm + SPARQL in the browser as of 2026 (Comunica, SPARQL.js, rdf-ext, oxigraph-wasm).
   - Any precedent for "the platform serves a unique SPARQL URL per (user, context)" — multi-tenant SPARQL endpoint architectures?
   - Performance shape: how much data fits in a browser-resident SPARQL store before it gets unusable?
   - Are there libraries/products that already do "give me a SPARQL endpoint scoped to a user's chosen sources"?

5. **Browser → multiple domains → unified Context, on a normal webpage.**
   - CORS implications of querying a SPARQL endpoint from an arbitrary user webpage.
   - Is there a clean way for a user to drop a `<script>` or `<vv-component>` tag into their webpage that talks to their personal SPARQL endpoint?
   - Anything from Google's WebMCP work that pre-solves this?

### Tier 3 — Rails community + adoption

6. **Rails dev psychology 2026 — what makes a gem land?**
   - What's the Rails community's current stance on AI / semantic-web / linked-data work? Apathetic? Hostile? Curious?
   - Recent gems that made it from "interesting" to "installed by default" — what did their READMEs and onboarding ladders look like?
   - Rails 8 / 8.1 features I should compose with (Solid Queue, Solid Cable, ActionMCP if that exists, Rails ActiveContext if that exists, etc.).
   - DHH and the core team's recent statements on AI integration in Rails — anything that shapes how I'd position the gem?

7. **Naming + positioning.**
   - Is `vv-webmcp` an OK gem name on RubyGems? Any name collision? Any naming pattern Rails devs prefer for declarative-publishing gems (recall: `acts_as_taggable`, `has_secure_password`)?
   - One-line README hook — what's the strongest analogy? "Like ActivityPub but for structured data"? "Schema.org for federated apps"? Find me prior art for how comparable gems pitched themselves.

### Tier 4 — sanity-check the architecture

8. **Anything I'm about to reinvent?**
   - Has someone already shipped the *whole* seven-step ladder above (Rails gem → federation → per-user context → browser SPARQL)? Either successfully or as a stalled-project case study — both useful.
   - What killed prior attempts at "linked data for normal web devs"? Specific failures to learn from.

## Format I want back

- **One tier-by-tier markdown document.**
- For every named gem / standard / project: give me **name + current maintenance signal (last commit / last release / GitHub stars / RubyGems downloads) + a one-paragraph what-it-is + a one-paragraph fit-for-my-purpose verdict.**
- For dead/abandoned things: say so explicitly, so I don't waste a day chasing them.
- For things you can't determine, write "unverified — worth a 15-minute spike" rather than guessing.
- Final section: a **"if I were you, I'd compose X + Y + Z and avoid A + B"** recommendation — your synthesis, not just a literature list.

Research depth target: ~2 hours of focused web search. Optimize for *recent* sources (2025–2026); the Rails ecosystem and WebMCP standards both moved a lot in the last 18 months and I want current signal, not archived blog posts from 2018.
