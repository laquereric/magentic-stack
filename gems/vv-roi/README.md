# vv-roi

Prices the options a decision already declares. It answers the question
the threshold layer cannot: not *how sure is the model*, but *what is it
worth to act on that*.

```ruby
stakes = Vv::DecisionObject::Roi::Stakes.build(
  question: :route,
  unit: :usd,
  escape: :human_review,
  options: {
    deterministic_code: { gain: 2.00, loss: 12.00, reversible: true, reversal_cost: 3.00 },
    fast_llm:           { gain: 1.60, loss: 15.00, reversible: true, reversal_cost: 3.00 },
    human_review:       { gain: 0.00, loss: 0.00,  cost: 9.00, recovery: 0.97 }
  },
  versus: {
    # the confusions that are not symmetric
    [:fast_llm, :human_review] => -420.00
  })[:data]

policy = Vv::DecisionObject::Roi::RiskPolicy.build(
  require_positive_nov: true,
  max_expected_loss:   -25.00,
  worst_case_floor:   -250.00,
  ruin_below:       -5_000.00,
  irreversible_requires_human: true)[:data]

appraisal = Vv::DecisionObject::Roi::Appraisal.of(
  distribution: { fast_llm: 0.55, deterministic_code: 0.45 },
  stakes: stakes, policy: policy, state: ticket)[:data]

appraisal.to_h
# => { unit: :usd, best: :deterministic_code, likeliest: :fast_llm,
#      diverges: true, hold: -7.27, net_option_value: 1.57,
#      downside: { expected_loss: -6.6, worst_case: -12.0, p_loss: 0.55, upside: 0.9 },
#      shape: :concave, reversible: true, verdict: :vetoes,
#      reason: :value_divergence,
#      because: "the likeliest option is :fast_llm but the valuable one is :deterministic_code" }

Vv::DecisionObject::Roi.gate(:commit, appraisal)
# => { ok: true, data: { disposition: :escalate, reason: :value_divergence, ... } }
```

## Why this exists

The `vv-decision-object` README says the right thing — "calibrate floors
by consequence rather than by taste." Nothing in that gem makes
consequence computable. This one does, and keeps the result subordinate
to the floor rather than in place of it.

## Not a seventh layer

Stakes cut across three existing layers rather than sitting beside them:

| Layer | What ROI adds |
|---|---|
| Evaluation | a payoff per declared option, in a declared unit |
| Commitment | a veto that can only ever be more conservative than the floor |
| Feedback | a realized value, to compare against the expected one |

An unpriced decision still runs; it just cannot be audited economically.

## Two rules everything else follows from

**ROI is never more permissive than the threshold layer.** It can veto a
`:commit`. It can never turn an `:escalate` into a `:commit`. A payoff
matrix is an estimate assembled from guesses about a distribution; a
floor is a boundary someone chose on purpose, for this question, at this
consequence. If expected value could clear a floor, a model with an
inflated confidence and a generous payoff table could talk its way into a
side effect — the exact failure the threshold layer exists to prevent.
Confidence is not authorization, and neither is arithmetic performed on
confidence.

**Payoffs are never asked of the adapter.** A model pricing its own
mistakes is grading its own homework, and the resulting number carries no
independent information. Stakes are human-declared, or derived from
logged outcomes in the Feedback layer. The adapter contract does not
change.

## Three kinds of number, kept apart

| Thing | Is | Changes when |
|---|---|---|
| `Stakes` | measurement — what an outcome costs | the business changes |
| `RiskPolicy` | appetite — how much of that you will accept | leadership changes |
| `Constraint` | boundary — what is never permitted | the law changes |

Collapsing these is the common failure. A risk appetite written as a
constraint cannot be tuned; a constraint written as an appetite can be
tuned, which is worse.

## The payoff matrix

`gain` is what an option is worth when it is right. `loss` is a positive
magnitude, subtracted when it is wrong. `cost` is paid either way.
`versus` overrides specific confusions — the point of the matrix is that
mistakes are not interchangeable, and a ticket that needed a human and
got a bot is not the same error as one that needed a reasoning model and
got a fast one.

The escape option is priced differently, because it does not have to be
right, it has to recover: its value is `recovery × gain(truth) − cost`.
`recovery` below 1.0 is where you admit humans are also wrong sometimes.

Payoff values may be callables on state, so loss can scale with the
amount at risk. A callable that raises makes the cell unevaluable, which
counts as the bad case — the same reasoning that makes an unevaluable
constraint count as violated.

## What gets computed

Given a posterior `p(t)` over options and the matrix `V(a, t)`:

| | |
|---|---|
| **expected value** | `EV(a) = Σ p(t)·V(a,t)`, per action |
| **hold value** | `EV(escape)` — the value of keeping the option open |
| **net option value** | `EV(best) − hold`. Positive NOV is the only economic argument for committing, and it is *not* the same as positive EV |
| **downside** | expected loss `Σ_{V<0} p(t)·V(a,t)`, worst plausible cell, `p_loss` |
| **upside** | `Σ_{V>0} p(t)·V(a,t)` |
| **shape** | `:convex`, `:linear`, `:concave` past `concavity_ratio`, `:ruinous` below `ruin_below` |

Shape is a coarse label, not a Greek. It exists so a reviewer can see at
a glance that a decision has bounded upside and a long tail — an unhedged
short option — even when its expected value looks fine.

## The likely option and the valuable option are different options

Under asymmetric costs, `argmax p` is not `argmax EV`. ROI reports
`diverges: true` and, by default, vetoes with reason `:value_divergence`.
It does not silently substitute the higher-EV option, because that option
never cleared its own floor. `allow_cost_sensitive_selection: true`
permits the substitution, and the substituted option must still clear its
own `option_floors` entry — cost-sensitive selection is legitimate, but
it is a different decision and has to pass the same gate.

## Ruin is not an expected-value question

`ruin_below` marks a cell as unrecoverable. No EV argument clears it,
however favorable, because the whole logic of expected value assumes you
get to keep playing. A plausible ruinous branch under the best action
vetoes to `:escalate`; if every action including the escape carries one,
the disposition becomes `:refuse`, since there is nothing the object is
permitted to do.

## Dispositions and reasons

`Roi.gate` only ever downgrades:

```
:commit + clears   -> :commit
:commit + vetoes   -> :escalate   (or :refuse on unavoidable ruin)
anything else      -> unchanged
```

Reason codes, in the existing style, checked in this order — the
structural and appetite limits before the economics, so the most
conservative answer is the one reported:

| reason | when |
|---|---|
| `stakes_invalid` | build-time; all problems named at once in `problems:` |
| `stakes_error` | a payoff callable could not be evaluated |
| `ruin_risk` | a plausible unrecoverable branch |
| `unpriced_option` | the distribution has mass on options with no declared payoff |
| `downside_exceeded` | expected loss or worst case beyond declared appetite |
| `irreversible_commitment` | policy reserves one-way doors for humans |
| `negative_expected_value` | net option value ≤ 0; holding beats exercising |
| `value_divergence` | the likeliest option is not the valuable one |

## Reversibility is the optionality term

`reversible:` and `reversal_cost:` are what connect a single decision to
the sequence of them. A reversible commitment has bounded downside — you
can undo it for a known price, which is a long option. An irreversible
one is a sold option: you collected the speed and handed the future the
right to present you a bill at a time of its choosing.

```ruby
Vv::DecisionObject::Roi.portfolio(priced)
# => { ok: true, data: { n:, committed:, expected_total:, realized_total:,
#                        downside_exposure:, escalation_spend:,
#                        short_option_position:, shape_mix: }, underpowered: }
```

A system whose share of irreversible concave commitments is rising is
trading futures for features. The gem cannot tell you that is wrong. It
can stop it from being invisible.

## Feedback: expected against realized

`Roi.realize` prices the outcomes the Feedback layer already tracks. The
comparison is the only thing that makes the payoff table falsifiable —
without it, the matrix is a set of assertions no one will ever revisit.

```ruby
Vv::DecisionObject::Roi.realize({ resolved: true, reopened: false },
  valuation: { resolved: { true => 2.00, false => -15.00 },
               reopened: { true => -8.00 } })
# => { ok: true, data: { realized: 2.0 } }
```

Three audit modes, bracketing the five in `Audit`:

| Mode | Heuristic |
|---|---|
| `payoff_drift` | realized value diverges from expected beyond tolerance — the matrix or the model is miscalibrated |
| `escalation_waste` | review spend exceeds the loss it avoided — the floor is too high |
| `tail_blindness` | the declared worst case was never approached — the tail is fictional, or you have not run long enough |

`over_automation` catches a floor set too low. `escalation_waste` catches
one set too high. Together they define the band you are actually trying
to find, and neither is measurable without stakes. Same contract as the
existing audit: declared overridable thresholds, evidence attached to
every finding, and `underpowered: true` rather than silent confidence on
a small set.

## Never raises

Every public method returns `{ ok: true, data: }` or
`{ ok: false, reason:, because: }`, the same contract as
`vv-decision-object`. A payoff that cannot be evaluated becomes
`:stakes_error`, not a backtrace.

## Piloting

Price the decision you already piloted, not a new one. Run in shadow mode
with `Adapters::Static`, log the full appraisal beside the real outcome,
and leave `require_positive_nov` on with every other guard off for the
first few thousand decisions — you are calibrating the payoff table, and
a guard that fires before the table is trustworthy just teaches people to
raise it.

Get `versus` right before `loss`. The asymmetric confusions carry most of
the value and are the entries people have actual opinions about; a
uniform `loss` is usually close enough to start.

Measure cost per *accepted* decision, as the `vv-decision-object` README
says, but now the number includes the cost of wrong routes rather than
estimating around it.

## What it deliberately does not do

- **No discounting.** Payoffs are contemporaneous. A decision whose
  consequences land quarters later needs a `horizon:` term and a rate,
  and that is a different module with a different argument behind it.
- **No correlation between decisions.** Portfolio downside is summed, not
  aggregated — it is an upper bound and is labeled as one. Correlated
  failures across a definition are exactly what a naive sum misses.
- **No inference of payoffs from outcomes.** `payoff_drift` names the
  gap; it does not close it. Fitting the matrix to observed results would
  make the audit unable to detect the thing it exists to detect.
- **No currency conversion**, and no opinion about whether `unit:` is
  dollars, minutes, or incidents. Mixing units across a portfolio is
  reported, not reconciled.

The long-form argument is in [`docs/research/roi.md`](docs/research/roi.md).

## Where the specs departed from the research note

Four of the examples in `docs/research/roi_spec.rb` did not hold against
the module's actual semantics. The specs were fixed, not the library — in
each case the test's premise was wrong, not the code.

1. **"prefers the valuable option over the likely one"** — at
   `{fast_llm: 0.72, human_review: 0.28}` the net option value is
   genuinely negative (EV −12 against a hold of −7.88), so
   `require_positive_nov` fires before the divergence check and the
   reason is `negative_expected_value`. The distribution became
   `{fast_llm: 0.55, deterministic_code: 0.45}`, which isolates
   divergence with a positive NOV, and a separate example now pins the
   negative-NOV veto.
2. **"labels … as concave"** — `allow_cost_sensitive_selection` does not
   change which row is `best` (that is always argmax EV), so the
   appraised row was the symmetric `deterministic_code` one. Rewritten at
   `{fast_llm: 0.99, human_review: 0.01}`, where `fast_llm` really is
   best: it clears on expected value and is `:concave` on shape — a
   sharper version of the point.
3. **"will not let expected value argue past ruin"** — a −50,000 cell
   drags that action out of contention, and ruin is only checked on the
   best row. A `trade_stakes` fixture (a 0.5% chance of a −50k confusion
   behind a +500 gain) now clears without `ruin_below` and vetoes
   `:ruin_risk` with it.
4. **"treats an unevaluable payoff as the bad case"** — the override
   dropped `fast_llm` from `options` but left it in the inherited
   `versus`, so `Stakes.build` correctly refused and the fixture arrived
   as `nil`. It now passes `versus: {}`, and the helper raises on a
   fixture that fails to build rather than letting a `nil` travel.

## Install

```ruby
gem "vv-roi"
```

Ruby >= 3.2, no runtime dependencies. Designed to sit beside
[`vv-decision-object`](https://github.com/laquereric/vv-decision-object)
— it occupies that gem's namespace and gates its dispositions, but loads
and runs on its own.

```
bundle install
bundle exec rspec
```
