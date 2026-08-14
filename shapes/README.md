# SHACL shapes for OSI Level 8 (canonical)

These are the normative, machine-checkable SHACL shapes that constrain the
Level 8 cybernetic interface. They were relocated here from the `json-rpc-ld`
repo so the shapes live with the specification that documents them
(`../docs/osi-level-8-cybernetic-interface.md`, section 8).

## Cyborg Channel shapes (`cyborg-channel/`)

| Shape file | Side | Role |
|---|---|---|
| `envelope.shacl.ttl`           | —       | the never-raise request/response envelope |
| `canonical-record.shacl.ttl`   | Context | the canonical ledger record the Cyborg READS |
| `sync-intent.shacl.ttl`        | Effect  | the allow-listed FRONT→BACK push the Cyborg EMITS |
| `private-local.shacl.ttl`      | —       | the ledger that never leaves |
| `allowlist.template.shacl.ttl` | Effect  | the disclosure allow-list that gates permitted Effect |

Closed shapes make conformance **decidable**: a message either validates or is
refused. **Profile 1** (the vv-graph relational/graph model, section 9) grounds
Context and Effect — every triple on a class or an instance — so they are
machine-checkable under these shapes.
