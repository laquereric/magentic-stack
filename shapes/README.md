# SHACL shapes for OSI Level 8

The base (`../docs/osi-level-8-base.md`, section 8) defines the **shape mechanism**:
closed SHACL shapes make boundary conformance decidable. The base does not ship
specific shapes.

## Profile shapes in this repo

| Profile | Shape file |
|---|---|
| **Profile 8 — Architectural Learning Loop** | [`osi-level-8-profile-8-architectural-learning-loop.ttl`](osi-level-8-profile-8-architectural-learning-loop.ttl) |

Profile 8 closed NodeShapes (one per entity):

- `SharedCognitionModel`
- `AssumptionRecord` (digest-only assumed values; status enum)
- `DriftMeasurement` (`driftScore` / `threshold` decimals)
- `ReconciliationRun` (**requires** `humanCheckpointRef` + `operationId`)
- `ArchitectureModel`
- `ArchitecturalDecisionRecord`
- `FrameChange`
- `AbsorptionOwnership` (**requires** `ownerRef`; decision adopt|skip|defer)

Namespace: `https://w3id.org/laquereric/osi-level-8/profile-8/v1#`  
Shape id: `https://w3id.org/laquereric/osi-level-8/shapes/profile-8/architectural-learning-loop/v1`

Examples: [`examples/profile-8-valid.ttl`](examples/profile-8-valid.ttl) (conforms) ·
[`examples/profile-8-invalid-missing-checkpoint.ttl`](examples/profile-8-invalid-missing-checkpoint.ttl) (fails).

Validate:

```bash
pip install pyshacl rdflib   # if needed
python3 scripts/validate_profile8.py
```

## External CPCP profile shapes

- **Profile 1 (Cyborg Channel)** — https://github.com/laquereric/JSON-RPC-LD-PS1-P1 → `shapes/`
- **Profile 2 (reference-passing)** — https://github.com/laquereric/JSON-RPC-LD-PS1-P2 → `shapes/`

See the CPCP standard: https://github.com/laquereric/cyborg-pod-contract-package
