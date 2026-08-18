# apps/  🔵 OFFICIAL

Magentic-built products and surfaces. They must **consume** the owned contracts
(`grammar/` via `interfaces/`) — never bypass them. Together they form the
adoption flywheel: **SwitchYard → (ThreeDot) → MagenticMarket**.

| Subdir | Product | Canonical source | Status |
|---|---|---|---|
| `switchyard-online/` | Freely hosted online routing surface. | `app-switchyard-online` | live at switchyard.online |
| `switchyard-offline/` | Private/local routing plugin (“no prompt leaves your device”). | `app-switchyard-offline` | Chrome plugin |
| `switchyard-market-gateway/` | MagenticMarket integration gateway. | `mmg-switchyard` | — |
| `magentic-market/` | Marketplace for verified offers without data inspection. | MagenticMarket | — |

## Vendored source

- `switchyard-offline/` is vendored in via **git subtree** (ADR 0002; relicensed
  Apache-2.0 for inclusion) - the real SwitchYard.offline (Chrome MV3 + loopback
  listener + content-blind egress gate). **Gate 5** runs its test suite and drives
  `shared/egress.js` to prove no prompt leaves the device except to an allowlisted
  provider with an on-device credential.
