# vv-slo

Reliability as an **enforceable spec**, not a slide. Three artifacts from
[`docs/SloReliability.md`](docs/SloReliability.md), modelled so a pipeline can
query them.

The premise: an agent implements exactly the spec it was given and nothing more.
An unwritten reliability requirement produces a service that doesn't have it.

## The three artifacts

### 1. An SLO a machine can read

```ruby
slo = Vv::Slo::Objective.new(
  service: "checkout-api", target: 0.999, time_window: "30d",
  good_query:  'sum(http_requests_total{code=~"2..|3.."})',
  total_query: "sum(http_requests_total)"
)
slo.validate
# => { ok: true, errorBudget: 0.001, budgetMinutes: 43.2, ... }
```

An SLO with no queries is **refused as `:unqueryable`** — that is the entire
point of the gem. A number on a dashboard is not a control mechanism.

### 2. The error budget as a deployment gate — with an agent rung

```ruby
Vv::Slo::BudgetGate.evaluate(remaining: 0.30, actor: :agent)
# => { agentChanges: :human_review, allowedWithoutReview: false, ... }
Vv::Slo::BudgetGate.evaluate(remaining: 0.30, actor: :human)
# => { allowedWithoutReview: true, ... }
```

Five rungs, not a binary switch. The rung that matters for a fleet: **once the
budget is dented, machine-generated changes need human review** while the same
budget still permits a human deploy. At zero, agents are `:blocked` outright.

Burn-rate tiers each name their **own** pair of windows, and a tier fires only
when both exceed its factor:

```ruby
Vv::Slo::BurnRate.classify("1h" => 20.0, "5m" => 18.0)  # => :page
Vv::Slo::BurnRate.classify("1h" => 20.0, "5m" =>  1.0)  # => :none — spike already subsided
```

### 3. The observability contract

```ruby
c.check_signal(name: "log", attributes: { "authorization" => "Bearer …" })
# => { ok: false, reason: :forbidden_attribute, ... }
```

Telemetry is a public API. Enforced at **two** points, build and runtime.
Identity requires an owner — telemetry without one is useless at 3:12 AM.
Cardinality limits are in the contract because cardinality explosion is a
**cost** failure, not a style one.

### 4. The runbook gradient, and where the human gate sits

```ruby
# restart a stateless pod — irreversible, tiny radius
Vv::Slo::Runbook.hitl_required?(irreversible: true, blast_radius: :negligible)
# => { hitlRequired: false, because: "consequence is contained; log and proceed" }

# drop a production index — irreversible, enormous radius
Vv::Slo::Runbook.hitl_required?(irreversible: true, blast_radius: :organization)
# => { hitlRequired: true, because: "irreversible with a organization blast radius" }
```

**`hitl_required?` takes no confidence argument, and a test asserts it never
will.** The gate sits at the intersection of irreversibility and blast radius —
never at the model's confidence threshold. A model that is confident and wrong
is more dangerous than one that hesitates, and agents optimised for accuracy
converge on always-escalate, which fails exactly the tasks that needed
judgement. **The consequence category is stable; the confidence level isn't.**

## Why this gem is here

This repository *is* an agent fleet. grok, Manus and Claude ship changes to
these gems continuously. Every claim in the source article about handing
production to agents describes our own situation, so the artifacts are modelled
rather than admired.

## Honest limits

Carried from the source rather than smoothed over:

- **OpenSLO's production adoption is unclear** — a promising standard, not a
  settled fact. Sloth is the more mature companion.
- **No public case documents a gate like this actually stopping an
  agent-generated deploy.** The mechanics of each piece are proven
  individually; the combination is where teams stand.
- The five-rung ladder is *"the ladder I see most often"* in the source, not a
  standard. Treat the thresholds as a starting position.
- The automation and the emergency override are designed together. Google's own
  error-budget policy has a CTO escalation clause. A mechanical gate is meant to
  take politics out of daily decisions, not remove the right to an exception.

`rspec` — 23 examples, 0 failures.
