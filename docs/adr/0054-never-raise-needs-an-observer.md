---
id: "0054"
title: A never-raise boundary must make its refusals observable
status: accepted
date: 2026-08-31
subject_kind: doctrine
subject: never-raise refusals
components: [rails-cpcp, rails-osi-level-8, vv-graph, backjob]
paths:
  - gems
  - runtimes
enforced_by: []
supersedes: null
superseded_by: null
---

# Never-raise needs an observer

## The rule

**A never-raise boundary must make its refusals observable by something other
than a human reading output.** Returning `{ok: false, reason:, because:}` or
`:error` and printing it is not observation. If the only way to notice is for
someone to be watching stdout at the time, the refusal is not observed.

The never-raise envelope itself is **not** the defect and is not being changed.
A boundary that raises into its caller is worse. The defect is that we built
the half that says "no" carefully and never built the half that listens.

## Why: three instances in one day, each found by accident

| | Boundary | What it returned | How it was found |
|---|---|---|---|
| 1 | `backjob` → BACK's CPCP seam | `{ok:false, reason:"backjob_cpcp_error"}`, printed | I read the compose file for an unrelated reason. The completion path had been dead **for weeks**. |
| 2 | P6 admission | nothing — the column could not express a denial | grok read the code while writing a protocol document |
| 3 | `Publisher::Immediate#schedule` | `:error`, discarded | grok read the code while investigating an empty graph |

None was found by the system. Each was found because a person happened to be
looking somewhere nearby. That is the pattern, and it is why this is doctrine
rather than three bug fixes.

## The distinction that decides the design

There are **45** `rescue StandardError` sites in our Ruby. They are not the same
kind of thing, and treating them alike would replace silence with noise — which
fails the same way, just louder.

| | Meaning | Needs an observer |
|---|---|---|
| **Refusal** | a boundary told a caller **no**; a decision was made and the caller may need to act | **yes** |
| **Fallback** | internal code chose a default; no caller decision is implied (e.g. `app_name` rescuing to a literal) | no |

Only refusals are in scope. A census that classifies all 45 comes **before** any
mechanism — the same discipline that made ADR 0052 work, where counting first
turned a migration into a decision.

## What "observable" must mean

Not specified here beyond the floor:

- something **other than a human reading logs** can see it — a gate, a health
  surface, or a durable record;
- it survives the process that produced it, or is aggregated somewhere that
  does;
- and a refusal that has never been seen is distinguishable from no refusal
  having occurred. **Absence of evidence must not read as evidence of absence**
  — the same rule ADR 0052 reached for `indeterminate`.

The journal is the obvious candidate for refusals that have an operation
context; it is append-only and already carries a `refused` kind. Refusals with
no operation context need somewhere else. Deciding that is the next step, not
this one.

## Scope

Ruby first. MIND is Python and SwitchYard will be Rust; whatever this becomes
has to cross those boundaries eventually, and a mechanism that cannot is the
wrong one. But it is not solved for three languages before it is solved for
one.
