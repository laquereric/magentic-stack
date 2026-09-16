# Purpose-based layering — the medallion, disciplined

Integrates `docs/research/DataLayer.md` (Modern Data 101, "The Layering Obsession"): a **layer is a
boundary where data changes state**, and it *earns its place* only by doing something that couldn't
happen elsewhere. Reject the maximalist habit of stacking "one more" gold/silver/bronze. Ask **what is
each tier FOR?** — every layer does exactly one of three jobs: **Build · Consume · Operate**.

## mmg-medallion is a BUILD layer (create meaning / productise)
Its Bronze→Silver→Gold projection maps 1:1 onto the Build actionables — each tier earns its place by a
**unique state-change**:

| Tier | Build actionable | Unique state-change (why it earns its place) | Code |
|---|---|---|---|
| **Bronze** | **landing** | relocates raw triples **unchanged** — closes the reachability gap. *Never transforms* (the moment it does, it's a different tier wearing Bronze's badge). | ingest |
| **Silver** | **transform** | the **first decision**: conform / resolve / dedup / collapse grain → shape. | `Conformer` (Bronze→Silver) |
| **Gold** | **semantic model + contract** | the **center of gravity**: a measure/subject defined **once** (what it means, how computed, what "fresh" means) — a *shared definition of truth*, triple-native + SHACL — plus the **contract** (schema you can depend on + freshness SLA + breakage policy). | `Curator` (Silver→Gold) |

Being a **semantic** medallion is the point: Gold is not "another zone", it is the semantic model — the
shared truth no two consumers can compute two different ways.

## The earn-its-place guard (anti-maximalism)
`audit!` is the discipline: **a tier with no unique state-change is rejected.** No zone is added out of
habit; if a proposed tier doesn't change data's state in a way an existing tier can't, it doesn't exist.
Bronze that transforms, or a Silver that only copies, fails the audit.

## Consume / Operate are sibling purposes, not more tiers
- **Consume** (serve trusted state to a reader) — read-model APIs / SAL surfaces (sibling gems), not a
  new medallion tier.
- **Operate** (run the thing) — observability + the `audit!` lineage/quality signals themselves.

A `purpose` (build|consume|operate) attribute on a `Flow`/`Tier` makes this explicit and keeps the
medallion a Build layer that refuses to sprawl. Full guidance: `docs/research/manus_data_layer.md`.
