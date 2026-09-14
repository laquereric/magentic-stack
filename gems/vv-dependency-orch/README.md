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
```

Rake (POC entry; no domain conditionals in tasks):

```ruby
require "vv/dependency_orch/tasks"
Vv::DependencyOrch::Tasks.install
```

Plan: [`docs/architecture/plan_vv_dependency_orch.md`](../../docs/architecture/plan_vv_dependency_orch.md).
Private. `allowed_push_host: none`.
