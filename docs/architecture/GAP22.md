# Gap 22: historical shape_id resolves on read

Resolver only. History is not rewritten. No TTL renamed, no `@prefix`
changed, no catalog IRI touched. No w3id redirect published.

## Census (confirmed)

Emitted:

- `grounding.rb` `Result#shape_id` from the catalog IRI
- `cpcp_adapter.rb:340` `Context#shape_id`
- `cpcp_adapter.rb:473` `AdmissionAttempt#shape_id` (and `report_json`)

Read back across CPCP:

- `Projections.context_list` — `l8.context.list` returned the stored
  `shape_id` unchanged

`mmg-acia` `shape_id` values (`acia:TabShape`) are a different
vocabulary and are not this mapping. No admission-attempt PULL exists.
No `UPDATE` of stored rows.

## What a reader sees

Both. `shape_id` stays the IRI that admitted the row. Alongside it:

| `shape_id_resolution` | `shape_id_resolved` | extra |
|---|---|---|
| `historical` | successor | — |
| `current` | same IRI (already a successor) | — |
| `unresolved` | omitted, not nil | `{ok:false, reason: shape_id_unresolved, because:}` |

The PULL itself stays `{ok:true}`. One unknown row does not fail the
list. An unknown IRI is never treated as resolved.

Cost: additive fields on `l8.context.list`. Existing `shape_id`
consumers keep working. FRONT governance already prints `shape_id`.

## Source

`tooling/shacl/osi_example_successors.json` is the only mapping file.
The resolver loads it. A second copy in the tree fails the gate. The
image COPYs that file to `/opt/magentic/` at rails-base build so BACK
can read it; that is a build artefact, not a second authored table.

## Gate / plants

`check_shape_id_resolver.py`. Plants: empty CHECK_ROOT; second copy of
the JSON; inline successor table in the resolver; `context_list` skips
`ShapeId.resolve`.
