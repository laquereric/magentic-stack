# vv-perch

Private Rails engine. **Schema only.** Relational grounding for Perch v2:
the sized slice, the freeze ladder, the orphan ledger, the outward
signal, the wholeness finding.

Not on rubygems.org. No XML importer, no service objects, no HTTP, no
Effect Gate, no Effect Ledger, no signatures, no ranking. The CPCP
seam lives in the host (`perch_seam.rb` on BACK), not here — same
split as `vv-bpmn-bbo`.

Design: [`docs/architecture/plan_vv-perch.md`](../../docs/architecture/plan_vv-perch.md).

## What it holds

Fifteen tables, prefix `perch_`. Throughput is **released slices**,
and the schema makes counting released methods unavailable: there is
no delivery boolean on `perch_methods`.

## Four refusals (load-bearing)

| | Forbidden | Grounding |
|---|---|---|
| R1 | Effect Gate / executor / credential | `perch_effect_bindings` has `effect_ref` and a principal. No executor column. |
| R2 | Effect Ledger | cites `uc_id` / `slice_key`; stores no proposals, decisions, executions |
| R3 | signatures | no column named `jws`, `signature`, `token`, `secret`, `credential` |
| R4 | ranking | `rank_together` is a constraint; no `position`, `priority`, `rank` |

## Install

Path gem in magentic-stack (ADR 0038):

```ruby
gem "vv-perch", path: "gems/vv-perch"
```

Host runs the engine migrations. vv-base is **not** a runtime
dependency: `receiver_id` is an integer whose `class_name` is
`"Vv::Base::Actor"`. The gem has no minter for actors — that is T1.

Owner calls (2026-09-15): `by_receiver` is in-governance; no draft
namespace yet; NOOA is pinned never forked; default placement is
`canonical`. The CPCP face is `runtimes/mind-pod/app/lib/perch_seam.rb`.
