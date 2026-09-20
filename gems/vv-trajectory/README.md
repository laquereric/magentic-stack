# vv-trajectory

Private gem. **Recorder and measure.** The path taken toward a slice's aim, and
the pump that moves a working session toward more smart context and less dumb
context.

Not on rubygems.org. No runtime dependencies. Calls no model.

## Where it sits

```
  ░░░░░░░░░░ DUMB CONTEXT ░░░░░░░░░░   attention spent, constraints lost
  ══════════ vv-trajectory ═════════   the edge, and the pump across it
  ---------- SMART CONTEXT ---------   the frame, the decisions, the record
  ---------- vv-frame       --------
  ---------- perch (slices) --------   the aim and its receiver
```

**Above perch.** A slice says what is being built and for whom. A trajectory is
the path actually taken toward it, and the evidence about how that went. It
cites the slice; it never closes it.

**At the edge of the smart zone.** The symptoms of the dumb zone — looping on
the same wrong fix, answering a slightly different question than the one asked,
redoing finished work — are all visible in a trajectory. Length is a weak proxy
for them. **Repetition is evidence.**

## And it moves the edge

RaML's result is that a reasoning trajectory is a **pseudo-gradient update to
the model's parameters**: each token is one inner-loop optimisation step, and
longer trajectories mean more adaptation. That sits awkwardly beside the
smart-zone result, where longer sessions mean worse attention — until you notice
they are about different objects.

> The **trajectory** is the update. It should be long.
> The **conversation** is the medium. It decays.

Separate them and the contradiction goes away: keep the steps, which are
observed and durable, and discard the prose, which was never the record. Then a
long trajectory *raises* the fraction of the working context that survives a
reset instead of consuming it.

That is the pump, and `Gradient` is where the movement is measured:

```ruby
run.gradient.to_h
# => { direction: :toward_smart, net: 5,
#      smart_steps: 5, dumb_steps: 0,
#      durable_tokens: 84, ephemeral_tokens: 10_000,
#      estimated_durable_fraction: 0.0083,
#      reset_recommended: false }
```

A step moves **toward smart** when it is a grounded call with a receipt — the
record now holds an observation it did not. It moves **toward dumb** when a
dumb-zone finding names it. `reset_recommended?` fires on losing ground, on
leaving the smart zone, or on a critical finding — **never on length alone.**

A reset is the operate instrument applied to context: the conversation is
disposable, the record is not. `run.to_record` is what you reload from.

## Recording and measuring

```ruby
require "vv-trajectory"
T = Vv::Trajectory

run = T.record(key: "r1", aim: "fix the null check in auth.rb",
               reached_aim: true, step_budget: 8, prose_chars: 8_000,
               steps: [
                 { tool: "read_file",   args: { path: "auth.rb" }, receipt: { tool: "read_file" } },
                 { tool: "run_tests",   args: { suite: "all" },    receipt: { tool: "run_tests" } },
                 { tool: "write_patch", args: { file: "auth.rb" }, receipt: { tool: "write_patch" } },
                 { tool: "run_tests",   args: { suite: "auth" },   receipt: { tool: "run_tests" } }
               ]).fetch(:run)

gold = T.gold(key: "g1", aim: "fix the null check in auth.rb", steps: [
  { accepts: ["read_file"],          required_args: { "path" => "auth.rb" } },
  { accepts: %w[search_code grep],   required_args: {} },
  { accepts: ["write_patch"],        required_args: { "file" => "auth.rb" } },
  { accepts: ["run_tests"],          required_args: { "suite" => "auth" } }
]).fetch(:gold)

T.evaluate(run: run, gold: gold, observed_at: "2026-09-19").fetch(:verdict).to_h
# tool_selection:     precision 0.75   ← ran the suite where the oracle searched
# sequencing:         tau 0.3333       ← below the 0.85 gate
# argument_accuracy:  recall 1.0, precision 0.75
```

**The run succeeded.** Tests pass, aim reached. The trajectory shows it ran the
whole suite before it had anything to test, and outcome eval would have scored
it perfect. That gap is the reason this gem exists: an agent that gets the right
answer through the wrong path is fragile, and nothing about the outcome says so.

A gold step names a **set** of acceptable tools, because there is rarely one
correct path — searching the docs then writing, or writing then testing, can
both be right.

## Five refusals (load-bearing)

Enforced by the absence of a method wherever one will do, and every one planted.

| | Forbidden | Grounding |
|---|---|---|
| R1 | summarisation | Steps are verbatim. The prose is not the record, so compacting it loses nothing — and rewriting a step would lose the only thing that is. |
| R2 | judging | Nothing here calls a model; `lib/` reaches no network. Every metric is computed from two records and no judgement. |
| R3 | a reference written from a run | `Gold.from_run` refuses: a reference authored from an observed run measures the run against itself. The eval set is the thermometer, not the target. |
| R4 | a single-run pass | Reliability over k < 2 refuses rather than returning a number that will be read as one. |
| R5 | a fabricated step | Every claimed call is cross-referenced against the execution log. A claim with no receipt is critical: everything after it reasons over invented data. |

On R2 — a judge's score may be **recorded**, never computed here, and it arrives
with the judge's identity and a **pinned version**, because a provider updating a
model underneath an unpinned judge is how a score changes with nothing else
changing. `Verdict#standalone?` is false for any judge verdict whatever its
confidence: it is a first pass requiring review.

`judge` is refused as an *operation*; recording one is a different act, so
`judge_id`, `judge_version` and `from_judge` are named in
`JUDGE_RECORDING_ALLOWED` rather than left to a substring match.

**No verdict promotes.** There is no `pass` a verdict can write and no method
that closes a slice. Promotion is not a score clearing a bar — the report is
evidence put in front of someone who signs, and the slice's outward signal is
measured on the receiver rather than declared by the system that served them.

## What the detector looks for

| finding | means |
|---|---|
| `step_repetition` | the same tool with the same arguments more than twice — the second attempt is a retry, the third is a loop |
| `reasoning_loop` | the same reasoning text more than twice — restating, not progressing |
| `goal_drift` | the aim restated as something else after a tool result. Named for what the record shows, not for the cause: a tool result may be data, it is never an instruction |
| `budget_exhaustion` | the step budget reached without the aim — a scoping problem, not a capability problem |
| `beyond_the_smart_zone` | carried prose past ~100K estimated tokens |

## Medallion

Steps are **Bronze** — observed, verbatim, never summarised on ingest. Verdicts
are **Silver** — typed facts about Bronze, carrying a clock, because a conclusion
drawn on Tuesday was not wrong on Monday. A gold trajectory is **Gold** —
contracted, frozen, and authored by hand. There is no Platinum here; this gem
holds no weights.

## Develop

```
bundle install
bundle exec rspec
```
