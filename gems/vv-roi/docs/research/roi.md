# ROI: pricing the options a decision already declares

`Vv::DecisionObject::Roi` answers the question the threshold layer cannot:
not *how sure is the model*, but *what is it worth to act on that*.

The README already says the right thing — "calibrate floors by consequence
rather than by taste." Nothing in the gem makes consequence computable. This
module does, and keeps the result subordinate to the floor rather than in
place of it.

## Not a seventh layer

Stakes cut across three existing layers rather than sitting beside them:

| Layer | What ROI adds |
|---|---|
| Evaluation | a payoff per declared option, in a declared unit |
| Commitment | a veto that can only ever be more conservative than the floor |
| Feedback | a realized value, to compare against the expected one |

`missing_layers` gains `:stakes` so the gap is visible without blocking a team
mid-build, exactly as `:feedback` behaves today. An unpriced decision runs; it
just cannot be audited economically.

## Two rules everything else follows from

**ROI is never more permissive than the threshold layer.** It can veto a
`:commit`. It can never turn an `:escalate` into a `:commit`. A payoff matrix
is an estimate assembled from guesses about a distribution; a floor is a
boundary someone chose on purpose, for this question, at this consequence. If
expected value could clear a floor, then a model with an inflated confidence
and a generous payoff table could talk its way into a side effect — which is
the exact failure the threshold layer exists to prevent. Confidence is not
authorization, and neither is arithmetic performed on confidence.

**Payoffs are never asked of the adapter.** A model pricing its own mistakes
is grading its own homework, and the resulting number has no independent
information in it. Stakes are human-declared, or derived from logged outcomes
in the Feedback layer. The adapter's contract does not change.

## Three kinds of number, kept apart

The gem already separates `Constraint` (runs in code, first), `Question`
(semantic), and `Policy` (a threshold someone chose). ROI keeps the same
discipline:

| Thing | Is | Changes when |
|---|---|---|
| `stakes` | measurement — what an outcome costs | the business changes |
| `risk_policy` | appetite — how much of that you'll accept | leadership changes |
| `constraint` | boundary — what is never permitted | the law changes |

Collapsing these is the common failure. A risk appetite written as a constraint
cannot be tuned; a constraint written as an appetite can be tuned, which is
worse.

## Declaration

```ruby
d.stakes(:route,
  unit: :usd,
  escape: :human_review,
  options: {
    deterministic_code: { gain: 2.00, loss: 12.00, reversible: true, reversal_cost: 3.00 },
    fast_llm:           { gain: 1.60, loss: 15.00, reversible: true, reversal_cost: 3.00 },
    reasoning_llm:      { gain: 1.10, loss: 15.00, reversible: true, reversal_cost: 3.00 },
    human_review:       { gain: 0.00, loss: 0.00,  cost: 9.00, recovery: 0.97 }
  },
  versus: {
    # the confusions that are not symmetric
    [:fast_llm, :human_review]      => -420.00,
    [:deterministic_code, :human_review] => -420.00
  })

d.risk_policy(
  require_positive_nov: true,
  max_expected_loss:   -25.00,
  worst_case_floor:   -250.00,
  ruin_below:       -5_000.00,
  irreversible_requires_human: true)

d.realized_value(
  resolved: { true => 2.00, false => -15.00 },
  reopened: { true => -8.00 })
```

`gain` is what the option is worth when it is right. `loss` is a positive
magnitude, subtracted when it is wrong. `cost` is paid either way. `versus`
overrides specific confusions — the point of the matrix is that mistakes are
not interchangeable, and a ticket that needed a human and got a bot is not the
same error as one that needed a reasoning model and got a fast one.

The escape option is priced differently, because it does not have to be right,
it has to recover: its value is `recovery × gain(truth) − cost`. `recovery`
below 1.0 is where you admit humans are also wrong sometimes.

Payoff values may be callables on state, so loss can scale with the amount at
risk. A callable that raises makes the cell unevaluable, which counts as the
bad case — the same reasoning that makes an unevaluable constraint count as
violated.

## What gets computed

Given posterior `p(t)` over options and the matrix `V(a, t)`:

- **expected value** of each action, `EV(a) = Σ p(t)·V(a,t)`
- **hold value**, `EV(escape)` — the value of keeping the option open
- **net option value**, `EV(best) − hold` — the Baldwin & Clark shape: value of
  exercising now, minus the value of not yet having to. Positive NOV is the
  only economic argument for committing, and it is *not* the same as positive EV
- **downside**: expected loss `Σ_{V<0} p(t)·V(a,t)`, worst plausible cell,
  and `p_loss`
- **upside**: `Σ_{V>0} p(t)·V(a,t)`
- **shape**: `:convex` when the upside span dominates, `:concave` when the
  downside span dominates by more than `concavity_ratio`, `:ruinous` when a
  plausible cell falls below `ruin_below`

Shape is a coarse label, not a Greek. It exists so a reviewer can see at a
glance that a decision has bounded upside and a long tail — an unhedged short
option — even when its expected value looks fine.

## The likely option and the valuable option are different options

Under asymmetric costs, `argmax p` is not `argmax EV`. A 70% chance of
`fast_llm` with a −420 confusion against a 25% chance of `human_review` is a
bad trade even though `fast_llm` is the model's answer.

ROI reports `diverges: true` and, by default, vetoes to `:escalate` with reason
`:value_divergence`. It does not silently substitute the higher-EV option,
because that option never cleared its own floor. Setting
`allow_cost_sensitive_selection: true` permits the substitution, and the
substituted option must still clear its own `option_floors` entry — cost-
sensitive selection is legitimate, but it is a different decision and has to
pass the same gate.

## Ruin is not an expected-value question

`ruin_below` marks a cell as unrecoverable. No EV argument clears it, however
favorable, because the whole logic of expected value assumes you get to keep
playing. A plausible ruinous branch under the best action vetoes to
`:escalate`; if every action including the escape carries one, the disposition
becomes `:refuse`, since there is nothing the object is permitted to do.

## Dispositions and new reasons

`Roi.gate` only ever downgrades:

```
:commit + clears   -> :commit
:commit + vetoes   -> :escalate   (or :refuse on unavoidable ruin)
anything else      -> unchanged
```

New reason codes, in the existing style:

| reason | when |
|---|---|
| `stakes_invalid` | build-time; all problems named at once in `problems:` |
| `stakes_error` | a payoff callable could not be evaluated |
| `unpriced_option` | the distribution has mass on options with no declared payoff |
| `negative_expected_value` | net option value ≤ 0; holding beats exercising |
| `downside_exceeded` | expected loss or worst case beyond declared appetite |
| `ruin_risk` | a plausible unrecoverable branch |
| `value_divergence` | the likeliest option is not the valuable one |
| `irreversible_commitment` | policy reserves one-way doors for humans |

## Reversibility is the optionality term

`reversible:` and `reversal_cost:` are what connect a single decision to the
sequence of them. A reversible commitment has bounded downside — you can undo
it for a known price, which is a long option. An irreversible one is a sold
option: you collected the speed and handed the future the right to present you
a bill at a time of its choosing.

`Roi.portfolio` reports `short_option_position` — the count of committed,
irreversible decisions — alongside `shape_mix`. A system whose share of
irreversible concave commitments is rising is, in Beck's terms, trading futures
for features. The gem cannot tell you that is wrong. It can stop it from being
invisible.

## Feedback: expected against realized

`realized_value` prices the outcomes the Feedback layer already tracks. The
comparison is the only thing that makes the payoff table falsifiable — without
it, the matrix is a set of assertions no one will ever revisit.

Three audit modes, bracketing the five in `Audit`:

| Mode | Heuristic |
|---|---|
| `payoff_drift` | realized value diverges from expected beyond tolerance — the matrix or the model is miscalibrated |
| `escalation_waste` | review spend exceeds the loss it avoided — the floor is too high |
| `tail_blindness` | the declared worst case was never approached — the tail is fictional, or you haven't run long enough |

`over_automation` catches a floor set too low. `escalation_waste` catches one
set too high. Together they define the band you are actually trying to find,
and neither is measurable without stakes. Same contract as the existing audit:
declared overridable thresholds, evidence attached to every finding, and
`underpowered: true` rather than silent confidence on a small set.

## Piloting

Price the decision you already piloted, not a new one. Run in shadow mode with
`Adapters::Static`, log the full appraisal beside the real outcome, and leave
`require_positive_nov` on with every other guard off for the first few
thousand decisions — you are calibrating the payoff table, and a guard that
fires before the table is trustworthy just teaches people to raise it.

Get `versus` right before `loss`. The asymmetric confusions carry most of the
value and are the entries people have actual opinions about; a uniform `loss`
is usually close enough to start.

Measure cost per *accepted* decision, as the README says, but now the number
includes the cost of wrong routes rather than estimating around it.

## What it deliberately does not do

- No discounting. Payoffs are contemporaneous. A decision whose consequences
  land quarters later needs a `horizon:` term and a rate, and that is a
  different module with a different argument behind it.
- No correlation between decisions. Portfolio downside is summed, not
  aggregated — it is an upper bound and is labeled as one. Correlated failures
  across a definition are exactly what a naive sum misses.
- No inference of payoffs from outcomes. `payoff_drift` names the gap; it does
  not close it. Fitting the matrix to observed results would make the audit
  unable to detect the thing it exists to detect.
- No currency conversion, and no opinion about whether `unit:` is dollars,
  minutes, or incidents. Mixing units across a portfolio is reported, not
  reconciled.
