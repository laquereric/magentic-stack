# Ornith — v2 solver loop (GRPO + five envelopes)

> ## CONTRACT GEM 2026-09-13 — `gems/vv-orinth`
>
> Five envelopes + declared GRPO + `V1Binding` that refuses until
> v1 plants exist. **Does not train. Does not promote Gold.**

**Design only for MIND weights. Not v1.**

v1 is ProcedureRepo + SelfLearn: Gold → PROD → Bronze collection →
Gold recommendations. No Ornith, no GRPO, no five envelopes
([`plan_self_learn.md`](plan_self_learn.md) non-goals).

This file is what starts **after** those plants are green. It does
not reopen v1. It does not auto-promote. It does not make Platinum
a Build tier.

Store remains ProcedureRepo (BACK AR + `vv-blob`). DuckDB deferred.

Sources: Ornith-1.0 / 1.5 at
`magentic-market-ai/docs/research/Orinth1.md`, `Ornith2.md`,
`Ornith3.md`; Lu et al. *Procedural Graphs*; EvalGrading (still
the promote bar); ADR
[0047](../adr/0047-three-languages-container-boundaries-own-images.md),
[0056](../adr/0056-back-and-backjob-are-the-writers.md),
[0057](../adr/0057-three-kinds-of-state.md).

The sentence:

> Ornith proposes tasks, scaffolds, and rollouts, and may GRPO its
> **MIND policy**. Gold still moves only through SelfLearn eval +
> grant. Five observed envelopes are Bronze, not a new Gold.

---

## What this is not

- v1. If `learn.collect` / `learn.eval` / `learn.recommend` are
  not plants, this plan is idle (`ornith_v1_required`).
- A second catalog. No `ornith_procedures` table. Revisions land
  on ProcedureRepo slugs.
- Auto-promote because GRPO loss dropped. EvalGrading still
  applies: planned N, Wilson CI, coverage, grant.
- FRONT eval. Python stays in MIND.
- DuckDB.
- Editing the verifier, the golden set, or the CPCP allowlist
  from inside a scaffold (Ornith outer trust boundary).

---

## Blocked until

| Plant | Plan |
|---|---|
| `procedure.serve` Gold for `shape.render.ghis-19` | ProcedureRepo |
| `learn.collect` from PROD, `learn.eval` envelope with N + Wilson, `learn.recommend` | SelfLearn v1 |
| Deterministic grader on the SHAPE golden set | SelfLearn v1 |

Until those exist, a stub that “emits five JSON files” is not this
product.

---

## The split v1 already named

```
v1  Gold ──PROD──► Bronze collect ──eval──► recommend ──grant──► Gold

v2  MIND Ornith ──five envelopes──► Bronze (typed)
         │
         └── GRPO ──► MIND policy checkpoint   (not Gold, not AR)
         │
         └── candidate binding / ΔG ──► learn.eval (v1) ──► recommend
```

GRPO updates **ephemeral inference state** (ADR 0057): a policy
blob MIND may reload. It is Operate, not a fourth medallion tier.
A weight file has no tombstone; it is dropped and rebuilt from
Silver/Bronze, never patched in place, and never cited as Gold.

---

## Five envelopes (observed Bronze)

One Ornith cycle files five **observed** blobs (`generation: 0`,
parentless except cites). Summarising them into one “trace
summary” on ingest is `bronze_mutated`. v1 `learn.collect` remains
the generic PROD path; these are the **typed DEV/MIND** path.

| Envelope | Bytes | Cites |
|---|---|---|
| `ornith.task` | proposed question / kind / claimed LinkML-in | optional `gold_digest` |
| `ornith.scaffold` | instructions, tools, decomposition, orchestration (inner policy) | task digest |
| `ornith.rollout` | trajectory T = (action, observation)*, CPCP ids | task + scaffold |
| `ornith.reward` | `{ validity, frontier, novelty, harness_align, harness_fidelity, harness_hack_resist, rollout_score }` | rollout |
| `ornith.monitor` | fired? path / tool / verifier-edit | rollout; score forced 0 if fired |

Reward fields are Ornith-1.5’s three stages, stored as numbers,
not as doctrine constants:

- **Task:** validity × frontier × novelty. Validity may hard-gate.
  Frontier uses empirical success rate vs a *recorded* target
  (Ornith publishes 0.2; we store the target, we do not freeze it
  here). Novelty vs prior task digests (exact + LinkML-in hash;
  embeddings wait on `rag_write_undecided`).
- **Harness / scaffold:** align, fidelity, hack-resist.
- **Rollout:** harness score (binary for SHAPE digest tasks).

Monitor hits still land. Throwing them away is how you cannot
audit the cheat. They are excluded from GRPO advantage, not from
Bronze.

---

## GRPO (MIND only)

Ornith-1.0: two-stage generate (scaffold then rollout), token-level
Group Relative Policy Optimization, staleness weighting on long
rollouts. Ornith-1.5: the same objective on task proposer,
scaffold, and rollout jointly.

| Rule | Why |
|---|---|
| Runs in MIND (Python) | ADR 0047 |
| Writes a policy checkpoint MIND owns | not BACK AR, not Gold |
| Reads Bronze envelopes + current Gold PG neighborhood | frozen Gold online |
| Must not write `procedure.promote` | SelfLearn eval is the bar |
| Outer trust boundary immutable | tool surface, golden set, plants, CPCP allowlist |
| Trajectories that trip `ornith.monitor` get advantage 0 | still stored |

A GRPO step that needs BACK is `ornith.reward` already landed plus
optional `learn.eval` on a candidate — never a silent Gold swap.

---

## How this feeds SelfLearn

1. Cycle emits five envelopes → Bronze (this plan).
2. Optional: a candidate binding or PG ΔG blob (inferred Bronze,
   parent = rollout digest).
3. `learn.eval` (v1) on the golden set + collected PROD Bronze.
   Planned N. Wilson CI. Deterministic grader for SHAPE.
4. `learn.recommend` (v1).
5. Grant → `procedure.promote`.

If the SHAPE family is already bit-identical Gold, success rate →
1.0 and frontier reward collapses. The proposer must move
(adjacent kind, new fixture, ghis-20 date path). That is curriculum,
not a reason to mutate a working renderer. EvalGrading coverage
still wins over more repeats of four easy cases.

---

## CPCP (v2, additive)

v1 methods stay. These are extra, DEV-gated except where noted.
`operationId` on writes. Never-raise.

| Method | Direction | Does |
|---|---|---|
| `ornith.task.put` | push | Envelope 1 |
| `ornith.scaffold.put` | push | Envelope 2 |
| `ornith.rollout.put` | push | Envelope 3 |
| `ornith.reward.put` | push | Envelope 4 |
| `ornith.monitor.put` | push | Envelope 5; may fire from the boundary process, not the model |
| `ornith.cycle.put` | push | All five in one operationId (convenience; still five blobs) |
| `ornith.grpo` | push | MIND-only: run one GRPO step against landed envelopes. Returns policy digest. Does not promote. |

PROD may still `learn.collect` (v1). PROD may not `ornith.*.put`
or `ornith.grpo` (`prod_write_refused`). Capture of PROD traffic
stays the generic Bronze path so a live Ornith in PROD cannot
rewrite its own curriculum from production.

Refusals: `ornith_v1_required`, `prod_write_refused`,
`bronze_mutated`, `verifier_edit_refused`, `platinum_not_a_tier`,
`grpo_without_envelopes`, plus SelfLearn/ProcedureRepo sets.

---

## Who runs what

| Piece | Where | Language |
|---|---|---|
| Ornith (9B first; 35B if hardware) | MIND | Python |
| Five envelope puts | MIND → BACK | CPCP |
| GRPO | MIND | Python |
| Policy checkpoint | MIND volume (ephemeral kind) | — |
| Eval / recommend / promote | BACKJOB + grant | Rails, v1 |

Stub solver is **not** this plan. v1 already said a stub is enough
to plant collect. Ornith is the named v2 solver.

---

## What is actually there

Measured 2026-09-13.

| Thing | State |
|---|---|
| This CPCP surface | **none.** |
| Ornith weights in the pod | **none.** Research notes only. MIT, Hugging Face `deepreinforce-ai`. |
| ProcedureRepo / SelfLearn v1 | **design only.** This plan is blocked on their plants. |
| GRPO in-repo | **none.** |

---

## Non-goals

- Shipping this in the same cut as `learn.collect`.
- Ornith-397B as a requirement (9B edge / 35B A3B is the local
  workhorse in the notes).
- LLM-as-judge for SHAPE receipts (still digest).
- Auto-promote from GRPO.
- Replacing SelfLearn’s three methods.

---

## Open questions (owner)

1. **When to pin a weight.** After v1 plants, Ornith-9B vs wait for
   independent SWE-Bench confirmation (Ornith3 notes skepticism).
   Recommendation: pin 9B for capture + GRPO plumbing; do not claim
   benchmark numbers we did not measure.
2. **Policy blob vs Platinum.** Keep the checkpoint off ProcedureRepo
   Gold. If we ever *cite* it from AR, it is Operate (`memory.distill`
   is already blocked on M5/M9) — not a procedure slug.

v1 does not implement this file. This file does not ship without v1.
