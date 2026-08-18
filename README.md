# rails-threedot-back

**The threedot BACK - the live data plane behind the threedot VS Code webview shell.**

The threedot plugin is split into a thin **webview shell** (FRONT, presentation only) and this
**Rails engine** (BACK). The BACK is authoritative for the CID(s), operations, capabilities,
shapes, and the plugin object model, served to the shell over the **single public CPCP seam**
(`/_cpcp`, via `rails-cpcp`).

## Core model: CID is the AR root
```
Cid (root AR)  has_many  Operation / Capability / Shape / ObjectNode
```
The CID is a first-class **ActiveRecord** record - the ROOT of every AR-driven threedot query.
The shell derives its live UI model (capabilities, params, result shapes) from this projection,
**not** from the static file.

## The static `.threedot/cid.json` is a bootstrap seed ONLY
It carries **no live operational data**. Its sole job is to **reconnect the CPCP path** - discover
where the BACK is and how to reach `/_cpcp`. Once connected, the shell reads the live AR-rooted CID
via `GET /_cpcp/cid.json` + CPCP **PULL**, and acts via typed closed-shape **PUSH** (idempotent by
`operationId`, receipt returned).

## Composition
- **`rails-cpcp`** - the single public `/_cpcp` seam; this engine projects the CID-rooted ops onto it (`CpcpProjection.install!`). No new endpoint family.
- **`rails-osi-level-8`** (optional) - OSI Level 8 grounding (three-ledger, profile evidence).
- **`Vv::Graph::Storable`** - RDF projection of the AR models; **enabled but deferred** (AR-primary first cut).

Status: **scaffold**. Apache-2.0. See `docs/CHARTER.md`.
