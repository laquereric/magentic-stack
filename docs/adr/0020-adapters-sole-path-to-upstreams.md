---
id: "0020"
title: Adapters are the only code permitted to reach upstream
status: accepted
date: 2026-08-26
subject_kind: gem
subject: adapters
components: [adapters]
paths:
  - gems/adapters
  - upstreams
enforced_by: []
supersedes: null
superseded_by: null
---

## Context

Frontier AI churns on roughly a 90-day loop. If the enterprise-facing contract
is entangled with upstream runtimes, every upstream change forces a rewrite of
the thing that was supposed to be stable.

The damage is not the first import. It is the tenth, in ten different files,
after which "what would this cost to re-pin" has no answer short of reading
everything.

## Decision

`gems/adapters/` is the **only** code permitted to import from `upstreams/`.
Upstreams are pinned by revision and never forked. Each adapter wraps one pinned
upstream and exposes it through the owned OSI-8 / CPCP contracts, and carries a
pin matrix and integration tests so a pin can advance or roll back on evidence.

## Consequences

- Upstream churn is absorbed at one layer, and re-pinning has a bounded cost.
- Reaching an upstream capability requires widening an adapter rather than
  adding an import, which is slower and is meant to be.
- **The chain is incomplete here.** `enforced_by` is empty: the rule is stated
  but nothing checks it, and an import-boundary rule is exactly the kind a
  fitness function should own -- a dozen lines asserting no path outside
  `gems/adapters/` references `upstreams/`. This is the most valuable missing
  test in the repository and is recorded as such.
