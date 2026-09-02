# Gap 69: split outbox causes, then fail closed

`ensure_schema!` returned `true` if the table existed or if
`create_table` just succeeded, and `false` for every other failure.
`outbox_ready?` then called `ensure_schema!` and Immediate **drained
anyway** when that was false (`job = nil`). Missing table and a
raised schema check were one boolean, and a missing table still
projected without durability.

## What Immediate does now

`ProjectionJob.schema_status` → `:available` | `:missing` |
`:check_failed`.

`Immediate#schedule` / `drain_pending!` refuse when not `:available`.
They do **not** call `ensure_schema!`. Reasons:

- `outbox_not_installed`
- `outbox_schema_check_failed`

Each carries a restoration object (gap 74 four keys). Return `:error`
/ `{ok: false}`. GRAPH is not updated on that path.

`ensure_schema!` remains for **specs**. `enqueue!` no longer
`create_table`s. Live `:requires_extension` examples install via
`spec_helper`.

## Honest fix for production "missing"

A lazy runtime `create_table` is the out-of-band table: it exists in
no app migration and no `schema.rb`. Gap 94 measured that as the
default of the live volume. The honest install is the gem migration
copied into the host app and `db:migrate`. **Not done this turn** —
schema changes are the owner's call; an out-of-band table breaks
`db:migrate` later. Until that lands, a save refuses projection
instead of inventing a table.

## Gate / plants / suite

`tooling/cpcp/check_outbox_schema.py`. Plants: empty CHECK_ROOT;
drop `schema_status`; plant `ensure_schema!` back into Immediate.
`bundle exec rspec` in `gems/vv-graph`: 341 examples, 0 failures
(3 pending engine-limited annotation DELETEs, pre-existing).
Did not touch Gemfile.lock.
