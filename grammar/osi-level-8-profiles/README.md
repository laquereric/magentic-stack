# osi-level-8-profiles

**All eight OSI Level 8 / CPCP profile SHACL shapes, in one place.** Refactored
from the split homes (Profiles 1-2 lived in the `JSON-RPC-LD-PS1-P1/P2` reference
implementations; Profiles 3-8 lived in `osi-level-8`) into a single per-profile tree.

| Profile | Slug | Source | Shapes | Fixtures |
|---|---|---|---|---|
| **1** | cyborg-channel | JSON-RPC-LD-PS1-P1 | envelope / canonical-record / sync-intent / private-local / allowlist / ps1-p1 | — (well-formedness) |
| **2** | reference-passing | JSON-RPC-LD-PS1-P2 | same shape family | — (well-formedness) |
| **3** | switchyard | osi-level-8 | RouteRequest / RouteDecision / ProviderOffer / UsageMetric | valid + invalid |
| **4** | durable-cyborg-execution | osi-level-8 | DurableRun / Checkpoint / TerminalReceipt | valid + invalid |
| **5** | biography-and-provenance | osi-level-8 | BiographyEvent / Journal / ReconstructionRule | valid + invalid |
| **6** | enterprise-authorization-evidence | osi-level-8 | AuthorizationDecision / CredentialRef / Revocation | valid + invalid |
| **7** | observation-and-outcome | osi-level-8 | OutcomeMeasurement / ImprovementDecision | valid + invalid |
| **8** | architectural-learning-loop | osi-level-8 | ReconciliationRun | valid + invalid |

Each `profile-N-slug/` holds `shapes/` (closed SHACL), and where they exist
`examples/` (valid + invalid fixtures) and `ontology/` (the vocabulary).

## Validate

```bash
python3 -m venv .venv && . .venv/bin/activate
pip install -r scripts/requirements.txt
python3 scripts/validate.py        # all 8 profiles
```

Profiles 3-8: every valid fixture conforms, every invalid one fails (closed shapes).
Profiles 1-2: the shape sets are checked for well-formed SHACL Turtle (their
valid/invalid conformance suites live with the PS1 reference implementations).

Apache-2.0.
