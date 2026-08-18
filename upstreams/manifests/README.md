# upstreams/manifests/  🟡 FOLLOW THEM

One pin record per upstream. A pin record is the release-integrity contract for a
followed dependency: it fixes the revision and captures everything needed to
advance or roll back on evidence.

Each `*.pin.json` records: source URL, pinned revision, license, SBOM ref,
provenance, conformance status, and a rollback target. See `nooa.pin.json` and
`nemo-switchyard.pin.json`.

> Revisions below are placeholders (`PENDING`) until the first real pin is taken.
