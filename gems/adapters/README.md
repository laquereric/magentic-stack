# gems/adapters/  🟢 OWN IT

Boundary adapters. This is the **only** code permitted to reach into `upstreams/`.
Each adapter wraps a pinned upstream (NOOA, NeMo Switchyard) or a marketplace and
exposes it through the owned OSI-8 / CPCP contracts.

- Upstreams are pinned, never forked — see [`../../upstreams/`](../../upstreams/).
- An adapter carries a pin matrix and integration tests so a pin can advance or
  roll back on evidence.
