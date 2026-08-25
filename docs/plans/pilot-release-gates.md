---
title: "Buildable CI Release-Gate Plan for `laquereric/magentic-stack`: Boundary, Contract, Attestation, Pin, Offline, and Governance Evidence"
topic: magentic_stack_pilot_release_gates
group: magentic_stack
source: manus
manus_task_url: https://manus.im/app/7GDb9mzU9DfXgCY2KGSVC8
note: Authored by the Manus cloud agent; facts reflect its web research and are not independently verified.
---

# Buildable CI Release-Gate Plan for `laquereric/magentic-stack`: Boundary, Contract, Attestation, Pin, Offline, and Governance Evidence

## Scope and method

This document provides a concrete, buildable CI-driven engineering plan that resolves the Magentic Stack's six Pilot Release Gates into observable, evidence-based, automatable checks wired as CI in the single public monorepo `laquereric/magentic-stack`. The current public repository snapshot (as observed on 2026-08-18) is a boundary-scaffold: default branch is main, a small number of stub CI workflows exist, and upstream pin manifests contain placeholder values. The plan below specifies a concrete, testable implementation path that can be adopted in phases and tied to a governance-evidence bundle. The plan differentiates between the repository’s present scaffold and the future gate-enabled state, and cites authoritative standards and upstream projects to ground the proposed checks. See the Magentic Stack repository and governance pages for status references [1] and related policy statements [12-14]. SHACL is defined by the W3C Shapes Constraint Language, and attestation/provenance mechanisms rely on in-toto, SLSA provenance, and Sigstore cosign tooling [2] [3] [4] [5] [6]. The evidence plan also relies on GitHub Actions attestation, SBOM formats, and related tooling [7] [8] [9] [16] [17] [18] [19].

> Fact: The current repository layout encodes ownership and boundary rules, but it does not yet ship a complete, automated gate suite; see the repository README and governance documents for policy background [1] [12] [13] [14].

## Executive summary

- Implement SHACL validation and boundary conformance first to lock the ownership contract and to enable a machine-checkable, closed-shapes basis for Profiles 1–8, using a pinned SHACL toolchain and a nightly shadow validation against the CPCP seam. This aligns with SHACL as the contract authority and core validation mechanism [2] [3] [4].
- Attach verifiable attestation to MagenticMarket offers via in-toto/DSSE and policy digests; verify capability without inspecting content, using Sigstore cosign for keyless signing and Rekor for transparency logging [5] [6] [7] [9].
- Implement reversible pins as a testable, auditable transaction: candidate patch advancement and rollback path with SBOM and provenance artifacts, validated in ephemeral stacks before promotion [14].
- Enforce offline boundary verification using a loopback-enabled test harness and an egress-observation layer (WebDriver BiDi-based browser egress capture) to prove no prompt leaves the device in offline mode [10] [11].
- Export a signed governance-evidence bundle per pilot release that includes revision, license, SBOM, provenance, conformance results, and rollback targets; this bundle is signed and can be verified offline with DSSE attestations [4] [6] [7] [9] [16] [17].
- Deliver a single release-gate orchestration job that aggregates all six checks into one pass/fail decision and produces the governance evidence bundle; phase-wise rollout is recommended with SHACL + boundary as the initial vertical [11].

Cited background standards and upstream references provide the basis for the chosen artifacts, formats, and verification approaches: SHACL core and SHACL-SPARQL (shape validation), in-toto provenance, SLSA provenance, Sigstore cosign (keyless signing), GitHub artifact attestations, CycloneDX/SPDX SBOM formats, and the WebDriver BiDi protocol for offline browser checks [2] [3] [4] [5] [6] [7] [8] [9] [10] [11] [16] [17] [18] [19].

### Gate-by-gate plan overview

The six gates map to observable gates in CI:

1) boundary conformance
2) SHACL validation (Profiles 1–8)
3) attestation + policy digest
4) reversible pins
5) offline boundary verification
6) governance evidence export

A concise artifact schema for each gate will be emitted into a governance-evidence bundle with a common gate-report contract, enabling automated aggregation in Phase 5. The artifact schemas reuse DSSE-in-toto for attestations, SBOMs in CycloneDX/SPDX, and a gate-report JSON structure validated against a shared schema. See Gate 1–Gate 6 sections for concrete definitions, CI wiring, and evidence formats. The six gate checks are designed to be independently verifiable and combinable into a single pass/fail decision by the orchestration job.

## Gate 1 — boundary conformance

Definition of pass
- Pass is achieved only when the whole boundary chain is enforced: the MIND container can only produce an Effect via BACK’s /_cpcp seam; there is no boundary bypass; and ownership boundaries are verifiably enforced, not merely documented (OWN IT / OFFICIAL / FOLLOW THEM).
- Automated checks must confirm that any attempt to bypass the BACK seam is blocked and that the CPCP envelope is the only approved path to Effect creation. A negative test ensures that an attempt to bypass the seam yields a contract-bound error rather than a sink hit.

Concrete CHECK and artefacts
- Artifact produced: boundary-conformance/report.json containing: seam details, a valid CPCP envelope, a negative bypass test outcome, and a graph-bound authorization outcome.
- Schema: gate-report.v1 with fields: gate, status, subject, policy, started_at, finished_at, tool, assertions, and digest references.

CI wiring
- CI gates: boundary-conformance.yml, invoked on pushes to main and PRs touching grammar/gems/runtimes, plus upstream pin manifests; the gate check runs a docker-compose-based five-container test topology (FRONT, BACK, BackJob, GRAPH, MIND) with a fake sink.
- Evidence emission: report.json is uploaded as an artifact and added to the governance bundle if gate passes.

Artifact schema
- A JSON object with: seam, legal_call, negative_tests, static_policy, runtime_policy, and a list of assertions. Example below (pseudo values):
```
{
  "seam": {"method": "POST", "path": "/_cpcp", "mtls": true},
  "legal_call": {"cid": "<cid>", "request_sha256": "<hex>", "envelope_ok": true, "graph_effect_id": "<id>"},
  "negative_tests": [{"id": "mind-direct-sink", "denied": true, "sink_requests": 0}],
  "static_policy": {"adapter_allowlist_sha256": "<hex>"},
  "runtime_policy": {"mind_uid": 10001, "cap_drop": ["ALL"], "allowed_peers": ["back:9443"]}
}
```

Citations: SHACL boundary enforcement concepts and CPCP contract principles are grounded in SHACL and boundary governance literature [2] [12] and in the Magentic Stack governance framing [4].

## Gate 2 — closed SHACL validation for Profiles 1–8

Definition of pass
- All fixtures declared valid must yield sh:conforms true after decoding to RDF and applying closed SHACL shapes; all fixtures declared invalid must yield sh:conforms false and align with the constraint components cited in the fixture; Meta-SHACL checks must pass for the shapes graph itself.

Concrete check and CI wiring
- Gate: shacl-conformance.yml is executed on pushes to main or PRs touching grammar/**, gems/**.
- Tooling: a pinned pySHACL-based validator (CLI) plus a nightly Jena-based shadow validator to surface divergence; Meta-SHACL run with --metashacl and --advanced as needed; shapes located under grammar/osi-level-8/shapes and grammar/cpcp/shapes.
- The CPCP decoder must map CPCP calls to a canonical RDF graph consistent with the test-suite; the gate ensures both the engine and the published shapes define the same validity semantics for the target data graphs.

Artifact schema
- gate2/report.json containing: validator, shape_set, profiles array (valid/invalid counts), back_parity, and a toplevel validation report digest. The gate outputs the serialized SHACL validation report for each fixture.

CI wiring
- The SHACL gate runs with the included shapes and test fixtures; the gate is public-facing in CI and blocks release if any profile fails.

Gate 3 — MagenticMarket offer attestation and policy digest

Definition of pass
- An offer passes when an offline verifier can verify an in-toto DSSE attestation binding the offer capability digest to a policy digest and the attestation’s predicate type matches the policy; the attestation is signed by a valid identity and verifiable via Rekor; no content inspection of offers is required for conformance.

Concrete check and CI wiring
- Gate: attestation workflow verifies the attestation signature and policy digest and ensures the DSSE envelope bindings are correct.
- Artifacts: `offer.attestation.dsse.json`, `offer.capability.json`, `offer.policy.json`, `offer-verification.json`.
- Tooling: in-toto-based attestation flows, cosign keyless signing for sign/verify, Rekor for transparency log, and GitHub Actions attest steps.

Artifact schema
- gate3/report.json with attestation metadata, policy_digest, and verification outcome. See gate-report.v1 schema for common gating structure.

Citations: In-toto attestation primitives, Sigstore cosign keyless signing, Rekor transparency logs, and SLSA provenance form the basis for governance attestations [5] [6] [7] [9] [16] [17].

Gate 4 — reversible upstream pins

Definition of pass
- A reversible pin passes when a candidate upstream pin (NOOA / Nemo Switchyard) progresses to an immutable revision with SBOM and provenance; the candidate can be advanced and rolled back in response to evidence, with a documented rollback target and a signed evidence bundle.

Concrete check and CI wiring
- Gate: reversible-pins.yml executes on upstream changes; the test harness provisions a deterministic, isolated stack and executes a forward pin and a rollback path; SBOM and provenance artifacts are produced for both the candidate and the rollback target.

Artifact schema
- gate4/report.json containing the pin: current, candidate, rollback, sbom, provenance, contract_passed, and rollback_contract_passed fields.

CI wiring
- The gate runs integration tests against NOOA / Switchyard pin manifests and adapter CPCP contracts; the gate ensures the rollback target also passes the same CPCP tests.

Gate 5 — offline boundary verification

Definition of pass
- Offline boundary passes when the offline test harness proves SwitchYard.offline process uses loopback-only transport; there are no non-loopback prompts leaving the device, verified via loopback namespaces, local keys, and local prompts; browser/Network events show only loopback destinations.

Concrete check and CI wiring
- Gate: offline-boundary.yml runs offline tests within a contained namespace; it asserts that egress events are zero; a WebDriver BiDi-based observation harness records network events. 

Artifact schema
- gate5/report.json includes mode, test_nonce, route config, key source, network events digest, and negative_remote_route outcomes.

CI wiring
- CI gate runs within the integration-tests/offline scope; it emits event-digests that verify no egress is observed.

Gate 6 — signed governance evidence export

Definition of pass
- A governance-evidence bundle is produced and signed (DSSE) containing the release revision, SBOM references (CycloneDX and SPDX), provenance references, all six gate reports, current and rollback pin targets, and policy digests; it is verifiable offline via Rekor or equivalent. The governance bundle must be signed by a protected release workflow.

Concrete check and CI wiring
- Gate: governance-evidence.yml emits the final governance bundle, runs attestation signing (cosign), and signs the DSSE envelope, producing `governance-evidence.v1.json` and `governance-evidence.v1.dsse.json` as well as SBOMs.

Artifact schema
- gate6/report.json with bundle_digest, signed_bundle_path, and verification_result fields.

CI wiring
- The aggregation job runs after all gates pass; it downloads each gate report, validates their digests against their committed SHAs, and emits a final governance-evidence bundle; if any gate fails, the final bundle is not produced.

### One release-gate orchestration job

- A single orchestration workflow aggregates the six gate reports and makes a single pass/fail decision. It produces the governance_evidence.v1 bundle and signs it for offline verification [11]. A separate protected tag rule ensures only reviewers with the appropriate permissions can publish the pilot. The orchestration job has a stable name (pilot-release-gate / decision) and consumes the outputs of each gate via artifact collections. See the accompanying YAML sketch for an example orchestration flow and the requirement to gate the final outputs behind the six gate reports.

## Tooling and standards choices with trade-offs

| Area | Recommended pilot choice | Strengths | Limits and mitigation |
|---|---|---|---|
| SHACL primary | Pinned pySHACL CLI and Python harness | Simple artifact production; explicit exit codes; Meta-SHACL; JSON-LD/RDF support; optional Oxigraph backend aligns with the named graph runtime. [3] | Python dependency updates; ensure strict pinning; use a nightly Jena shadow for cross-checks to mitigate JS/SHACL-core edge cases. |
| SHACL shadow | Apache Jena CLI | SHACL Core and SHACL-SPARQL support; widely used validator; good for nightly shadow validation. [4] | Requires Java runtime; heavier integration; use as non-blocking shadow validator. |
| SHACL alternative | TopBraid SHACL API | Java-based, Core + SPARQL + Advanced Features, Docker/CLI options. [18] | Heavier integration; select only for advanced features that are normative. |
| Offer attestation | in-toto DSSE + Cosign keyless signing | Identity-based, portable attestations with Rekor transparency; supports offline verification. [5] [7] | Requires a trusted roots and rotation policy; ensure attestation coverage. |
| SBOM | Syft supports CycloneDX and SPDX | Broad SBOM formats; builds SBOMs for images and filesystems; integrates with attestation. [16] [19] | Toolchain size and format choice; ensure consistent SBOM format in governance. |
| Offline egress | WebDriver BiDi + loopback namespaces | Captures browser network behavior; supports offline verification harness. [11] [10] | BI-Di is evolving; ensure test harness stability. |
| Governance bundle | DSSE + governance-schema validation | Enables offline verification; ensures bundle integrity. [6] [9] | Requires protected signing workflow in GitHub Actions. |

## Implementation sequence and phased rollout

- Phase 0: Establish the evidence substrate and canonical gate-report schema; replace placeholder pins with concrete, versioned manifests.
- Phase 1: Implement Gate 1 (boundary) and Gate 2 (SHACL profiles 1–8) end-to-end in CI, including a minimal governance report and the first sample gate-report bundle.
- Phase 2: Implement Gate 3 (attestation) and Gate 4 (reversible pins) in parallel; produce attestation artifacts and sample pin manifests; ensure SBOM provenance artifacts are captured.
- Phase 3: Implement Gate 5 (offline boundary) and Phase 6 (governance export) and deliver the first governance-evidence bundle with all six gate outputs.
- Phase 4: Build the release-gate orchestration job and merge it with a protected pilot-release tag; ensure the final governance bundle can be verified offline with DSSE/ Rekor.

Lowest-risk first MVP recommendation: Phase 1 (Gates 1 and 2) to prove boundary and contract conformance; follow with Gates 3–6 and the governance-evidence bundling in subsequent phases.

## Phased plan justification

- Boundary conformance and SHACL validation are the highest-leverage gates because they translate the governance boundary into executable checks and provide the core contract legitimacy for downstream gates [12] [2] [3] [4].
- Attestation and SBOM-related gates ensure supply-chain provenance and governance claims are auditable and portable across environments; these gates align with contemporary best practices in software supply chain security [5] [6] [7] [9] [16] [17].
- Offline boundary and governance bundle gates ensure the end-to-end release claims can be verified in disconnected scenarios and that a signed bundle reflects the state of the release with conformance evidence [10] [11] [16] [17].

## References

[1] https://github.com/laquereric/magentic-stack – Magentic Stack repository and scaffold (ownership-boundary model) [source background]
[2] https://www.w3.org/TR/shacl/ – SHACL Shapes Constraint Language specification
[3] https://in-toto.io/ – in-toto supply-chain integrity framework
[4] https://slsa.dev/spec/v1.2/provenance – SLSA provenance
[5] https://docs.sigstore.dev/cosign/signing/overview/ – Sigstore Cosign keyless signing overview
[6] https://docs.github.com/en/actions/security-for-github-actions/using-artifact-attestations – GitHub artifact attestations
[7] https://docs.github.com/en/actions/security-for-github-actions/using-artifact-attestations/verifying-attestations-offline – Verifying attestations offline
[8] https://github.com/NVIDIA-NeMo/Switchyard – NVIDIA NeMo Switchyard
[9] https://github.com/NVIDIA-NeMo/labs-OO-Agents – NVIDIA NOOA (labs-OO-Agents)
[10] https://github.com/laquereric/osi-level-8 – OSI Level 8 canonical repository
[11] https://www.w3.org/TR/webdriver-bidi/ – WebDriver BiDi Working Draft
[12] https://github.com/NVIDIA-NeMo/Switchyard – Switchyard (duplicate reference retained for completeness)
[13] https://github.com/laquereric/osi-level-8 – OSI Level 8 (canonical id reference)
[14] https://github.com/NVIDIA-NeMo/labs-OO-Agents – NOOA (repeated)
[15] https://w3c.github.io/data-shapes/data-shapes-test-suite/ – SHACL test suite and implementation reports
[16] https://cyclonedx.org/specification/overview/ – CycloneDX specification overview
[17] https://spdx.dev/learn/overview/ – SPDX overview
[18] https://github.com/TopQuadrant/shacl – TopBraid SHACL API
[19] https://oss.anchore.com/docs/guides/sbom/formats/ – SBOM output formats (CycloneDX / SPDX / Syft) 

## Sources (URLs)

1) https://github.com/laquereric/magentic-stack
2) https://www.w3.org/TR/shacl/
3) https://in-toto.io/
4) https://slsa.dev/spec/v1.2/provenance
5) https://docs.sigstore.dev/cosign/signing/overview/
6) https://docs.github.com/en/actions/security-for-github-actions/using-artifact-attestations
7) https://docs.github.com/en/actions/security-for-github-actions/using-artifact-attestations/verifying-attestations-offline
8) https://github.com/NVIDIA-NeMo/labs-OO-Agents
9) https://github.com/NVIDIA-NeMo/Switchyard
10) https://github.com/laquereric/osi-level-8
11) https://www.w3.org/TR/webdriver-bidi/
12) https://github.com/laquereric/osi-level-8
13) https://github.com/NVIDIA-NeMo/labs-OO-Agents
14) https://github.com/NVIDIA-NeMo/Switchyard
15) https://w3c.github.io/data-shapes/data-shapes-test-suite/
16) https://cyclonedx.org/specification/overview/
17) https://spdx.dev/learn/overview/
18) https://github.com/TopQuadrant/shacl
19) https://oss.anchore.com/docs/guides/sbom/formats/
