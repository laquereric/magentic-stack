# Gap 68 U5: discovery error is not an empty catalogue

`GraphReplay.storable_models` rescued to `[]`. `[]` is also what an
app with no `triples` declarations returns. `run` then refused
`:no_storable_models` for both, so a discovery fault (eager_load
raised, descendants raised) was reported as "no model declares
triples."

U1, U4, U8 stay observation-only. **U2 `get` stays nil** — a store
that cannot be read yields *not cached* and the effect re-runs, which
is SAFE; a fake receipt is not. Not touched.

## Two reasons, not one

| discovery | `storable_models` | `run` |
|---|---|---|
| raised | `{ok:false, reason: :storable_discovery_failed, because: "Class: message"}` | forwards that reason |
| succeeded, no models | `{ok:true, models: []}` | `{ok:false, reason: :no_storable_models}` — still a replay refusal, honestly empty |
| succeeded, models present | `{ok:true, models: [...]}` | proceeds to emit |

`because` names the exception class on discovery refusal. Never-raise
kept: neither method raises into CPCP `graph.replay`.

Did not run `graph.replay` against the live volume. Gap 94 already
projected the 96 notes through the outbox. This is the contract at
the discovery boundary, not a backfill.

## Gate / plants / spec

`tooling/cpcp/check_graph_replay_discovery.py`. Plants: empty
CHECK_ROOT; restore `rescue -> []`; collapse `run` so it reads
`models` and ignores `ok`. mind-pod `graph_replay_spec.rb`: four
examples, discovery raise vs empty catalogue.

Did not touch idempotency `get`. Did not touch Gemfile.lock.
