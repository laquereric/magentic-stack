# Changelog

## 0.1.0 — 2026-09-20

First cut. Decisions as durable, inspectable, governable objects.

- `Vv::DecisionObject::Definition` — the six-layer declaration (intent,
  constraint, signal, evaluation, commitment, feedback) with a builder
  DSL; reports `missing_layers` without blocking a mid-build definition
- `Vv::DecisionObject::Question` — `Choice`, `Score`, `Noul`; closed
  option sets must declare an escape route
- `Vv::DecisionObject::Table` — DMN-style decision tables with `:first`,
  `:unique` and `:collect` hit policies
- `Vv::DecisionObject::Constraint` — hard and soft boundaries checked in
  code before anything probabilistic; unevaluable counts as violated
- `Vv::DecisionObject::Policy` — per-question and per-option confidence
  floors, margin floor, four dispositions
- `Vv::DecisionObject::Decision` — one situation, evaluated in order and
  traced end to end; `commit!` gated on the disposition
- `Vv::DecisionObject::Lifecycle` — designed → … → revised / decommissioned
- `Vv::DecisionObject::Trace` — append-only, injected clock, JSON and
  Agent Decision Record output
- `Vv::DecisionObject::Adapters` — `Static`, `Unavailable`, `Chain`, and
  a transport-free `Jev` response mapper
- `Vv::DecisionObject::Audit` — the five named failure modes as
  heuristics with declared thresholds
- Never-raise envelopes throughout
