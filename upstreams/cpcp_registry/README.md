# upstreams/cpcp_registry/  🟡 FOLLOW THEM

Pinned **laquereric cpcp_registry** — the machine-readable index of the CPCP
contract: which methods exist, which seams serve them, under what names and
versions.

- **Source:** <https://github.com/laquereric/cpcp_registry>
- **Source (submodule):** `src/` — pinned at 30975ba (branch main), read-only.
- **Pin record:** [`../manifests/cpcp_registry.pin.json`](../manifests/cpcp_registry.pin.json)
- **Relationship:** indexes the contract in
  [`../coordination-protocol-contract-package/`](../coordination-protocol-contract-package/).
  Drift between a registry entry and the contract spec is a bug against the
  registry, not against this monorepo.
- Nothing here executes in the pod. Registry entries are read as data.
- Do not fork. Advance the pin via a recorded manifest update with a rollback
  target.
