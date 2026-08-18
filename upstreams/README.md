# upstreams/  🟡 FOLLOW THEM

Upstream dependencies. **Pinned, never forked.** Nothing here is edited in place
— it is tracked, pinned, and reached only through [`../interfaces/adapters/`](../interfaces/adapters/).

| Subdir | Upstream | Source |
|---|---|---|
| `nooa/` | NVIDIA NeMo labs-OO-Agents (NOOA). OS-level isolation required. | <https://github.com/NVIDIA-NeMo/labs-OO-Agents> |
| `nemo-switchyard/` | NVIDIA NeMo Switchyard (pre-alpha; not production-ready). | <https://github.com/NVIDIA-NeMo/Switchyard> |
| `manifests/` | Pin records: SBOMs, provenance, patch records, rollback targets. | this repo |

## Follow, do not fork

We follow upstream releases and govern their behavior at *our* seam (`/_cpcp`),
not inside their code. Each pin is advanced or rolled back on evidence, via a
recorded manifest change — never an in-place edit.
