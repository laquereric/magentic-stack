# vv-routing

Two-tier LLM routing, split by the question the two-tier literature leaves out.

Source: [`docs/MonolitheLlmDead.md`](docs/MonolitheLlmDead.md).

## The point

The article's case is sound and incomplete. Route mechanical work — tool calls,
argument extraction, schema validation — to a small fast model, and keep the
frontier model for the answer a person reads, because *"tool calling is a
mechanical syntax task, not an abstract reasoning problem."*

That is an argument about **checkability**. And checkability is not a property of
the task; it is a property of the plane the task runs on.

| | synthesis | production |
|---|---|---|
| what the model emits | code, a plan, a shape, a migration | an answer consumed live |
| who reads it first | the compiler, the specs, the sweep, review | nothing, unless you name something |
| a wrong answer costs | a retry | an incident |

Same task, same tier, different plane, different rule. Extracting a field name
from a migration and extracting a caller's slug in a live request are the same
mechanical operation — and one of them is checked by machinery that already
exists, while the other is checked by whatever you remembered to put there.

```ruby
# Synthesis: no ceremony. The toolchain reads it.
Route.new(task: "extract the migration's table name", kind: :extraction,
          plane: :synthesis, tier: :router)

# Production: refuses.
Route.new(task: "extract the caller's slug", kind: :extraction,
          plane: :production, tier: :router)
# => Vv::Routing::Route::Unverified

# Production, with a checker named:
Route.new(task: "extract the caller's slug", kind: :extraction,
          plane: :production, tier: :router,
          verifier: "TB::AciaLatestPullShape twin")
```

Three ways past the refusal, all of them explicit: name a verifier, take the
frontier tier, or pass `ACCEPTED_UNVERIFIED` with a `because:` — which turns an
omission nobody notices into a decision someone can argue with.

## Where this sits

**SWITCH** owns which model answers. MIND holds no credential and names no
model; it asks for a completion and SWITCH decides what serves it. So this gem
names **no models** — not DeepSeek, not Qwen, not any frontier flagship. It
models the *shape* of the choice (`:router` / `:frontier`), and a spec pins the
absence, because a gem that hardcoded a model would be reaching through SWITCH's
seam from the wrong side. The article's throughput numbers were true of
particular hosts in the week it was written; the shape outlasts them.

**BUS** carries events, **MIND** derives readings — both production-plane
callers. A route there is exactly the case that needs a named verifier, and the
substrate already has the vocabulary for one: a shape, a runtime twin, a
never-raise envelope.

## Prefix discipline

The article's sharpest operational claim: the cache discount applies **strictly**
to identical prefixes, and a mutating system prompt or an injected timestamp
takes the hit rate to zero.

```ruby
Prefix.cacheable?("SYSTEM: 2026-09-06 09:15 — you extract fields.")
# => false, ["a timestamp"]

Prefix.audit(first, second)[:verdict]
# => "prefix changed between turns; a partial match is a miss, not a smaller discount"
```

A cliff, not a slope. 99% identical is a miss, and the failure is silent: the
calls still work, the bill just stops being the one that justified the
architecture. This checks the half you control — whether the prefix *you* sent
was stable. Whether a host honours prefix caching, and at what rate, is SWITCH's
relationship and not a promise this gem makes.

## What this does not do

* It does not choose a model, or hold a credential.
* It does not measure cost or latency. The article's figures are a week's
  snapshot of particular hosts.
* It does not forbid a mismatched tier. Routing prose to the small tier is a
  choice someone may make with reason; `tier_suits_kind?` reports it.

```bash
rspec   # 16 examples
```
