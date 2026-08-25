# Governance

The Magentic Stack is organized around one idea: **make the ownership boundary
visible in the tree.** Owned language and contracts are first-class; upstreams
are pinned and reached only through adapters. These rules exist so the
enterprise-facing contract stays stable while upstream AI churns.

## Ownership tiers

| Tier | Areas | Change policy |
|---|---|---|
| 🟢 **OWN IT** | `grammar/`, `gems/`, `runtimes/` | Deliberate, versioned, contract-driven. Breaking changes require an ADR and a conformance bump. |
| 🔵 **OFFICIAL** | `apps/`, `plugins/` | Product velocity is fine, but must consume the owned contracts — never bypass them. |
| 🟡 **FOLLOW THEM** | `upstreams/` | **Pinned, never forked.** Updated only via a recorded pin bump with SBOM + provenance + rollback target. |

## The four rules

1. **Boundary ownership.** `grammar/`, `gems/`, `runtimes/`, `apps/`, and
   `plugins/` are Magentic-owned. `upstreams/` is a tracked dependency area and
   its contents are never modified in place — only pinned and adapted.

2. **Release integrity.** Every release records: source revision, license, SBOM,
   provenance, conformance results, and rollback targets for the NOOA and
   Switchyard pins. Pin records live in `upstreams/manifests/`.

3. **Contract authority.** SHACL shapes and normative profiles in `grammar/` are
   the authoritative specification. Generated code and interface implementations
   **derive from** these contracts; when code and contract disagree, the contract
   wins.

4. **Privacy commitment.** Offline boundary tests and explicit opt-in analytics
   governance apply to all telemetry. “No prompt leaves your device” for
   SwitchYard.offline is a testable claim, not a slogan.

## “Follow, do not fork”

Upstream runtimes and routers (NVIDIA NOOA, NeMo Switchyard) are treated as
replaceable, pinned dependencies. We follow upstream releases; we do not fork
Magentic-specific variants. Governance of their behavior happens at *our* seam
(the `/_cpcp` contract), not inside their code. Each pin carries a pin matrix,
adapter, and integration tests so a version can be advanced or rolled back on
evidence.

## Pilot release gates

A release to a pilot must pass observable, evidence-based checks:

- boundary conformance
- SHACL validation (closed shapes)
- attestation + policy digest
- reversible pins (rollback target recorded)
- offline boundary verification
- governance evidence export

## Decision records

Architectural decisions are captured as ADRs under `docs/adr/`. Anything that
moves a boundary, changes a contract, or advances an upstream pin gets an ADR.
