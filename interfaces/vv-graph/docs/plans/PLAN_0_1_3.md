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
"@id": urn:mm:plan:PLAN_0_1_3
"@type": Plan
inEpic: urn:mm:epic:epic_02_substrate_core
concepts:
- urn:mmg:curation:concept:epic:epic_02_substrate_core
- urn:mmg:curation:concept:term:step
- urn:mmg:curation:concept:term:shacl
- urn:mmg:curation:concept:term:valid
- urn:mmg:curation:concept:term:plan
- urn:mmg:curation:concept:term:sprint
---

# PLAN 0.1.3 — Validation, Build Pipeline & Integration Testing

Parent: [PLAN 0.1.2](PLAN_0_1_2.md) · [PLAN 0.1.1](PLAN_0_1_1.md) · [PLAN 0.1.0](PLAN_0_1_0.md)

This plan closes the gaps identified in 0.1.2 and validates the full
round-trip loop end-to-end.

---

## Gaps Carried Forward from 0.1.2

| Gap | Sprint |
|-----|--------|
| SHACL validation infrastructure (service, shapes, gems) | 1 |
| Client build pipeline (package.json, rollup) | 2 |
| `field-assist.js` module | 2 |
| SHACL shape file (`context-record.shacl.ttl`) | 3 |
| Server-side RDF config (`config/shacl/`, `config/rdf/`) | 1 |
| `ContextRecord` model missing `before_save :validate_shacl` hook | 1 |

---

## Sprint 1 — SHACL Validation Stack

**Goal:** Server validates every context-record payload against SHACL shapes
before persistence and broadcast.

### Step 1.1 — Gemfile Dependencies

Add missing RDF/SHACL gems:

```ruby
gem "rdf-turtle"        # Turtle format for RDF vocabularies
gem "shacl"             # SHACL validation engine
```

Run `bundle install` and verify gem resolution against Rails 8.1.

### Step 1.2 — SHACL Shape File

Create `server/config/shacl/context_record_shape.ttl` from the shape
defined in PLAN 0.1.2 Step 3.2 (copied from `shared/shapes/`).

Create `server/config/rdf/magentic_market.ttl` — the RDF vocabulary file
declaring the `mm:` namespace terms used in `magentic-market.jsonld`.

### Step 1.3 — ShaclValidator Service

Implement `server/app/services/shacl_validator.rb` per PLAN 0.1.2 Step 1.5.

### Step 1.4 — Wire Validation into ContextRecord

Add `before_save :validate_shacl` callback to `ContextRecord` model so that
invalid payloads are rejected before they reach the database or WAMP broadcast.

### Step 1.5 — Server-Side Tests

- Unit test: `ShaclValidator` returns `valid?` for a conforming payload
- Unit test: `ShaclValidator` returns errors for a payload missing `sessionId`
- Integration test: `ContextRecord.create!` with invalid payload raises
  validation error
- Integration test: `Wamp::RpcHandler.call("mm.context.create", ...)` with
  valid payload succeeds end-to-end

---

## Sprint 2 — Client Build Pipeline & Field Assist

**Goal:** The client modules can be built, bundled, and served alongside the
Rails app. The `field-assist` feature is implemented.

### Step 2.1 — Package Configuration

Create `client/package.json` per PLAN 0.1.2 Step 2.1.

Create `client/rollup.config.js`:
```javascript
import resolve from '@rollup/plugin-node-resolve'

export default {
  input: 'src/index.js',
  output: {
    file: '../server/public/js/magentic-market.js',
    format: 'es',
    sourcemap: true
  },
  plugins: [resolve()]
}
```

Output lands directly in `server/public/js/` so Rails serves it without
an asset pipeline.

### Step 2.2 — Field Assist Module

Implement `client/src/field-assist.js` per PLAN 0.1.2 Step 2.6.

Wire into `client/src/index.js` — the MutationObserver logic is already
stubbed there; connect it to the `FieldAssist` class.

### Step 2.3 — Build Verification

- `cd client && npm install && npm run build` produces
  `server/public/js/magentic-market.js`
- `npm run dev` watches and rebuilds on change
- The built bundle loads in a browser without module resolution errors

---

## Sprint 3 — End-to-End Integration

**Goal:** Validate the full round-trip described in PLAN 0.1.1's data flow
summary, from user action through to UI re-render.

### Step 3.1 — Shared Shape Deployment

Copy `shared/shapes/context-record.shacl.ttl` into
`server/config/shacl/context_record_shape.ttl` (or symlink).

Ensure the shape file is loadable by `ShaclValidator` at Rails boot.

### Step 3.2 — Session View Wiring

Update `server/app/views/sessions/show.html.erb` to:
- Load the built `magentic-market.js` bundle
- Call `boot()` with the correct `cableUrl`, `sessionId`, and DOM selectors
- Include a `<div id="mm-root">` and `<aside id="mm-sidebar">` target

### Step 3.3 — Round-Trip Smoke Test

Manual verification script (or system test):

1. Open browser to `/sessions/new`
2. Rails creates a session → context-record persisted (SHACL-valid)
3. Browser connects via ActionCable → WAMP subscribe succeeds
4. Context-record arrives in IndexedDB
5. WebLLM evaluates context → emits MCP-UI tool calls
6. Renderer paints at least one section/form/list to the DOM
7. Sidebar chat sends a message → receives a reply
8. Field assist `?` button appears on rendered form fields

### Step 3.4 — Delta Sync Verification

1. Server updates context-record via RPC (`mm.context.update`)
2. WAMP broadcasts delta to browser
3. IndexedDB updates → WebLLM re-evaluates → UI re-renders
4. Confirm only changed data traversed the wire (not full payload)

---

## Verification Checklist

Maps to open success criteria from PLAN 0.1.0 and 0.1.1:

| Criterion | Verified by |
|-----------|------------|
| Context-record schema defined in RDF, validated by SHACL | Sprint 1 — ShaclValidator + shape files |
| SHACL validation runs on server before publish | Sprint 1 — `before_save` callback |
| JSON-LD serialization round-trips cleanly | Sprint 3 — round-trip smoke test |
| MCP-UI PoC: LLM generates dynamic UI from context | Sprint 3 — Step 3.3 item 6 |
| Sidebar chat functional | Sprint 3 — Step 3.3 item 7 |
| Field-level `?` functional | Sprint 2 + Sprint 3 — Step 3.3 item 8 |
| Delta sync — only changed triples over the wire | Sprint 3 — Step 3.4 |
| Client bundle builds and loads | Sprint 2 — Step 2.3 |

---

## Out of Scope (deferred to 0.1.4+)

- Human agent handoff (PLAN 0.1.0 criterion — needs agent join RPC + shared topic)
- Browser-side SHACL validation (PLAN 0.1.1 Phase 2 — requires WASM or JS SHACL engine)
- Production deployment (Docker, CI/CD, environment configs)
- ANP (Agent Network Protocol) integration
- Cross-domain cache configuration for WebLLM model persistence
