---
id: "0001"
title: Make the ownership boundary visible in the tree
status: accepted
date: 2026-08-18
subject_kind: tooling
subject: repo
components: []
paths:
  - grammar
  - gems
  - runtimes
  - upstreams
enforced_by:
  - tooling/boundary/check_boundary.py
  - tooling/pins/check_pydantic_ai_harness.py
  - .github/workflows/boundary-conformance.yml
supersedes: null
superseded_by: null
---
# ADR 0001 — Make the ownership boundary visible in the tree

## Context

Frontier AI churns on a ~90-day loop. If the enterprise-facing contract is
entangled with upstream runtimes, every upstream change forces a rewrite.
Enterprises need a stable language and a bounded governance surface.

## Decision

Structure the repository so that ownership is legible at the top level:

- 🟢 **OWN IT** — `grammar/`, `gems/`, `runtimes/`: durable, versioned,
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
- External validation: pydantic split `pydantic-ai-harness` out of
  `pydantic-ai` so capabilities can churn while the framework stays lean —
  the same OWN/FOLLOW split, at 20k-star scale. Cite it; do not vendor it.
  Source: <https://github.com/pydantic/pydantic-ai-harness>. The harness's
  capabilities (shell, browser, filesystem, sub-agents) would blow through
  the bounded Effect surface. See `docs/pydantic-upgrades.md`.
  `tooling/pins/check_pydantic_ai_harness.py` holds the citation and the
  no-home rule.
