# interfaces/  🟢 OWN IT

Adapters and Rails backends that *implement* the `grammar/` contracts. Owned, but
strictly derivative: these turn the normative spec into running seams.

| Subdir | Purpose | Canonical source |
|---|---|---|
| `rails-cpcp/` | The `/_cpcp` seam — an additive Rails engine projecting resources as CID-grounded JSON-RPC-LD. | `rails-cpcp` |
| `rails-osi-level-8/` | OSI-8 grounding helpers for Rails. | `rails-osi-level-8` |
| `adapters/` | Boundary adapters to upstreams and marketplaces — the only code allowed to touch `upstreams/`. | this repo |

Rule: interfaces derive from contracts. A behavior change starts in `grammar/`,
then lands here.
