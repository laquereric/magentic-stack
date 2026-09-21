# Design — research to API

Where each part of this gem comes from, and what was deliberately left
out. Sources are in [`research/`](research/).

## The problem the research names

Four groups arrived at "decision object" independently and mean
different things by it:

| Source | Means | Has running code |
|---|---|---|
| Appian / OMG DMN | a rules table: inputs, rows, outputs | yes, for a decade |
| Agent / finance literature | a proposal bundled with its constraints and reasoning | partly |
| Cloverpop, decision intelligence | a recorded question, alternatives, choice, outcome | yes, as product |
| Regen AI Institute (Decision Object Theory™) | a six-layer engineered ontology | no — position paper |

The research brief's recommendation was to start from DMN and the
decision-trace work because they have implementations, and to treat
Decision Object Theory as scaffolding for deciding *what a complete
record should contain* rather than as an implementable standard.

That is exactly the split this gem makes:

- **DMN** became `Table` — real, deterministic, load-bearing.
- **Decision traces / AgDR** became `Trace` — append-only, with a
  markdown export meant to be committed beside the code.
- **Decision Object Theory** became `Definition#layers` and
  `Audit` — a completeness checklist and a set of named failure modes,
  not a runtime contract. Nothing in the gem *requires* six layers; it
  reports which are missing.
- **Jev's primitives** became `Question::Choice` / `Score` / `Noul` —
  the interface shape, without the vendor.

## Mapping

| Research | Gem |
|---|---|
| Six-layer ontology (intent / constraint / signal / evaluation / commitment / feedback) | `Definition`, `LAYERS`, `#missing_layers` |
| Lifecycle: design → instantiation → execution → monitoring → audit → revision / decommissioning | `Lifecycle::TRANSITIONS` |
| Named failure modes | `Audit`, `FAILURE_MODES` |
| "Constraints as first-class, not afterthoughts" | `Constraint`, evaluated before the adapter is called |
| "Separate model accuracy from decision quality" | `Policy` sits between `Answer` and `commit!` |
| "A high-quality decision can produce a bad result" | `record_outcome` stores outcome *beside* reasoning, never overwriting it |
| Jev: state + typed questions evaluated in parallel | `Adapter#ask(state:, questions:)` — one call, all questions |
| Jev: Choice / Score / Noul | `Question::Choice` / `Score` / `Noul` |
| Jev: confidence derived from distribution shape | `Answer#confidence`, `#margin` |
| Jev: "closed sets need an escape route" | `Choice#escape` — a set without one fails validation |
| Jev: "keep arithmetic and invariants in code" | `Table` and `Constraint` are plain Ruby; no question computes |
| Jev: "confidence is not authorization" | `commit!` refuses on any disposition but `:commit` |
| Jev: "pin and log the model" | `Answer#source`, traced per answer |
| Jev: "retain a bypass" | `Adapters::Chain`, `Adapters::Unavailable` |
| Jev: "calibrate by consequence" | `Policy#option_floors` |
| DMN decision tables | `Table`, with DMN hit policies |
| Decision traces / AgDR | `Trace`, `#to_markdown` |
| Decision intelligence: record decisions like transactions | `Decision#to_h` / `#to_json` |
| Gartner: decision governance for agent risk | `Audit`, `Lifecycle` |

## Deliberate omissions

**No HTTP client.** The gem does not call Jev, an LLM, or anything else.
A decision record's whole value proposition is that it outlives the
model that produced it; embedding a beta API surface into it would
invert that. `Adapters::Jev.map` translates a response shape — it does
not fetch one. The reviewed Jev SDK shape is documented in
`research/jev-review.md` and may change; the record should not.

**No persistence.** `#to_h` is JSON-ready and that is the boundary.
Which store, which schema version, and which retention policy are
deployment questions, and the gem has no business guessing.

**No vendor performance claims.** The research is explicit that the
40×–200× speed and cost multipliers are vendor-run benchmarks against
vendor-designed harnesses with model-generated labels, described by the
vendor itself as likely near the high end. None of that appears in this
gem's docs as fact.

**No "decision quality score."** Decision Object Theory proposes
metrics — signal detection rate, constraint integrity index, feedback
latency, decision drift score, alignment coherence — and the research
brief lists "do these ever get operationalized, or stay rhetorical?" as
an open question. Inventing formulas for them here would answer that
question dishonestly. `Audit` ships five heuristics with declared,
overridable thresholds and labels them as heuristics.

**No automatic escalation routing.** `Policy` returns `:escalate`. Where
that goes — a queue, a person, a more expensive model — is the
application's, and the gem refuses to guess at an org chart.

## Open questions this gem does not settle

1. Whether a shared decision-record schema emerges, and from whom — a
   standards body, a vendor, or the agent-observability tooling layer.
   `#to_h` is this gem's guess, not a claim.
2. Whether regulatory pressure forces a decision-record format the way
   financial regulation forced transaction records.
3. Whether the decision object becomes an agent *input* — queryable
   institutional precedent — as much as an output. The decision-trace
   work claims the measurable accuracy gains are there. `Trace` is
   queryable by kind, which is a start and not an answer.
