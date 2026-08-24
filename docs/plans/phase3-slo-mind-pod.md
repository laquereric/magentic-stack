# Phase 3 — one SLO for mind-pod (blocked)

Status: **blocked**. Machine envelope:
[`phase3-slo-mind-pod.json`](phase3-slo-mind-pod.json).
Driver: [`phase2-3-mind-pod.rb`](phase2-3-mind-pod.rb).
Branch: `grok/phase2-3-mind-pod` (worktree `/tmp/mm-wt/magentic-stack-phase23`).

No telemetry was added to mind-pod. The objective was not weakened to match
the healthcheck.

## Objective (one thing, with a number)

**mind-pod BACK answers `GET /up` successfully for 99% of probes in any 1h
window.**

| Field | Value |
|---|---|
| service | `mind-pod` |
| target | `0.99` |
| window | `1h` |
| error budget | `0.01` → **0.6 minutes** (36s) |
| good | `sum(mind_pod_probe_success{role="back",path="/up"})` |
| total | `sum(mind_pod_probe_total{role="back",path="/up"})` |

`Objective.validate` → `{ ok: true, … }`. The spec is well-formed. The
queries name metrics that **do not exist**.

Why this bar, and not FRONT, MIND, or switch: BACK is the sole writer and
the `/_cpcp` seam. If BACK is unready, the pod is not working. Why 1h not
30d: this is a local demo; we have no production window to defend. Why 99%
not 99.9%: 36s in an hour is already something I would page on at 3am for a
dev pod; 43 minutes a month would be theatre.

## ObservabilityContract

| Field | Value |
|---|---|
| owner | `runtimes/mind-pod` |
| environment | `demo` |
| required attributes | `role`, `path`, `probe_id`, `status_class` |

`contract.validate` (identity) → ok. `check_signal` against what the demo
**actually** emits — compose healthcheck, `GET /up`, HTTP code only,
attributes `{}` — → `{ ok: false, reason: :required_attribute_missing,
because: [role, path, probe_id, status_class] }`.

There is no Prometheus (or other) scrape. `/_cpcp/up` is a JSON liveness
document listing operations; it is not a ratio metric. Inventing an exporter
so the contract would pass would be the reverse-engineered SLO the brief
forbade.

## BurnRate / BudgetGate

No observed error rate → no burn → no `remaining` fraction.

`BudgetGate.evaluate(remaining: nil, actor: :agent)` →
`{ ok: false, reason: :remaining_invalid }`.

The gate **cannot decide**. Treating “nothing paged” as a healthy budget
would let an agent activate a candidate with no measurement. That is a pass
wearing a gate’s clothes. Activation is **blocked**.

## Runbook (when it fires)

Rung **1** (prose). `rehearsable?` → false. Honest: there is no script.

When BACK `/up` is not 200:

1. `docker compose -f runtimes/mind-pod/app/extract/compose.yml ps` — is
   `back` running?
2. Do **not** `docker commit`.
3. Do **not** reinstantiate a prior image onto the live `mind-data` volume
   and call it rollback (Phase 2).

| Act | `hitl_required?` |
|---|---|
| Restart the BACK container (`irreversible`, `negligible`) | **false** — contained; log and proceed |
| Activate a materialization while `mind-data` is attached (`irreversible`, `service`) | **true** — HITL |

## Verdict

**Blocked.** The Objective is a spec of a metric nobody emits. The contract
refuses the only existing probe. The gate has no remaining to read.

Do not activate a candidate against this SLO until a probe actually produces
`mind_pod_probe_{success,total}` with the required attributes. That emitter
is future work, not this phase.

## What the plan got wrong

The plan said phase 3 “will be embarrassing in its modesty.” The modest
objective **validates**. The block is one layer down: observability, not
ambition. If we had emptied `good_query` to get `:unqueryable`, that would
have been weakening the objective to match the tool. We did not.

## Disagreement with Phase 2 (loud)

Phase 3’s “working” is BACK `/up`. Phase 2’s live system is a SQLite volume
that `/up` does not name. A green Phase 3 probe can coincide with C1–C9
failure. Joining them in Phase 4 without a volume closure **and** a real
probe will glue two different facts into one Release Packet.
