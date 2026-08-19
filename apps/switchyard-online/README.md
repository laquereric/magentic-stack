# apps/switchyard-online/  [EXTERNAL / uncoupled]

**SwitchYard.online is a standalone product, uncoupled from this monorepo.** It is
the freely hosted online routing surface (live at **switchyard.online**) and is
**not vendored** into magentic-stack. The stack interoperates with it through the
**CPCP seam** (route decisions governed via `/_cpcp`), not by building its source.

- **Runs independently** of `magentic-stack` (own repo, own deploy).
- **Coupling = contract only:** OSI-8 / CPCP, not source.
- Its content-blind, on-device sibling **is** part of the stack:
  [`../switchyard-offline/`](../switchyard-offline/) (vendored; Gate 5).
