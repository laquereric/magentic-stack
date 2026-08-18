# integration-tests/

Validation and governance tests that cross tier boundaries. These back the pilot
release gates.

Covers:
- **boundary conformance** — MIND cannot reach Effect except through `/_cpcp`.
- **SHACL validation** — closed-shape validation of example calls.
- **attestation + policy digest** — offers carry verifiable metadata.
- **reversible pins** — an upstream pin can be advanced and rolled back.
- **offline boundary verification** — “no prompt leaves your device” for SwitchYard.offline.
- **governance evidence export**.
