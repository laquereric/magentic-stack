# vv-dependency-orch

One identity, many placements. Digest-addressed resources: what
depends on them, and what breaks if one moves.

Never boots Rails. Soft-depends on `vv-code-search` (absence is
`not_indexed`, not a bundle failure).

```ruby
require "vv-dependency-orch"
Vv::DependencyOrch.inventory(roots: ["."])
Vv::DependencyOrch.blast_radius(graph, "sha256:…")
Vv::DependencyOrch.drift(graph)
Vv::DependencyOrch.deploy(root: ".")
Vv::DependencyOrch.deploy_ready(root: ".")
```

`.cpcp/package.json` is compile and runtime protocol. `.cpcp/deploy.json`
(`kind: cpcp-deploy`) is local_deploy / remote_deploy image and blob SHAs.
This gem reads the latter; it does not re-parse Dockerfiles or FLOOR.json.

Rake (POC entry; no domain conditionals in tasks):

```ruby
require "vv/dependency_orch/tasks"
Vv::DependencyOrch::Tasks.install
```

Plan: [`docs/architecture/plan_vv_dependency_orch.md`](../../docs/architecture/plan_vv_dependency_orch.md).
Private. `allowed_push_host: none`.
