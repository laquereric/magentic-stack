# tooling/

Developer-environment and CI tooling: local setup, linters, SBOM generation,
SHACL runners, and the scripts invoked by [`../.github/workflows/`](../.github/workflows/).

`bin/sweep` is the host checker+plant sweep that must be green to push
`main` (row 114). `bin/install-hooks` sets `core.hooksPath` to
[`githooks/`](githooks/).
