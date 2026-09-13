# SelfLearn — GOLD → PROD → Bronze → Gold recommendations

> ## CONTRACT GEM 2026-09-13 — `gems/vv-self-learn`
>
> Three methods, Wilson interval, collect/eval/recommend envelopes.
> Ornith/GRPO refuse as `ornith_not_v1`. **No AR, no dispatcher.**

**Design only for BACKJOB wiring.** KISS. One loop, one grader
contract, three CPCP methods. Not an Ornith training stack and not
a lakehouse.

**Store is ProcedureRepo** ([`plan_procedure_repo.md`](plan_procedure_repo.md)):
BACK ActiveRecord + digest-named blobs. DuckDB deferred.

Eval doctrine:
[`EvalGrading.md`](../../../magentic-market-ai/docs/research/EvalGrading.md)
(Palamakula, Sep 2026). Companion: Lu et al. *Procedural Graphs*;
[`plan_ornith.md`](plan_ornith.md) (v2: GRPO + five envelopes;
blocked until this file’s plants); [`plan_vv_medallion_memory.md`](plan_vv_medallion_memory.md);
ADR [0052](../adr/0052-the-journal-is-the-only-admission-truth.md),
[0056](../adr/0056-back-and-backjob-are-the-writers.md),
[0057](../adr/0057-three-kinds-of-state.md).

The sentence:

> Gold runs in PROD. PROD lands observed Bronze. Eval grades that
> evidence and **recommends** the next Gold. It does not auto-promote
> on a 100% from five attempts.

---

## What this is not

- Weight updates / Platinum / GRPO. Procedural knowledge stays
  outside the model.
- Five envelope types, a task proposer, novelty embeddings, or a
  0.2 frontier constant. Those can wait.
- PROD writing Gold. PROD may **collect** Bronze. Promote is a
  separate, gated act.
- LLM-as-judge when code can check the receipt (EvalGrading: schema
  / status / party size were deterministic). SHAPE render is a
  digest compare.
- DuckDB.
- MIND as the catalog.

---

## The loop (v1)

```
Gold (frozen) ──serve──► PROD (FRONT / MIND)
                              │
                              │  observed traces, receipts, refusals
                              ▼
                         Bronze collection
                              │
                              │  learn.eval  (golden set + collected Bronze)
                              ▼
                    Gold recommendation
                    (candidate digest + score + CI + coverage)
                              │
                              │  human / DEV grant
                              ▼
                    procedure.promote  →  new Gold
```

Four stages, named so nobody skips eval:

| Stage | What | Who writes |
|---|---|---|
| **Gold** | Production procedure. Graph frozen. | BACKJOB `procedure.promote` only |
| **PROD** | Serve Gold. Do the work. | nobody writes Gold |
| **Bronze collection** | Observed episodes from PROD (and from offline eval runs). Never summarised on ingest. | BACK via `learn.collect` |
| **Gold recommendation** | Eval report: this candidate vs current Gold, planned N, Wilson interval, coverage. Not a promote. | BACKJOB `learn.eval` → `learn.recommend` |

Silver (LinkML / SHACL conform) stays on ProcedureRepo. SelfLearn
does not invent a fourth tier.

---

## Lifecycle EVAL (EvalGrading, applied)

Two modes. Same grader. Same cases when comparing versions.

| Mode | Traffic | Purpose |
|---|---|---|
| **Offline** | Prepared golden set, **outside** PROD. Live solver allowed. | Compare Gold_n vs candidate before promote |
| **Online collect** | PROD traces as Bronze | Coverage the golden set does not have |

Rules, closed:

1. **Deterministic grader first.** For `shape.render.*`: receipt
   digest vs pinned expected bytes. No LLM judge. Tone / extra
   fields are out of score (same cut as the restaurant demo).
2. **Planned N.** N is part of the eval record, not a leftover
   `repeats=5`. A 100% on N=5 is not “perfect reliability.”
3. **Report the interval, not just the point.** Wilson 95% CI on
   the pass rate. 5/5 is ~57–100%. That is sampling uncertainty,
   not a forecast that PROD will drop to 57%.
4. **Equal scores ≠ equivalent, and not “B is better.”** Cases and
   grader stay fixed across versions. Do not test by comparing CI
   endpoints.
5. **Coverage ≠ repetitions.** More repeats of four fixtures will
   not reveal a missing kind (ghis-20 date, HTML-in-props). Missing
   cases are a Bronze/golden-set problem, not an N problem.
6. **Sensitivity is hypothetical until a failure is observed.**
   “One fail would move the score 5 points” is arithmetic, not
   evidence.

Eval result shape (never-raise):

```
{ ok: true,
  gold_digest, candidate_digest,
  n, passes,
  rate, wilson95: [lo, hi],
  delta_rate,                 # candidate − gold; may be 0
  coverage: { cases: [...], because: "golden set, not the population" },
  recommend: true|false,
  because }
```

`recommend: true` only when the **planned** comparison supports it
(and for a deterministic renderer, when digest equality holds on
the whole golden set). `recommend: true` does **not** promote.

---

## PROD may collect; PROD may not promote

ProcedureRepo’s `prod_write_refused` still applies to Gold and to
`procedure.put` of a production binding.

| Act | PROD | DEV / BACKJOB |
|---|---|---|
| `procedure.serve` | yes | yes |
| `learn.collect` | **yes** (observed Bronze only) | yes |
| `learn.eval` / `learn.recommend` | no | yes |
| `procedure.promote` | no | yes, after recommend |

Collect is an append of observed bytes + parent Gold digest. It
does not mutate Gold. Summarising the trace on the way in is
`bronze_mutated`.

---

## First task — SHAPE render (unchanged, smaller)

Golden set: fixture ACIA documents (ghis-19, date-on-19 must refuse,
ghis-20 DateInput, ghis-21 Input, A2UI 0.9.1 emit).

Grader: digest equality with current Gold (or with today’s
`Profile9::Renderer` before the first promote). Deterministic → N=1
is honest; do not pad repeats to look statistical.

PROD Bronze: FRONT/MIND `ui.surface.get` / render receipts and
refusals, citing the Gold digest that served them.

Recommendation: a candidate binding whose golden-set digests match
and whose collected Bronze has no new refusal class the golden set
missed — or a recommendation **not** to promote, with `because`.

mmg-browser cucumber UCs remain PROD acceptance of Gold, not the
eval runner.

---

## CPCP (three methods)

`operationId` on writes. Never-raise.

| Method | Direction | Does |
|---|---|---|
| `learn.collect` | push | Land observed Bronze: trace/receipt/refusal + `gold_digest`. PROD allowed. |
| `learn.eval` | pull | Run golden set (and optional Bronze sample) through the deterministic grader. Returns the eval envelope above. |
| `learn.recommend` | pull | Latest eval for a slug: candidate digest or `recommend: false`. Does not write Gold. |

Promote stays `procedure.promote` on ProcedureRepo.

Refusals: `prod_write_refused` (promote/eval from PROD),
`bronze_mutated`, `grader_not_deterministic` (LLM judge offered for
a digest task), `n_not_planned`, `platinum_not_a_tier`.

---

## What is actually there

Measured 2026-09-13.

| Thing | State |
|---|---|
| `learn.collect` / `eval` / `recommend` | **none.** |
| ProcedureRepo | **design only.** |
| Deterministic P9 renderer plants | **live** in-process. |
| EvalGrading Wilson/CI machinery | **none** in this repo. Doctrine in the research note. |
| Ornith in MIND | **not v1.** |

---

## Non-goals (v1)

- Ornith task generation, scaffold RL, GRPO, five envelopes
  ([`plan_ornith.md`](plan_ornith.md), v2).
- LLM-as-judge for SHAPE receipts.
- Auto-promote.
- DuckDB.
- Changing GHIS pins from a recommendation.

---

## Open questions (owner)

1. **Where eval runs.** BACKJOB invoking the Ruby renderer in-process
   vs a MIND stub. Recommendation: **BACKJOB in-process** for
   digest tasks; MIND only when the solver is actually an LLM.
2. **Who clicks promote.** SUPERDEV grant vs automatic if
   `recommend: true` and deterministic 100% on the full golden set.
   Recommendation: **grant even then** — coverage is still a human
   call (EvalGrading’s last paragraph).

ProcedureRepo ships Gold without this loop. This loop does not ship
without ProcedureRepo.
