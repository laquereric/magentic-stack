# SHACL shapes for OSI Level 8

The base (`../docs/osi-level-8-base.md`, section 8) defines the **shape mechanism**:
closed SHACL shapes make boundary conformance decidable. The base does not ship
specific shapes.

## Profile shapes in this repo

| Profile | Shape file |
|---|---|
| **3 — SwitchYard (Market Routing)** | [`osi-level-8-profile-3-switchyard.ttl`](osi-level-8-profile-3-switchyard.ttl) |
| **4 — Durable Cyborg Execution** | [`osi-level-8-profile-4-durable-cyborg-execution.ttl`](osi-level-8-profile-4-durable-cyborg-execution.ttl) |
| **5 — Biography & Provenance** | [`osi-level-8-profile-5-biography-and-provenance.ttl`](osi-level-8-profile-5-biography-and-provenance.ttl) |
| **6 — Enterprise Authorization Evidence** | [`osi-level-8-profile-6-enterprise-authorization-evidence.ttl`](osi-level-8-profile-6-enterprise-authorization-evidence.ttl) |
| **7 — Observation & Outcome** | [`osi-level-8-profile-7-observation-and-outcome.ttl`](osi-level-8-profile-7-observation-and-outcome.ttl) |
| **8 — Architectural Learning Loop** | [`osi-level-8-profile-8-architectural-learning-loop.ttl`](osi-level-8-profile-8-architectural-learning-loop.ttl) |

Conventions (all profiles): one CLOSED `sh:NodeShape` per entity; `sh:closed true`;
`sh:ignoredProperties ( rdf:type )`; versioned `shapeId` + `contextId`; `*Ref` =
`sh:nodeKind sh:IRI`; digests `sha256:` pattern; enums via `sh:in`.

### Key invariants

- **P3:** `RouteRequest.operationId` + `payloadRef` IRI (never inline payload);
  `RouteDecision` requires `policyDigest`+rationale+audit and is **closed** (no payload/prompt);
  decision is an egress **proposal**, not a release; `ProviderOffer` attestations+offerVersion;
  `UsageMetric.privacyTransform` required.
- **P4:** `DurableRun` requires `runId`+`operationId`+status enum; `Checkpoint` requires
  `stateDigest`+`resumeTokenRef`; `TerminalReceipt` requires outcome+`finalStateDigest`+signature;
  `RetryPlan` / `CompensationPlan` present as shapes.
- **P5:** `BiographyEvent` requires causal links including `causalParentRef` (IRI or
  `<urn:osi:level-8:causal-root>`); Journal append-only ordering; ReconstructionRule deterministic digest.
- **P6:** `AuthorizationDecision` subject/action/resource/decision/policyDigest/evidence;
  `CredentialRef.credentialLocator` is IRI **never** a literal secret; `Revocation` target+revokedAt;
  `PolicyRef.policyVersion` required.
- **P7:** `OutcomeMeasurement` requires `effectRef`(s)+`attributionWindow`+`measuredValue`;
  `ImprovementDecision` is a grounded Effect (`operationId`).
- **P8:** `ReconciliationRun` requires `humanCheckpointRef`+`operationId`; digests not raw values.

Examples live under [`examples/`](examples/) (`profile-N-valid.ttl` + `profile-N-invalid-*.ttl`).

```bash
python3 -m venv .venv && . .venv/bin/activate
pip install pyshacl rdflib
python3 scripts/validate_profiles.py   # covers profiles 3–8
```

## External CPCP profile shapes

- **Profile 1 (Cyborg Channel)** — https://github.com/laquereric/JSON-RPC-LD-PS1-P1 → `shapes/`
- **Profile 2 (reference-passing)** — https://github.com/laquereric/JSON-RPC-LD-PS1-P2 → `shapes/`

See the CPCP standard: https://github.com/laquereric/cyborg-pod-contract-package
