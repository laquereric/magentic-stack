# vv-decision-object

A decision as a durable, inspectable, governable object — rather than a
moment, a memo, or a model output.

```ruby
definition = Vv::DecisionObject.define(:route_support_ticket) do |d|
  d.intent "Route the ticket to the handler that can close it",
           tradeoffs: ["speed over precision below $500 exposure"]

  d.constraint(:no_pii_to_vendor, because: "DPA forbids vendor PII") { |s| !s[:contains_pii] }
  d.signal :subject, :body, :tier, :contains_pii

  d.choice(:route,
    instructions: "Which handler should process this ticket?",
    criteria: {
      deterministic_code: "A fixed lookup or rule is sufficient",
      fast_llm:           "Short generation, limited reasoning",
      reasoning_llm:      "Multi-step interpretation is required",
      human_review:       "Ambiguous, sensitive, or outside the routes"
    })
  d.noul(:refund_requested, instructions: "Does the body request a refund?")

  d.thresholds floors: { route: 0.80 }, margin_floor: 0.15
  d.commit_to :assign_handler
  d.track :resolved, :reopened
end[:data]

decision = definition.instantiate(state: ticket, actor: "agent:triage-1")[:data]

decision.evaluate(adapter)
# => { ok: true, data: { disposition: :commit, because: "every declared floor cleared", ... } }

decision.commit!(handler: "billing")
decision.record_outcome(resolved: true, reopened: false)
```

## Why this exists

"Decision object" arrived from four directions at once and they are not
interchangeable: a rules table (DMN, Appian), a proposal bundled with its
constraints (agent literature), a recorded outcome (decision
intelligence), and a six-layer ontology (Decision Object Theory). See
[`docs/research/`](docs/research/) for the survey.

This gem takes the parts that have running code and makes them one
record. The underlying insight is old and correct — separate decision
quality from outcome quality, make reasoning durable, version it like
code. What is new is that agents made it economically necessary: the
volume of machine judgments has outrun anyone's ability to reconstruct
them after the fact, and the cost of writing a decision down collapsed
once the system making the decision could also record it.

## The separation it enforces

| Layer | Best at | Never delegated to it |
|---|---|---|
| Deterministic code | arithmetic, permissions, limits, dates, side effects | ambiguous semantic classification |
| Decision model | bounded choices, scores, yes/no judgments | prose, exact calculation, final authorization |
| Language model | explanation, synthesis, drafting, open-ended reasoning | unsupervised authority over consequences |

`Constraint` runs in code, first. `Question` carries the semantic part.
`Policy` stands between them with a threshold someone chose on purpose.
A probability is never wired directly to a side effect.

## The six layers

`Definition` is the design-time declaration. A model occupies only part
of Signal and Evaluation; everything else here is what separates *model
accuracy* from *decision quality*, and it is the part usually missing.

| Layer | Declared with | Holds |
|---|---|---|
| Intent | `intent` | objective, acceptable trade-offs, owner |
| Constraint | `constraint` | legal, financial, ethical, temporal boundaries |
| Signal | `signal` | what the judgment is allowed to see |
| Evaluation | `choice` / `score` / `noul` / `decision_table` / `thresholds` | how it is scored |
| Commitment | `commit_to` | what the object is permitted to do |
| Feedback | `track` | what gets recorded afterwards |

A definition can be valid and still incomplete — `#missing_layers` names
the governance gap without blocking a team that is mid-build.

```ruby
definition.complete?       # => true
definition.missing_layers  # => [:feedback]
```

## Questions

Three primitives, in the shape Jev made legible. A question declares its
own answer space, so the answer is data rather than prose to be parsed.

| Primitive | Returns | For |
|---|---|---|
| `Choice` | one declared option + distribution + confidence | route, triage, classify |
| `Score` | a point on a described rubric + distribution | rank urgency, quality, priority |
| `Noul` | probability that a proposition is true | gate a branch |

Keep them atomic. "Is this trade safe?" hides market, policy, exposure,
timing and execution judgments behind one answer; decompose, keep
arithmetic in code, and ask only the genuinely semantic part.

`Choice` **requires an escape option** (`human_review`, `unknown`,
`other`, …). A closed set with no way out forces a wrong answer, so a
definition without one is refused at build time.

## Decision tables

DMN made *rules* into objects a decade before anyone proposed making
*judgments* into objects. Where a rule will do, a rule is better — it is
auditable by reading it, costs nothing, and cannot drift between model
versions.

```ruby
d.decision_table(:refund_authority,
  inputs: %i[amount tier], outputs: %i[approver], hit_policy: :first,
  rules: [
    { when: { amount: ->(v) { v < 50 } },                  then: { approver: "auto" } },
    { when: { amount: ->(v) { v < 500 }, tier: "premium" }, then: { approver: "agent" } },
    { when: { amount: :any, tier: :any },                   then: { approver: "manager" } }
  ])
```

Conditions may be `:any`, a literal, a `Range`, a `Regexp`, an `Array`
of any of those, or a callable. Hit policies: `:first`, `:unique`
(refuses ambiguity), `:collect`.

## Thresholds are the whole point

Confidence is not authorization. A high number cannot approve a payment
or bypass a risk limit — all it can do is clear a floor someone chose on
purpose, for this question, at this consequence. A wrong FAQ route and a
wrong payment route must not share a floor.

```ruby
d.thresholds(
  floors:        { route: 0.80, severity: 0.70 },
  option_floors: { route: { deterministic_code: 0.90, human_review: 0.0 } },
  margin_floor:  0.15,
  on_uncertain:  :escalate
)
```

`margin_floor` catches the case a raw confidence number hides: a coin
flip between two options, where the winner's own probability still looks
respectable.

Four dispositions:

| Disposition | When |
|---|---|
| `:commit` | every floor cleared; the commitment layer may act |
| `:escalate` | below a floor, below the margin, or the model took the escape route |
| `:refuse` | a hard constraint failed; no action is permitted |
| `:abstain` | the answer fell outside its declared space |

`#commit!` is refused unless the disposition is `:commit`. That gate is
what the threshold is for.

## Adapters

An adapter answers declared questions. That is its whole contract:

```ruby
#ask(state:, questions:) -> { name => { value:, probabilities:, confidence:, source: } }
```

This gem ships **no network client**. Pinning a vendor's HTTP surface
into a decision-record library would couple the durable half to the
volatile half, and the argument for decision objects is that the record
outlives the model that produced it.

| Adapter | For |
|---|---|
| `Adapters::Static` | shadow mode and specs — run the real path with known answers |
| `Adapters::Unavailable` | rehearse the bypass; provider failure must not trap the workflow |
| `Adapters::Chain` | fall through refusals to a deterministic default |
| `Adapters::Jev` | map a Jev-shaped response into answers; `.adapter` wraps your own call |

```ruby
adapter = Vv::DecisionObject::Adapters::Jev.adapter(model: "jev-1.13.0") do |state, questions|
  client.system_one(state: state, questions: to_jev(questions)).answers
end
```

Pin and log the version. A moving alias can change behind an
application, and a calibrated threshold belongs to the version it was
calibrated against.

## Never raises

Every public method returns `{ ok: true, data: }` or
`{ ok: false, reason:, because: }`. A decision library that raises is a
decision library that loses the decision — a refusal is itself an
outcome and belongs in the trace, not in a backtrace. An adapter that
blows up becomes `:adapter_error`; a constraint that cannot be evaluated
counts as violated, because an unevaluable boundary is not a satisfied
one.

| reason | when |
|---|---|
| `definition_invalid` | build-time problems, all named at once in `problems:` |
| `undeclared_signal` | state carries something the signal layer never declared |
| `adapter_required` / `adapter_error` / `adapter_malformed` / `answer_missing` | the evaluation layer could not be answered |
| `already_evaluated` / `already_committed` / `not_evaluated` | called out of order |
| `not_committable` | `commit!` on a disposition other than `:commit` |
| `undeclared_feedback` | an outcome the feedback layer never declared |
| `illegal_transition` / `unknown_state` | lifecycle |
| `no_matching_rule` / `ambiguous_rules` / `table_invalid` | decision tables |

## Lifecycle

The object persists after execution rather than disappearing. That is
the claim, and it is what forces versioning and governance.

```
designed → instantiated → executed → monitored → audited
                                                   ├→ revised → instantiated
                                                   └→ decommissioned
```

## Trace

Append-only: what was asked, of whom, against which state, what came
back, which floor applied, what was committed, what happened. Structural
keys (`seq`, `at`, `kind`) cannot be shadowed by a payload — a record
whose sequence can be overwritten is not append-only. The clock is
injected, so traces are reproducible.

```ruby
decision.to_h        # the whole object, ready to persist
decision.to_json
decision.to_markdown # an Agent Decision Record, for humans and for git
```

## Audit

Governance gaps only become visible after production incidents — unless
something is looking. `Audit` runs the five named failure modes over a
set of decisions sharing a definition.

```ruby
Vv::DecisionObject.audit(decisions)
# => { ok: true, data: { findings: [...], counts: {...} }, underpowered: false }
```

| Mode | Heuristic |
|---|---|
| `signal_degradation` | decisions running without a declared signal |
| `constraint_drift` | the set spans definition versions; boundaries were not identical |
| `metric_myopia` | one evaluator carries the whole decision |
| `feedback_suppression` | commitments with no recorded outcome, or no feedback layer at all |
| `over_automation` | nothing ever escalated; the floor is decorative |

These are heuristics with declared, overridable thresholds — not
measurements. Each finding names its evidence so a human can disagree
with it, and a set below `min_decisions` is reported as `underpowered:`
rather than silently trusted.

## Piloting

Start with one frequent, reversible decision that already has labeled
outcomes. Run `Adapters::Static` or a real adapter in shadow mode beside
the existing path, log the pinned model version and the full
distribution, calibrate floors by consequence rather than by taste, and
keep a deterministic bypass. Measure cost per *accepted* decision —
inference, retries, fallbacks, human review, and the cost of wrong
routes — not cost per call.

Typed is not correct. Probabilistic is not deterministic. Confidence is
not authorization. State is an attack surface. This gem makes each of
those visible in the record; it does not make them go away.

## Install

```ruby
gem "vv-decision-object"
```

Ruby >= 3.2, no runtime dependencies.

```
bundle install
bundle exec rspec
```
