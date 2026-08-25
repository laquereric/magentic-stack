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
"@id": urn:mm:plan:PLAN_0_8_1
"@type": Plan
inEpic: urn:mm:epic:epic_63_pseudo_code_engine
concepts:
- urn:mmg:curation:concept:epic:epic_63_pseudo_code_engine
- urn:mmg:curation:concept:term:pack
- urn:mmg:curation:concept:term:app
- urn:mmg:curation:concept:term:platform
- urn:mmg:curation:concept:term:oper
- urn:mmg:curation:concept:term:model
---

# PLAN 0.8.1 — Modular Monolith with Packwerk

## What Changed

Shopify's research (docs/research/Shopify.md) shows that the right approach for separating platform and application is not Rails engines or separate repos — it's a **modular monolith** using **Packwerk** for static boundary enforcement. Shopify runs one of the largest Rails codebases in the world this way: domain-oriented "packs" with enforced dependency and privacy boundaries, no gem extraction needed.

The PLATFORM research (docs/research/PLATFORM.md) confirms that the platform layer — runtime, context, governance, sessions, AI orchestration — is the high-value layer in the AI stack. The marketplace is one application surface. The platform is the thing worth owning.

PLAN 0.8.0 recommended "Start with B (Namespace), prepare for A (Engine)." Shopify's Packwerk is B done right — with static analysis instead of spec-based string matching.

## Approach: Packwerk Packs

Packwerk organizes code into **packs** — directories with a `package.yml` that declares dependencies and privacy boundaries. The `packwerk check` command statically analyzes the codebase and reports violations. No runtime overhead, no gem extraction, no namespace prefixing required.

### Pack Structure

```
server/
├── packs/
│   ├── platform/
│   │   ├── package.yml           # enforce_dependencies: true, enforce_privacy: true
│   │   ├── app/
│   │   │   ├── models/
│   │   │   │   ├── user.rb
│   │   │   │   ├── passkey.rb
│   │   │   │   ├── context.rb
│   │   │   │   ├── session_participant.rb
│   │   │   │   ├── session_channel.rb
│   │   │   │   ├── api_key.rb
│   │   │   │   ├── webhook.rb
│   │   │   │   ├── usage_meter.rb
│   │   │   │   ├── actor.rb
│   │   │   │   └── intention.rb
│   │   │   ├── public/           # Packwerk public API — what app packs can use
│   │   │   │   ├── context.rb    # Re-export: public interface to Context model
│   │   │   │   ├── user.rb
│   │   │   │   ├── session_participant.rb
│   │   │   │   └── global_route.rb
│   │   │   ├── operations/
│   │   │   │   ├── auth/         # Challenge, Register, Login, Logout
│   │   │   │   ├── context/      # Create, Read, Update, Delete, List, Clear, UpdateLayer
│   │   │   │   ├── session/      # Join, Leave, Kick, Participants, SetRole, EnableAi
│   │   │   │   ├── channel/      # StartVoice, StartScreen, StartVideo, Stop, Signal
│   │   │   │   ├── others/       # Message, Share, Presence, SetRole, Invite, History
│   │   │   │   ├── nav/          # Go
│   │   │   │   └── action/       # Route
│   │   │   ├── services/
│   │   │   │   ├── action_router.rb
│   │   │   │   ├── agent_router.rb
│   │   │   │   ├── llm_service.rb
│   │   │   │   ├── shacl_validator.rb
│   │   │   │   └── webhook_dispatcher.rb
│   │   │   ├── channels/
│   │   │   │   └── wamp_channel.rb
│   │   │   ├── middleware/
│   │   │   │   └── rate_limiter.rb
│   │   │   ├── controllers/
│   │   │   │   ├── api/v1/       # BaseController, ContextsController, WebhooksController, UsageController
│   │   │   │   └── sessions_controller.rb
│   │   │   └── concerns/
│   │   │       ├── wamp_dispatchable.rb
│   │   │       ├── global_route_dispatchable.rb
│   │   │       └── tenant_scoped.rb
│   │   ├── config/
│   │   │   └── initializers/
│   │   │       ├── global_route.rb
│   │   │       ├── wamp_routing.rb
│   │   │       └── webauthn.rb
│   │   └── javascript/
│   │       ├── lib/
│   │       │   ├── wamp_client.js
│   │       │   └── webrtc_manager.js
│   │       └── controllers/
│   │           ├── modal_controller.js
│   │           ├── panel_controller.js
│   │           ├── toggle_controller.js
│   │           ├── role_controller.js
│   │           ├── voice_channel_controller.js
│   │           ├── screen_channel_controller.js
│   │           └── video_channel_controller.js
│   │
│   └── marketplace/
│       ├── package.yml           # dependencies: [platform]
│       ├── app/
│       │   ├── models/
│       │   │   ├── scenario.rb
│       │   │   ├── slide.rb
│       │   │   ├── slide_region.rb
│       │   │   ├── component_record.rb
│       │   │   ├── component_variant.rb
│       │   │   ├── variant_element.rb
│       │   │   ├── element_state.rb
│       │   │   ├── design.rb
│       │   │   ├── design_concern.rb
│       │   │   ├── design_eval.rb
│       │   │   ├── turn.rb
│       │   │   ├── turn_eval.rb
│       │   │   ├── use_case.rb
│       │   │   └── todo.rb
│       │   ├── operations/
│       │   │   ├── ai/           # Chat, FieldAssist, Modal
│       │   │   ├── scenario/     # Diff, Export, Revert
│       │   │   ├── slide/        # List, Read, Block
│       │   │   ├── region/       # Save, Insert, SetState, Schema, Revert
│       │   │   ├── modal/        # Ai, Others, Login, EditScenario, EditRegions
│       │   │   └── style/        # Save
│       │   ├── controllers/
│       │   │   ├── scenarios_controller.rb
│       │   │   ├── slides_controller.rb
│       │   │   ├── slide_regions_controller.rb
│       │   │   ├── turns_controller.rb
│       │   │   ├── todos_controller.rb
│       │   │   ├── ai_controller.rb
│       │   │   ├── ai_modal_controller.rb
│       │   │   ├── others_modal_controller.rb
│       │   │   ├── login_modal_controller.rb
│       │   │   ├── marketplace_controller.rb
│       │   │   └── home_controller.rb
│       │   └── view/components/  # All 32 marketplace components
│       └── javascript/
│           └── controllers/
│               ├── editor_controller.js
│               ├── chat_controller.js
│               ├── context_controller.js
│               ├── context_crud_controller.js
│               ├── slide_events_controller.js
│               ├── component_cst_controller.js
│               ├── component_sst_controller.js
│               └── accordion_controller.js
│
├── app/                          # Root app — shared config, ApplicationController, layouts
│   ├── controllers/
│   │   └── application_controller.rb
│   ├── views/layouts/
│   └── javascript/
│       ├── application.js
│       └── channels/
├── config/
│   ├── routes.rb                 # Draws from both packs
│   ├── importmap.rb
│   └── initializers/
├── db/migrate/                   # Single migration directory
├── package.yml                   # Root package (dependencies: [])
└── packwerk.yml                  # Packwerk configuration
```

### Package Declarations

**Root `package.yml`:**
```yaml
enforce_dependencies: true
enforce_privacy: true
```

**`packs/platform/package.yml`:**
```yaml
enforce_dependencies: true
enforce_privacy: true
dependencies: []
```

Platform depends on nothing. It is the foundation.

**`packs/marketplace/package.yml`:**
```yaml
enforce_dependencies: true
enforce_privacy: true
dependencies:
  - packs/platform
```

Marketplace depends on platform. Platform does NOT depend on marketplace.

### What Packwerk Enforces

```
✅ Marketplace can use: Context, User, SessionParticipant, GlobalRoute, ActionRouter
   (anything in packs/platform/app/public/)

❌ Platform cannot reference: Scenario, Slide, ComponentRecord, Design, Turn, UseCase
   (packwerk check catches this at CI time)

❌ Marketplace cannot reach into platform internals:
   (e.g., directly calling WebhookDispatcher — must go through public API)
```

**Example violation:**
```
packs/platform/app/operations/context/create.rb:15
  references Scenario (from packs/marketplace)
  → Dependency violation: packs/platform cannot depend on packs/marketplace
```

### packwerk.yml

```yaml
# packwerk.yml
include:
  - "**/*.rb"
exclude:
  - "**/spec/**"
  - "**/test/**"
```

## Implementation

### Step 1: Add Packwerk gem

```ruby
# Gemfile
group :development, :test do
  gem "packwerk"
end
```

### Step 2: Create pack directories

```bash
mkdir -p packs/platform/app/{models,operations,services,channels,middleware,controllers,concerns}
mkdir -p packs/platform/app/public
mkdir -p packs/platform/config/initializers
mkdir -p packs/platform/javascript/{lib,controllers}
mkdir -p packs/marketplace/app/{models,operations,controllers}
mkdir -p packs/marketplace/app/view/components
mkdir -p packs/marketplace/javascript/controllers
```

### Step 3: Move files

**Platform models** (10 files):
```bash
mv app/models/user.rb              packs/platform/app/models/
mv app/models/passkey.rb           packs/platform/app/models/
mv app/models/context.rb           packs/platform/app/models/
mv app/models/session_participant.rb packs/platform/app/models/
mv app/models/session_channel.rb   packs/platform/app/models/
mv app/models/api_key.rb           packs/platform/app/models/
mv app/models/webhook.rb           packs/platform/app/models/
mv app/models/usage_meter.rb       packs/platform/app/models/
mv app/models/actor.rb             packs/platform/app/models/
mv app/models/intention.rb         packs/platform/app/models/
mv app/models/concerns/tenant_scoped.rb packs/platform/app/concerns/
```

**Platform operations** (29 files):
```bash
mv app/operations/auth/     packs/platform/app/operations/
mv app/operations/context/  packs/platform/app/operations/
mv app/operations/session/  packs/platform/app/operations/
mv app/operations/channel/  packs/platform/app/operations/
mv app/operations/others/   packs/platform/app/operations/
mv app/operations/nav/      packs/platform/app/operations/
mv app/operations/action/   packs/platform/app/operations/
```

**Platform services** (5 files):
```bash
mv app/services/action_router.rb     packs/platform/app/services/
mv app/services/agent_router.rb      packs/platform/app/services/
mv app/services/llm_service.rb       packs/platform/app/services/
mv app/services/shacl_validator.rb   packs/platform/app/services/
mv app/services/webhook_dispatcher.rb packs/platform/app/services/
```

**Marketplace models** (14 files):
```bash
mv app/models/scenario.rb         packs/marketplace/app/models/
mv app/models/slide.rb            packs/marketplace/app/models/
# ... etc for all 14 application models
```

**Marketplace operations** (20 files):
```bash
mv app/operations/ai/       packs/marketplace/app/operations/
mv app/operations/scenario/  packs/marketplace/app/operations/
mv app/operations/slide/     packs/marketplace/app/operations/
mv app/operations/region/    packs/marketplace/app/operations/
mv app/operations/modal/     packs/marketplace/app/operations/
mv app/operations/style/     packs/marketplace/app/operations/
```

### Step 4: Configure autoload paths

```ruby
# config/application.rb
config.autoload_paths += Dir[Rails.root.join("packs/*/app/*")]
config.autoload_paths += Dir[Rails.root.join("packs/*/app/public")]
config.autoload_paths += Dir[Rails.root.join("packs/*/app/concerns")]
```

### Step 5: Create public API files

Platform's public API — the only things marketplace can reference:

```ruby
# packs/platform/app/public/context.rb
# Re-exports Context model for use by dependent packs
# (file can be empty — Packwerk uses the public/ directory as the boundary)
```

No code needed in public files if the model names match. Packwerk treats anything in `app/public/` as the pack's public interface. Marketplace can reference `Context`, `User`, `SessionParticipant`, `GlobalRoute` — because those exist in platform's public directory.

### Step 6: Update importmap

```ruby
# config/importmap.rb
pin_all_from "packs/platform/javascript/lib", under: "lib"
pin_all_from "packs/platform/javascript/controllers", under: "controllers"
pin_all_from "packs/marketplace/javascript/controllers", under: "controllers"
```

### Step 7: Run packwerk check

```bash
bundle exec packwerk check
```

Fix any violations. The most likely violations:
- Platform operations that reference application models (shouldn't exist but verify)
- Application operations that reach into platform internals (should go through public API)

### Step 8: CI integration

```yaml
# .github/workflows/ci.yml (or equivalent)
- name: Check architectural boundaries
  run: bundle exec packwerk check
```

## What This Does NOT Change

- No class renaming. `Context` stays `Context`, not `Platform::Context`.
- No migration split. Single `db/migrate/` directory.
- No route changes. Single `config/routes.rb`.
- No gem extraction. Everything stays in one repo, one deploy.
- No runtime behavior change. Packwerk is development/CI only.
- GlobalRoute continues to auto-discover operations from both packs.

## Dependency Direction

```
┌─────────────────────────┐
│  packs/marketplace       │
│                          │
│  Scenarios, Slides,      │
│  Components, AI Chat,    │
│  Designs, Todos          │
│                          │
│  depends on ↓            │
└──────────┬──────────────┘
           │
┌──────────▼──────────────┐
│  packs/platform          │
│                          │
│  Auth, Context, Sessions,│
│  Channels, Others, WAMP, │
│  ActionRouter, LLM,      │
│  API Keys, Usage Metering │
│                          │
│  depends on: nothing      │
└─────────────────────────┘
```

This is the Shopify pattern: domain packs with one-way dependencies, enforced by static analysis. The platform pack has zero upward dependencies. A second application pack (e.g., `packs/editor/`, `packs/support/`) could depend on platform without touching marketplace.

## Files

| File | Action |
|------|--------|
| `Gemfile` | Add `packwerk` |
| `packwerk.yml` | NEW — Packwerk config |
| `package.yml` | NEW — Root package |
| `packs/platform/package.yml` | NEW — Platform pack (no deps) |
| `packs/marketplace/package.yml` | NEW — Marketplace pack (depends on platform) |
| `packs/platform/app/public/*.rb` | NEW — Public API boundary |
| `config/application.rb` | Add pack autoload paths |
| `config/importmap.rb` | Add pack JS paths |
| 50+ files | MOVE — from `app/` to `packs/platform/app/` or `packs/marketplace/app/` |

## Verification

1. `bundle exec packwerk check` passes with zero violations
2. All operations still resolve via GlobalRoute
3. All WAMP procedures still dispatch correctly
4. All HTTP routes still work
5. All Stimulus controllers still connect
6. Adding a `Scenario` reference to a platform operation → `packwerk check` fails
7. Adding a second pack (`packs/editor/package.yml` with `dependencies: [packs/platform]`) works
