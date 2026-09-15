# docs/

Board-facing, architecture, and operational documentation for The Magentic Stack.

| Path | Contents |
|---|---|
| `architecture/` | System overview, the 14-container MIND Pod, the ownership boundary, the adoption flywheel. |
| `adr/` | Architecture Decision Records. Every boundary move, contract change, or upstream pin bump gets one. |
| `runbooks/` | Operational procedures: pod deploy, pin bump + rollback, evidence export, incident response. |
| `security/` | Security posture, threat model, disclosure policy, boundary/isolation guarantees. |

Start with [`architecture/OVERVIEW.md`](architecture/OVERVIEW.md).

## Comparative analysis

Cloudflare OS (Apache 2.0, August 2026) answers the same question this
stack does — how an agent reaches an enterprise resource without the reach
becoming the vulnerability — from the opposite starting point. Two files,
read in this order:

| Path | Contents |
|---|---|
| [`architecture/CloudflareOs_Contrast.md`](architecture/CloudflareOs_Contrast.md) | The reasoned contrast: where the two systems agree independently, where they structurally diverge, and what each already owns that the other must build. |
| [`architecture/CloudflareOs_3_directions.md`](architecture/CloudflareOs_3_directions.md) | The decision: ignore / make optional / bake in, with the borrow list and the open questions. |

The one thing adopted from that reading is ADR
[0070](adr/0070-never-persist-datasets-and-the-inverted-observer-seam.md).
