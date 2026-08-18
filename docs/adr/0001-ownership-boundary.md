# ADR 0001 — Make the ownership boundary visible in the tree

- Status: Accepted
- Date: 2026-08-18

## Context

Frontier AI churns on a ~90-day loop. If the enterprise-facing contract is
entangled with upstream runtimes, every upstream change forces a rewrite.
Enterprises need a stable language and a bounded governance surface.

## Decision

Structure the repository so that ownership is legible at the top level:

- 🟢 **OWN IT** — `grammar/`, `interfaces/`, `runtimes/`: durable, versioned,
  contract-driven. This is the enterprise truth boundary.
- 🔵 **OFFICIAL** — `apps/`, `plugins/`: Magentic products that *consume* the
  owned contracts.
- 🟡 **FOLLOW THEM** — `upstreams/`: pinned, never forked; reached via adapters.

SHACL shapes and normative profiles are authoritative; code derives from them.

## Consequences

- Upstream churn is absorbed at the adapter/pin layer, not in the contract.
- Releases must record revision, license, SBOM, provenance, conformance, and
  rollback targets (see GOVERNANCE.md).
- A contributor can tell, from the path alone, what change discipline applies.
