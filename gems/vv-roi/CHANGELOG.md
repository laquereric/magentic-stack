# Changelog

## 0.1.0 — 2026-09-20

First cut. Pricing the options a decision already declares.

- `Vv::DecisionObject::Roi::Stakes` — human-declared payoffs per option
  (`gain`, `loss`, `cost`, `reversible`, `reversal_cost`, `recovery`)
  with a `versus` matrix for the confusions that are not symmetric; the
  escape option is priced to recover rather than to be right; payoffs may
  be callables on state, and one that raises makes the cell unevaluable,
  which counts as the bad case
- `Vv::DecisionObject::Roi::RiskPolicy` — appetite, kept separate from
  measurement and from constraint: `require_positive_nov`,
  `max_expected_loss`, `worst_case_floor`, `ruin_below`,
  `irreversible_requires_human`, `allow_cost_sensitive_selection`
- `Vv::DecisionObject::Roi::Appraisal` — expected value per action, hold
  value, net option value, downside and upside, and a coarse `shape`
  (`:convex` / `:linear` / `:concave` / `:ruinous`); reports when the
  likeliest option is not the valuable one
- `Roi.gate` — the one place ROI touches disposition, and it only ever
  downgrades: a vetoed `:commit` becomes `:escalate`, or `:refuse` when
  every action carries an unrecoverable branch
- `Roi.realize` — the feedback layer, priced, so the payoff table is
  falsifiable against observed outcomes
- `Roi.audit` — `payoff_drift`, `escalation_waste`, `tail_blindness`;
  declared overridable thresholds, evidence on every finding, and
  `underpowered: true` rather than silent confidence on a small set
- `Roi.portfolio` — `short_option_position` and `shape_mix`, so a rising
  share of irreversible concave commitments stops being invisible
- Never raises: `{ ok: true, data: }` or `{ ok: false, reason:, because: }`
