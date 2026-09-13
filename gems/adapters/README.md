# gems/adapters/  🟢 OWN IT

Boundary adapters. This is the **only** code permitted to reach into `upstreams/`.
Each adapter wraps a pinned upstream (NOOA, NeMo Switchyard) or a marketplace and
exposes it through the owned OSI-8 / CPCP contracts.

- Upstreams are pinned, never forked — see [`../../upstreams/`](../../upstreams/).
- An adapter carries a pin matrix and integration tests so a pin can advance or
  roll back on evidence.
- [`nemo-switchyard/`](nemo-switchyard/) wraps the NVIDIA Switchyard pin
  (content-blind algorithms, env injection, 4000→8789 reverse-front).
- [`monty/`](monty/) wraps pydantic/monty as the CodeAct isolation
  seam (ADR 0070). `run()` never falls back to CPython. MIND intercepts
  `execute_python` and does not call `nxt`.
- [`genai-prices/`](genai-prices/) overlays INDICATIVE `in`/`out` onto
  the ROLE=config catalog from the pinned `data_slim.json`. Not a
  second table.
