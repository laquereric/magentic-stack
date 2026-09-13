# upstreams/manifests/  🟡 FOLLOW THEM

One pin record per upstream. A pin record is the release-integrity contract for a
followed dependency: it fixes the revision and captures everything needed to
advance or roll back on evidence.

Each `*.pin.json` records: source URL, pinned revision *or* version, license,
SBOM ref, provenance, conformance status, and a rollback target. Git-submodule
pins omit `kind` (see `nooa.pin.json`, `nemo-switchyard.pin.json`). PyPI pins
set `"kind": "pypi"` (`pydantic.pin.json`); data pins `"kind": "data"`
(`genai-prices.pin.json`); declared git pins without a gitlink yet
`"kind": "declared"` (`monty.pin.json`). Gate 4 skips gitlink/fetch for
those kinds.

> Revisions below are placeholders (`PENDING`) until the first real pin is taken.
