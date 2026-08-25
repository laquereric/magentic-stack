# rails-cpcp

**CPCP -- coordination-protocol-contract-package.**

> The affordance a deterministic entity grants a non-deterministic entity.

A Rails app is deterministic: one writer, one shape, one journal. An agent is
not -- it proposes, it can be wrong, it retries. CPCP is the seam where the first
grants access to the second, on terms.

That sentence is not a slogan; the rules follow from it. A deterministic system
that lets a non-deterministic one in must be able to say afterwards **what was
done and on whose word**, which is why the boundary never raises, why every
write carries an `operationId`, why the far side is the sole writer, and why the
shapes are closed and owned by OSI Level 8.

## Two faces, different obligations

`direction: :pull` is **read access**. `direction: :push` is **write access**.

- A read costs nothing and promises nothing. No `operationId`.
- A write carries an `operationId` -- the agent's word for what it is doing --
  and an account. The same id is a retry; a different id is a different intent.

## What the engine does

`rails-cpcp` is a mountable Rails engine that projects selected Rails resources
as **CID-grounded JSON-RPC-LD** operations at `/_cpcp/rpc`, with a CID at
`/_cpcp/cid.json`. Your Rails app stays a normal single-container monolith for its usual
deploy; the same source additionally deploys as **two pods**: the Rails app is the
**BACK**, and a **distinct, mandatory FRONT** pod talks to it only over JSON-RPC-LD.
Co-locating FRONT and BACK in one container is **not** a conformant CPCP deployment.

## Install

```ruby
# Gemfile
gem "rails-cpcp"
```

```bash
bin/rails generate rails_cpcp:install   # initializer + Kamal two-pod deploy template
```

Mount the engine and declare projections:

```ruby
# config/routes.rb
mount RailsCpcp::Engine => "/_cpcp"

# config/initializers/rails_cpcp.rb
RailsCpcp.base_iri = "https://yourapp.example.com"

RailsCpcp.project(model: "Build") do
  operation "build.list",   direction: :pull, result: :collection,
    summary: "List builds",   via: ->(p, ctx) { Build.recent.limit(50).map(&:as_api) }
  operation "build.get",    direction: :pull, params: %w[id],
    summary: "Get one build", via: ->(p, ctx) { Build.find(p["id"]).as_api }
  operation "build.create", direction: :push, params: %w[kind spec],
    summary: "Create a build", via: ->(p, ctx) {
      Build.create!(kind: p["kind"], spec: p["spec"], status: "queued", user: ctx.try(:current_user)).as_api
    }
end
```

## Surface (mounted at `/_cpcp`)

| Route | What |
|---|---|
| `GET  /_cpcp/cid.json` | The **CID** projected from your declared operations (JSON-RPC-LD-PS1 shape). |
| `POST /_cpcp/rpc`      | A **JSON-RPC-LD** request envelope; returns a never-raise response envelope. |
| `GET  /_cpcp/up`       | Liveness + `cid_digest` + operation names. |

- **Direction:** `:pull` (BACK->FRONT reads) / `:push` (FRONT->BACK writes).
- **Never-raise:** every response is `{ok:true, result:...}` or `{ok:false, error:{reason, because}}`; handler exceptions become envelopes, never leak.
- **@context / @graph:** requests and results carry a JSON-LD `@context`; `:collection` results are wrapped as `@graph`.
- **Idempotency:** `:push` requires an `operationId`; retries return the same receipt (pluggable store; default in-memory — back it with a table/Redis in production).

A request envelope:

```json
{ "jsonrpc": "2.0", "@context": {"@vocab": "https://w3id.org/laquereric/cpcp/ns#"},
  "id": 1, "method": "build.create", "operationId": "9f8e...",
  "params": { "kind": "model", "spec": "..." } }
```

## Two-pod deployment (mandatory)

The BACK is your Rails image with the engine mounted. The **FRONT** is a distinct
pod built from [`front/`](front/) (a thin, no-Rails JSON-RPC-LD client that reads the
CID and exercises PULL/GET/PUSH over the wire). Deploy both from one revision with
the Kamal template in [`deploy/`](deploy/README.md) — the FRONT is a Kamal `accessory`
beside the Rails `service`, bound to one CID digest.

## Grounding

The projection targets the public OWL/SHACL vocabulary at
`https://w3id.org/laquereric/cpcp/ns#` (see `cyborg-pod-contract-package`) and mirrors
the `JSON-RPC-LD-PS1-P1/P2` CID shape. Apache-2.0.
