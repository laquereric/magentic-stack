# Gap 63 step 1 — census of `rescue StandardError`

Measured 2026-08-31 from `15b6802`. Census only. No mechanism.

ADR [0054](../adr/0054-never-raise-needs-an-observer.md): a never-raise
boundary must make its refusals observable by something other than a
human reading output. Classify first; design second.

## How many

Claude counted **45** after writing the ADR. `rg --type ruby` on
`gems/` + `runtimes/`, excluding `vendor/` and `spec/`, is **45**.

That search misses extensionless Ruby. Same shape as the journal-index
under-match (gap 56). Two more live sites sit in
`runtimes/mind-pod/app/bin/backjob` — **instance 1 of the ADR**. One
more in `gems/vv-graph/bin/vv-graph-pattern` (tooling). Docs hits
ignored.

| Population | N |
|---|---:|
| Claude's 45 (`.rb` in gems + runtimes) | 45 |
| `bin/backjob` (no suffix) | +2 |
| `vv-graph/bin/vv-graph-pattern` | +1 |
| **This census** | **48** |

The 45 are all here. The extra three are named so the denominator is
not a search artifact.

## Legend

| Kind | Meaning |
|---|---|
| **REFUSAL** | a boundary told a caller no; the caller may need to act |
| **FALLBACK** | internal code chose a default; no caller decision |
| **UNCLEAR** | not forced. Usually: failure is indistinguishable from the empty/negative answer |

**Observed (today)** — what actually happens to the value, not what
ADR 0054 would require:

| Token | Means |
|---|---|
| printed | stdout / `puts` / `warn` |
| logged | `Rails.logger` |
| returned-wire | on a CPCP / never-raise envelope a caller *could* inspect |
| returned-discarded | caller ignores it (redirect, `nil`, continues) |
| counted | folded into a hash that is itself returned |
| none | discarded at the rescue; not even returned |

**ADR floor?** gate, health surface, or durable record. Printed,
logged, and returned-wire **do not** meet it (0054 §Why, §What
observable must mean). Journalled would. None of these rescues
journal.

---

## FALLBACK (12)

Internal default. No caller decision.

| # | Site | What it becomes | Why fallback |
|---:|---|---|---|
| F1 | `rails-cpcp/.../rpc_controller.rb:35` `app_name` | `"rails-cpcp"` | ADR's example |
| F2 | `vv-graph/.../storable.rb:267` | `nil`, skip annotation | optional value lambda |
| F3 | `vv-graph/.../storable.rb:331` | ignore | best-effort retract of annotations |
| F4 | `vv-graph/.../storable.rb:516` | ignore | same, orphan annotations |
| F5 | `vv-graph/.../publisher/immediate.rb:138` `capture_subject_context` | `[nil, nil]` | optional IRI stash for later retract |
| F6 | `rails-osi-level-8/.../profile9/graph.rb:125` `ar_enabled?` | `false` | capability probe |
| F7 | `rails-osi-level-8/.../profile11/store.rb:319` `ar_enabled?` | `false` | capability probe |
| F8 | `vv-graph/.../projection_job.rb:39` `available?` | `false` | capability probe |
| F9 | `vv-graph/.../publisher/immediate.rb:75` `outbox_ready?` | `false` | capability probe (schema missing) |
| F10 | `rails-cpcp/.../cid.rb:33` `digest` | `nil` | `/up` `cid_digest` may be null; cosmetic |
| F11 | `vv-graph/bin/vv-graph-pattern:218` `source_text` | `nil` | tooling, source slice failed |

---

## UNCLEAR (8)

Failure and the empty/negative answer are the same value. This is the
`indeterminate` shape: absence of evidence reads as evidence of absence.

| # | Site | Returns on error | Also the success-negative |
|---:|---|---|---|
| U1 | `vv-blob/.../store.rb:142` `has?` | `false` | blob does not exist |
| U2 | `rails-cpcp/.../idempotency.rb:59` `get` | `nil` | cache miss → replay will re-execute |
| U3 | `mmg-adr/.../document.rb:41` YAML | `{}` | empty frontmatter. The *next* line refuses non-Hash; `{}` *is* a Hash, so a corrupt `---` block becomes an empty document, not `unparsable_frontmatter` |
| U4 | `profile11/store.rb:377` `persist_artifact_ar!` | `nil` | "nothing to persist" / persist skipped |
| U5 | `graph_replay.rb:31` `storable_models` | `[]` | "no Storable models" → `run` then refuses `:no_storable_models`. Discovery *error* looks like an empty catalog |
| U6 | `projection_job.rb:66` `ensure_schema!` | `false` | "outbox not installed" (then projection proceeds without durability) |
| U7 | `idempotency.rb:72` `put` | the `value`, as if stored | success. Failure of the idempotency store is reported as a successful put |
| U8 | `cpcp_adapter.rb:475` `record_refusal!` | swallowed after `warn_log` | the *admission* refusal already happened; this is the observer failing. Logged. The original no still proceeds |

U7 is the most loaded: a put that fails still hands the caller the
body they asked to store. Classifying it REFUSAL would be fair; it
stays UNCLEAR because the method's contract has no `ok` channel — the
caller cannot act even if they wanted to.

U8 is the observer of a refusal failing. Not a second caller-facing
no. Logged only.

---

## REFUSAL (29)

A decision was made. The caller may need to act. **ADR floor: none of
these.**

### A. Returned on a never-raise envelope (16)

Someone *could* inspect `ok`/`reason`. Nothing durable watches.

| # | Site | Returns | Observed today |
|---:|---|---|---|
| R1 | `vv-blob/store.rb:57` `open` | `Refusal` `:store_unavailable` | returned-wire (memoized by `Mmg::Blob::Operations.store`; a later `put` would then explode rather than refuse — not checked at open) |
| R2 | `store.rb:112` write | `refuse :write_failed` | returned-wire (`Operations.put` forwards) |
| R3 | `store.rb:124` entries | `refuse :read_failed` | returned-wire |
| R4 | `store.rb:136` get | `refuse :read_failed` | returned-wire (`Operations.get` checks `res[:ok]`) |
| R5 | `store.rb:169` delete | `refuse :delete_failed` | returned-wire |
| R6 | `store.rb:175` count | `refuse :read_failed` | returned-wire |
| R7 | `store.rb:182` digests | `refuse :read_failed` | returned-wire |
| R8 | `store.rb:189` close | `refuse :close_failed` | returned-wire |
| R9 | `mmg-adr/ingest.rb:67` | `{ok:false, :ingest_error}` | returned-wire |
| R10 | `profile9/projection.rb:149` | `refuse :projection_failed` | returned-wire |
| R11 | `mmg-graph/cpcp.rb:129` publish | `refuse :publish_failed` | returned-wire (CPCP `graph.publish` / `session.observe`) |
| R12 | `mmg-graph/cpcp.rb:140` entries | `refuse :read_failed` | returned-wire |
| R13 | `session_cycle.rb:28` open | `refuse :open_failed` | returned-wire (CPCP); MIND checks `ok` |
| R14 | `session_cycle.rb:47` latest | `refuse :latest_failed` | returned-wire; MIND checks |
| R15 | `session_cycle.rb:79` context | `refuse :context_failed` | returned-wire; MIND `mind_waiting` |
| R16 | `session_cycle.rb:123` observe | `refuse :observe_failed` | returned-wire; MIND checks `committed_by_back` |
| R17 | `session_cycle.rb:134` close | `refuse :close_failed` | returned-wire |
| R18 | `graph_replay.rb:69` `run` | `{ok:false, :replay_failed}` | returned-wire (CPCP `graph.replay`) |
| R19 | `graph_replay.rb:58` per-row | counted in `failed`, `Rails.logger.warn` | logged + counted into R18 |
| R20 | `publisher/immediate.rb:64` `drain_pending!` | `{ok:false, errors:1}` | returned-wire; **who calls `drain_pending!` in the pod? specs and `Vv::Graph.drain_pending!`. No cron, no BACKJOB sweep found.** |
| R21 | `publisher/immediate.rb:60` per-job in drain | `errors += 1` | counted into R20 |
| R22 | `back_cpcp_client.rb:28` | `{ok:false, back_unavailable}` | returned-wire; `GovernanceController` checks `ok`; `HomeController#index` `dig`s and treats failure as empty list |

R13–R17 go through `CpcpAdapter.wrap`. A `refuse` **hash** is a handler
return, not a `KnownRefusal`, so it does **not** take the journalled
P6/admission path. It is a result body. MIND inspecting `ok` is the
only current listener, and MIND is a process that exits its tick.

### B. Discarded or printed (the three the ADR named, and neighbours)

| # | Site | Returns | Observed today | ADR instance |
|---:|---|---|---|---|
| R23 | `publisher/immediate.rb:42` `schedule` | `:error` | **none.** `Note.create!` still commits (gap 7) | **#3** |
| R24 | `bin/backjob:30` `cpcp_push` | `{ok:false, backjob_cpcp_error}` | printed (`puts ok=`) | **#1** |
| R25 | `bin/backjob:62` loop | printed `error: Class: message` | printed | neighbour of #1 |
| R26 | `cpcp_adapter.rb:95` handler | `warn_log` then `raise KnownRefusal processing_failed` | logged; then CPCP envelope. **This one can be journalled** if the wrap's refusal path records before re-raise — `record_refusal!` is that path, and *it* is U8 | closest to journalled; U8 can swallow the record |
| R27 | `home_controller.rb:11` index | `@error` string, empty `@notes` | rendered on the FRONT page. Human looking at `:13000` | — |
| R28 | `home_controller.rb:20` create | `redirect_to root_path` | **none.** A failed `note.create` looks like success | — |
| R29 | `idempotency.rb:49` schema/open | `@db = nil` after `warn(...)` | printed (`warn`). Subsequent get/put become U2/U7 | — |

R23 is the empty-graph mechanism. R24 is the dead completion path.
R28 is FRONT swallowing a write refusal into a 302.

---

## Rollup

| Kind | N | ADR floor (gate / health / durable) |
|---|---:|---|
| FALLBACK | 11 | n/a |
| UNCLEAR | 8 | n/a (several *hide* a refusal as empty) |
| REFUSAL | 29 | **0** |
| **total** | **48** | |

Of the 29 refusals:

| Observed today | N | Meets 0054 floor? |
|---|---:|---|
| none (discarded / `:error` / redirect) | 2 (R23, R28) | no |
| printed only | 3 (R24, R25, R29) | no |
| logged (+ maybe returned) | 2 (R19, R26) | no |
| returned-wire, caller-dependent | 22 | no |
| journalled | 0 (R26 tries; U8 can drop it) | no |

**Returned-wire is the bulk and is not observation.** 0054: "Returning
`{ok: false, reason:, because:}` or `:error` and printing it is not
observation." Most of this system is that bulk.

The UNCLEAR eight are the ones a mechanism can get wrong: if you
observe only explicit `refuse(...)` you will miss `has? → false`,
`idempotency.get → nil`, `put` that "succeeded", YAML `{}`. Those are
the silent class 0052 named `indeterminate`.

## What this census does not decide

Mechanism is step 2. Not this branch.

Facts a later mechanism has to live with, not answers:

- 11 sites must not become noise (FALLBACK).
- 8 sites have no `ok` channel; observing them means changing the
  contract or wrapping them.
- 22 "returned-wire" refusals already have a shape a gate *could*
  scrape; nothing does.
- 2 sites (R23 `:error`, R28 redirect) have no envelope to scrape.
- Refusals with an operation context (R13–R17, R26, blob via CPCP)
  could journal. Refusals with none (R23 publisher, R24 backjob if
  BACK is down, R29 idempotency store, blob `open` at boot) are the
  interesting remainder 0054 already flagged.

Ruby only, as briefed.
