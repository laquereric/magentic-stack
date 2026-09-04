# upstreams/  🟡 FOLLOW THEM

Upstream dependencies. **Pinned, never forked.** Nothing here is edited in place
— it is tracked, pinned, and reached only through [`../gems/adapters/`](../gems/adapters/).

| Subdir | Upstream | Source |
|---|---|---|
| `nooa/` | NVIDIA NeMo labs-OO-Agents (NOOA). OS-level isolation required. | <https://github.com/NVIDIA-NeMo/labs-OO-Agents> |
| `nemo-switchyard/` | NVIDIA NeMo Switchyard (pre-alpha; not production-ready). | <https://github.com/NVIDIA-NeMo/Switchyard> |
| `json-rpc-ld/` | laquereric json-rpc-ld (spec only; CPCP profiles it per ADR 0048). Nothing here executes. | <https://github.com/laquereric/json-rpc-ld> |
| `coordination-protocol-contract-package/` | CPCP formats + protocol rules extracted from this monorepo. Reference home, read-only. | <https://github.com/laquereric/coordination-protocol-contract-package> |
| `cpcp_registry/` | laquereric cpcp_registry. Method and seam registries plus PS1 naming and versioning. Indexes the contract; nothing here executes. | <https://github.com/laquereric/cpcp_registry> |
| `manifests/` | Pin records: SBOMs, provenance, patch records, rollback targets. | this repo |

## Follow, do not fork

We follow upstream releases and govern their behavior at *our* seam (`/_cpcp`),
not inside their code. Each pin is advanced or rolled back on evidence, via a
recorded manifest change — never an in-place edit.
