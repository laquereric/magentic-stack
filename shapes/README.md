# SHACL shapes for OSI Level 8

The Level 8 interface is constrained by closed, machine-checkable SHACL shapes.
Shapes are organized per profile (see the base spec `../docs/osi-level-8-base.md`,
section 8 "Interface Contracts" and section 9 "Profiles"). A conforming deployment
declares exactly one profile.

## Profile 1 (`profile-1/`)

The Cyborg Channel shapes for **Profile 1** — the vv-graph relational/graph model
(`../docs/osi-level-8-profile-1-vv-graph.md`).

| Shape file | Side | Role |
|---|---|---|
| `envelope.shacl.ttl`           | —       | the never-raise request/response envelope |
| `canonical-record.shacl.ttl`   | Context | the canonical ledger record the Cyborg READS |
| `sync-intent.shacl.ttl`        | Effect  | the allow-listed FRONT→BACK push the Cyborg EMITS |
| `private-local.shacl.ttl`      | —       | the ledger that never leaves |
| `allowlist.template.shacl.ttl` | Effect  | the disclosure allow-list that gates permitted Effect |

## Profile 2 (`profile-2/`)

The shapes for **Profile 2** — reference-passing for agents
(`../docs/osi-level-8-profile-2-nooa.md`). Profile 2 is seeded with **copies of the
same shape files** as Profile 1: it inherits the same envelope, canonical-record,
sync-intent, private-local, and allow-list contracts as a starting point, and may
specialize them for Profile 2's API-surface, bounded-preview, and typed-Effect
semantics.

Closed shapes make conformance **decidable**: a message either validates or is refused.
