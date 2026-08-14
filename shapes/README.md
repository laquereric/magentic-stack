# SHACL shapes for OSI Level 8

The interface is *verifiable*: messages crossing it are constrained by closed
SHACL shapes. The canonical **Cyborg Channel** shapes live in the `json-rpc-ld`
spec repo under `shapes/cyborg-channel/`:

- `envelope.shacl.ttl`         — the never-raise request/response envelope
- `canonical-record.shacl.ttl` — the pulled canonical ledger record
- `sync-intent.shacl.ttl`      — the allow-listed FRONT→BACK push
- `private-local.shacl.ttl`    — the ledger that never leaves
- `allowlist.template.shacl.ttl` — the disclosure allow-list template

The Level 8 specification (see `../docs/`) documents how these shapes type the
**Context** side (what the Cyborg reads) and the **Effect** side (what the
Cyborg does), and how **Profile 1** (the vv-graph relational/graph model)
satisfies them with every triple grounded on a class or an instance.
