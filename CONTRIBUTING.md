# Contributing to The Magentic Stack

Thanks for your interest. This repository is the ownership-boundary map and
reference scaffold for the stack — please read [`README.md`](README.md) and
[`GOVERNANCE.md`](GOVERNANCE.md) first. The tree encodes an intentional boundary;
contributions must respect it.

## Before you start

- **Know the tier you are touching.** 🟢 OWN IT (`grammar/`, `gems/`,
  `runtimes/`), 🔵 OFFICIAL (`apps/`, `plugins/`), 🟡 FOLLOW THEM (`upstreams/`).
- **Contracts are authoritative.** If your change affects behavior at the
  boundary, it starts as a change to the SHACL shapes / normative profiles in
  `grammar/`, then flows into `gems/` and consumers — not the other way around.
- **Never edit `upstreams/` source.** Advance a pin via a recorded manifest
  update in `upstreams/manifests/` with SBOM, provenance, and a rollback target.

## Workflow

1. Open an issue describing the change and which tier/area it touches.
2. For any boundary/contract/pin change, add an ADR under `docs/adr/`.
3. Make the change; keep it inside a single tier where possible.
4. Ensure CI gates pass: SHACL conformance, SBOM, and integration tests.
5. Open a PR referencing the issue (and ADR, if any).

## Ground rules

- Small, boundary-respecting changes over sweeping ones.
- Every contract change ships with valid **and** invalid example calls.
- No secrets in the tree (`.env`, keys, tokens are git-ignored — keep it that way).
- By contributing you agree your contributions are licensed under Apache-2.0.

## Code of conduct

Be respectful and assume good faith. Adversarial design review of boundaries and
validation is welcome — that is how trust in the stack is earned.
