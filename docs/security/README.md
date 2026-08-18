# Security

## Posture

- **OS-level isolation** for any agent that can execute code (MIND container).
  This follows upstream NOOA guidance and is a hard requirement, not a default.
- **Evidence paths are non-bypassable.** MIND cannot reach Effect without passing
  the `/_cpcp` seam and its SHACL validation.
- **Closed SHACL shapes.** The protocol is open; the validation shapes are closed,
  so “open ecosystem, closed shapes” keeps trust decisions ours.
- **Pinned upstreams.** No forks; every pin carries an SBOM, provenance, and a
  rollback target.

## Privacy

Offline boundary tests verify “no prompt leaves your device” for SwitchYard.offline.
Telemetry is explicit opt-in and governed by a data-use charter.

## Disclosure

Report suspected vulnerabilities privately to the maintainer. Do not open a public
issue for security reports. Adversarial reviews of boundaries and validation are
welcome and credited.
