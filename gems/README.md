# gems/  ð¢ OWN IT

Adapters and Rails backends that *implement* the `grammar/` contracts. Owned, but
strictly derivative: these turn the normative spec into running seams.

| Subdir | Purpose | Canonical source |
|---|---|---|
| `rails-cpcp/` | The `/_cpcp` seam â an additive Rails engine projecting resources as CID-grounded JSON-RPC-LD. | `rails-cpcp` |
| `rails-osi-level-8/` | OSI-8 grounding helpers for Rails. | `rails-osi-level-8` |
| `adapters/` | Boundary adapters to upstreams and marketplaces â the only code allowed to touch `upstreams/`. | this repo |

Rule: interfaces derive from contracts. A behavior change starts in `grammar/`,
then lands here.

## Vendored source

- `rails-cpcp/` is vendored in via **git subtree** (ADR 0002) â the real `/_cpcp`
  seam engine (dispatcher, envelope, CID registry, idempotency) plus its FRONT
  accessory and RSpec suite. **Gate 1** (boundary conformance) runs those specs as
  its BACK-seam contract check (fail-closed / never-raise / operationId-required).
- `rails-osi-level-8/` is vendored in via **git subtree** (ADR 0002) — OSI-8 grounding helpers for Rails.
