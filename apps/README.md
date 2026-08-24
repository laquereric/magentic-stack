# apps/  🔵 OFFICIAL

> **This directory is a category error and is being dissolved.**
>
> magentic-stack is the BASE that apps build on. It does not *have* apps. A thin
> layer lives in its own repo and references a baseline image by tag; a shared
> library lives in `interfaces/`. There is no third thing.
>
> `switchyard-offline` moved to `interfaces/switchyard-offline` — it is a library
> the baseline provides, and `runtimes/switch` imports its egress gate.
>
> The two entries left below are EXTERNAL products that were never coupled to
> this repo. They are kept only until it is confirmed nothing else reads them;
> they do not belong here either.

Magentic-built products and surfaces. They must **consume** the owned contracts
(`grammar/` via `interfaces/`) — never bypass them. Together they form the
adoption flywheel: **SwitchYard → (ThreeDot) → MagenticMarket**.

| Subdir | Product | Canonical source | Status |
|---|---|---|---|
| `switchyard-online/` | Freely hosted online routing surface. | `app-switchyard-online` | EXTERNAL - uncoupled (switchyard.online) |
| `switchyard-offline/` | Private/local routing plugin (“no prompt leaves your device”). | `app-switchyard-offline` | Chrome plugin |
| `magentic-market/` | Marketplace app (external); dir = offer-attestation contract. | MagenticMarket | EXTERNAL - uncoupled |

## Vendored source

- `switchyard-offline/` is vendored in via **git subtree** (ADR 0002; relicensed
  Apache-2.0 for inclusion) - the real SwitchYard.offline (Chrome MV3 + loopback
  listener + content-blind egress gate). **Gate 5** runs its test suite and drives
  `shared/egress.js` to prove no prompt leaves the device except to an allowlisted
  provider with an on-device credential.

## External / uncoupled

- `switchyard-online/` and `magentic-market/` are **standalone products, uncoupled
  from magentic-stack** - not vendored. The stack interoperates with them through
  the **CPCP / offer contract**, not by building their source. Their directories
  here hold only the pointer + the stack-owned contract fixtures (e.g. the Gate 3
  offer attestation), never the external app source.
