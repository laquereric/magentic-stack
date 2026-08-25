---
title: "Engineering Plan: Make laquereric/magentic-stack the Buildable, Canonical Source of Truth"
topic: magentic_stack_self_referential_build
group: magentic_stack
source: manus
manus_task_url: https://manus.im/app/A9r6MfkwSUfn9hFnenZD92
note: Authored by the Manus cloud agent; facts reflect its web research and are not independently verified.
---

# Engineering Plan: Make laquereric/magentic-stack the Buildable, Canonical Source of Truth

Scope and method

This document prescribes a concrete, buildable engineering plan to consolidate the public repository laquereric/magentic-stack into a self-referential, canonical monorepo that serves as the maintained SOURCE OF TRUTH for The Magentic Stack. The plan preserves the repository’s ownership boundaries (OWN IT, OFFICIAL, FOLLOW THEM) and establishes a bootstrapable end-to-end build, a unified maintenance model, and six CI-driven pilot release gates. It relies on evidence from public sources and the current scaffold’s governance documentation, including the boundary rules and the “follow, do not fork” policy for upstreams. See the governance and repository description for context and constraints [1] [2].

Executive summary

- Adopt a hybrid consolidation model: import Magentic-owned/official sources via history-preserving subtree imports to establish a canonical, editable core within magentic-stack, while pinning NVIDIA upstreams in upstreams/ as read-only submodules with explicit pin manifests. This approach preserves governance provenance and avoids forking upstreams. This hybrid is recommended by best-practice comparisons of submodules, subtree merges, and in-repo workspaces, to balance ownership, history, and boundary clarity [8] [9] [10] [11] [12].
- Implement a single bootstrap entry point. A one-command bootstrap clones magentic-stack, initializes and pins upstreams, builds all polyglot components via language-native workspaces (Bundler path gems for Ruby, pnpm workspaces for TypeScript, and a Rust/Cargo workspace for adapters), starts a governed pod (the MIND pod) in a containerized dev environment, and performs an end-to-end smoke test against the contract seam (_/cpcp). This bootstrap is designed to work with a Docker Compose-based five-container topology as described by the current CPCP and MIND pod model [4], while keeping upstream pins immutable [2].
- Define a canonical maintenance model. Once canonicalized, old external repos become archives or redirects to the magentic-stack canonical path, with a PROMINENT pointer in the root README and a dedicated SOURCE-STATUS/ARCHIVE note. Upstream pins stay in upstreams/manifests with SBOMs and rollback targets; every release aggregates provenance and conformance evidence into a release artifact bundle [2] [13] [14].
- Enforce six pilot release gates from the single repository. The plan transforms the scaffold’s echo TODO gates into a unified, machine-checkable release gates workflow that validates boundary conformance, SHACL conformance, attestation, reversible pins, offline boundary tests, and governance-evidence export; artifacts are stored as release artifacts with SBOMs and provenance [15] [16] [17].
- Propose phased migration with acceptance criteria and rollback. The migration proceeds in phases, starting with the smallest demonstrable slice (clone one repo and build the governed path) and culminating in a full canonical cutover with a released stack tag and a locked upstream pin matrix. Each phase includes a concrete acceptance criterion and a rollback path to a known-good state [2] [9].

1 Confirmed baseline and migration inventory

1.1 What exists today

The current scaffold encodes an ownership boundary: OWN IT (grammar, interfaces, runtimes), OFFICIAL (apps, plugins), and FOLLOW THEM (upstreams). The governance document frames the boundary rules, the release integrity requirements (SBOM, provenance, conformance), and the six pilot gates as binding policy for the canonical monorepo [2]. The OSI-Level-8 ecosystem is publicly visible in separate canonical repositories (laquereric/osi-level-8, laquereric/json-rpc-ld); the CPCP rails repository is private and are identified in the scaffold as the intended import targets, including their public licenses and versioning constraints. The official topology for the two-pod CPCP deployment (BACK and FRONT) is described in rails-cpcp, with a public surface at /_cpcp and endpoints such as CID retrieval and RPC surface [4]. The MIND pod topology (FRONT/BACK/BackJob/GRAPH/MIND) is outlined as the governance plane in the scaffold [2] [4].

1.2 Source intake register and pin manifests

The plan codifies a migration ledger that records canonical source, license, and pin state for each imported component. The current upstreams have pin manifests with PENDING pins indicating that they require a formal SBOM, provenance, and rollback targets before use in canonical builds. The plan requires upgrading all PENDING pins to either verified or blocked status prior to cutover, and to maintain SBOM provenance for each pin [2] [7]. For NVIDIA upstreams NOOA and Switchyard, the upstreams are pinned and used behind adapters; the upstreams manifests already articulate the “follow, do not fork” stance and pin semantics [13] [14] [2].

1.3 Immediate baseline corrections

Before consolidating, all pin records with PENDING should be upgraded to a complete record or explicitly blocked. Also, remove empty README directories that imply buildable components. The canonical path should be one repository with explicit subpaths and descriptors, not an empty directory that pretends to be a piece of the stack [2].

2 Consolidation strategy and decision record

2.1 Consolidation options evaluated

- Git submodules pinned to SHAs: Provides exact pinpoints of upstreams but requires bootstrap discipline; not ideal for multiple owned components, and creates additional operational complexity in bootstrap and CI. Submodules are appropriate for follow-the-upstream scenarios, particularly for NOOA and Switchyard where pinned commits are the governance boundary [8] [9].
- Git subtree / subtree merge: Enables a history-preserving consolidation into the canonical tree; the approach is suitable for initial imports of owned components with preserved histories and can be re-used for later merges of other owned packages [9][10].
- Vendoring/workspaces (Bundler path, npm/pnpm workspaces, Cargo workspaces): Ideal for ongoing in-repo build relationships and for developing with local, editable dependencies but does not itself provide history-preserving import of external upstreams. Workspaces are a strong mechanism for multi-language coordination and can be used after an initial subtree import to integrate the components into a single top-level build experience [10] [11] [12].

2.2 Recommended decision

Adopt a hybrid model: import owned/official sources into magentic-stack using non-squashed subtree merges to preserve history; then configure Bundler path gems, pnpm workspaces for JavaScript, and a Rust/Cargo virtual workspace to wire the imported components into a single build. NVIDIA upstreams remain as read-only submodules behind upstreams/ with complete pin manifests. This preserves a single source of truth, keeps ownership boundaries visible, and prevents upstream forks from entering the canonical code path [9] [12] [8] [2].

2.3 Post-consolidation layout (high-level)

The canonical layout centres on the three ownership tiers and aligns with the current scaffold’s intent: own the language and contracts (grammar, interfaces, runtimes); own the products (apps, plugins); follow upstreams as pinned dependencies. The plan’s target layout emphasizes that the monorepo is the sole source of truth and that all future development should occur within magentic-stack or via clearly pinned upstreams only [2].

3 Recommended post-consolidation layout

- A minimal GOV-initiated bootstrap path: bootstrap script that performs a full bootstrap inside a tooling container, with a single repository clone and a one-command bootstrap. This aligns with the current CPCP two-pod deployment model and ensures the bootstrap produces a deterministic, reproducible dev environment [4].
- A canonical source tree with: grammar/ interfaces/ runtimes/ (OWN IT), apps/ plugins/ (OFFICIAL), upstreams/ (FOLLOW THEM), integration-tests/, tooling/, deploy/, docs/ and a controlled Upstreams pin manifests directory at upstreams/manifests/ with SBOM, provenance, and rollback_target fields. The structure mirrors the current scaffold but with concrete entries and status for each piece [1] [2].
- A bootstrapped, one-command bootstrap that builds and exercises the governance path end-to-end through the /_cpcp seam; the test harness should execute a minimal end-to-end workflow without hitting a real model during initial validation, to prove the pipeline works and that the portal components are accessible [4].

4 One clone, one bootstrap, one reproducible developer path

- The public quick start is to clone magentic-stack and run the bootstrap: git clone ... && ./bootstrap. The bootstrap initializes submodules, builds dependencies, and launches the five-container governance pod in a containerized dev environment, enabling an end-to-end smoke test against /_cpcp. This bootstrap path mirrors how the current rails-cpcp and MIND pod topologies are described in the repository [4].

5 Source-of-truth maintenance and release model

- Post-consolidation, old external repos should be archived and redirected to canonical sources with a visible pointer in the root README; do not mirror or synchronize into the canonical tree. The six-pilot gates become a single, monorepo-driven gate that aggregates conformance, SHACL shapes validation, attestation, reversible pins, offline boundary tests, and governance-evidence export; release evidence is packaged and stored as artifacts with SBOMs and provenance [2] [15] [16] [17].
- Upstream pin bumps flow via upstreams/manifests/*.pin.json, with SBOM and provenance recorded in the pin manifests. Pins are updated only through a controlled PR-based process; no automatic remote updates bypass the governance seam. This aligns with the “follow them, do not fork” policy [2] [13] [14].

6 CI: implement the six pilot release gates from the single repository

The six gates are implemented as a single aggregator workflow in .github/workflows/release-gates.yml, with per-gate jobs that emit machine-readable evidence (e.g., boundary-conformance reports, shacl reports, attestation bundles, and SBOM proofs). The aggregator captures and stores artifacts and an artifact attestation as the release evidence bundle. GitHub’s workflow syntax, artifacts, and dependency caching features support the required data paths for artifacts and caching to accelerate CI; the gate runner must ensure that the six gates are green before publishing a stack/tag release [15] [16] [17].

7 Phased migration program

Phases are designed to prove the plan in small, controlled steps and then expand. Each phase has a green acceptance criterion and a rollback procedure to a known-good state. The first phase demonstrates clone-build of a minimal governance pod; the second phase introduces the owned rails-based components; the third phase introduces the upstream pinning; the fourth phase hydrates any blocked source areas; the fifth phase completes the canonical cutover and release. A two-week audit window is assumed for migration; shorter or longer windows may be required based on the discovery outcomes [2].

8 Risk register and mandatory controls

- History/attribution loss: mitigate by non-squashed subtree imports and an import ledger with per-repo records and tags; CI checks ensure provenance remains intact [2].
- License mixing: ensure a license map, SBOMs, notices, and clear separation of license boundaries; enforce in CI that no critical dependencies violate licensing constraints [2] [7] [13] [14].
- Repository size: avoid vendoring heavy assets; use lockfiles and workspace strategies to minimize bloat; shallow submodule imports and selective bootstrap build steps [11] [12].
- Upstream drift: pin drift is mitigated by read-only submodules and well-defined pin manifests for every upstream; no upstream history is merged except via pinned commits; changes require governance ADRs and release gates [2] [14].
- “Offline” claims and egress: ensure offline boundary tests are enforced and that the pins’ offline assertions are validated; the governance egress policy is explicit in the plan [2] [15].
- Required checks: ensure the six gates are enforced as a single aggregator and are non-skippable as required checks to avoid bypassing critical validation [15].

9 Definition of done

The monorepo is considered the canonical source of truth when: clone/bootstrap produces a fully healthy governance pod without requiring external credentials; all imported components live under magentic-stack with accessible CI and test coverage; the six gates pass and produce a consolidated evidence bundle; the upstream pins have complete manifests; and a stack-level release tag is published. The old repositories are archived or redirected to the canonical path, with a visible pointer in the root documentation [2] [4].

10 Sources

- laquereric/magentic-stack — current repository README and tree [1]
- laquereric/magentic-stack — GOVERNANCE.md [2]
- laquereric/osi-level-8 — public repository [3]
- laquereric/cpcp (was rails-cpcp) — CPCP deployment/interface documentation [4]. NOT public: private as of 2026-08-25, though several documents here described it as public. The gem is released; the repository is not open.
- laquereric/rails-osi-level-8 — public repository [5]
- laquereric/rails-threedot-back — public repository [6]
- app-switchyard-offline — package manifest [7]
- Git submodule documentation [8]
- GitHub Docs — About Git subtree merges [9]
- RubyGems/Bundler — Gemfile reference (path dependencies) [10]
- pnpm — Workspace documentation [11]
- Rust Cargo — Workspace reference [12]
- NVIDIA-NeMo/labs-OO-Agents README [13]
- NVIDIA-NeMo/Switchyard README [14]
- GitHub Docs — Workflow syntax for GitHub Actions [15]
- GitHub Docs — Workflow artifacts [16]
- GitHub Docs — Dependency caching [17]
- GitHub REST API — public repositories for laquereric [18]
- threedot-vscode public repository [19]

Notes: The above plan leans on publicly verifiable materials and the current scaffold’s governance artifacts. Where sources were not publicly resolvable or fully specified in the scaffold (notably certain official apps/plugins in the official tier), the plan treats them as blocked migration inputs requiring explicit source verification and documented pin manifests prior to import. All inline claims reference the sources listed in this document’s Source section.

End-to-end, this plan yields a concrete, buildable, self-referential Magentic Stack that respects ownership boundaries, pins upstreams, and provides a single, auditable source of truth for ongoing development and release governance.
