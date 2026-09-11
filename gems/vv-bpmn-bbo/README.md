# vv-bpmn-bbo

Private Rails engine. **Schema only.** BPMN 2.0 (ISO/IEC 19510 Chapter 10)
via BBO 1.0.0 as the vocabulary; ordinary ActiveRecord as the shape.

Not on rubygems.org. No XML importer. Graph and rag follow these rows;
they do not mint identity.

## Decisions

| | |
|---|---|
| Table prefix | `bpmn_bbo_` |
| Run tables | `bpmn_bbo_run_*` (explicit `self.table_name`) |
| First `ar_class` | `Vv::Base::Actor` |
| Host `ApplicationRecord` | not defined here |
| `Vv::Base::Flow` | not this gem |

## Install

This gem lives in magentic-stack and has no other home (ADR 0038). The
standalone `laquereric/vv-bpmn-bbo` repo it started in is **archived**:
readable and cloneable so history survives, but not where it is
consumed from, and not where changes go.

In this repo it is a path gem, already in the root `Gemfile`:

```ruby
gem "vv-bpmn-bbo", path: "gems/vv-bpmn-bbo"
```

Downstream consumers resolve it from the monorepo, one clone serving
many gems:

```ruby
gem "vv-bpmn-bbo", git: "https://github.com/laquereric/magentic-stack.git",
    glob: "gems/vv-bpmn-bbo/*.gemspec", ref: "<sha>"
```

Host runs the engine migrations. Then:

```ruby
Vv::BpmnBbo.seed_datatypes
# => { ok: true, seeded: Integer }
```

## Specs

```
bundle exec rspec
```

Temp SQLite in process. Plants the acceptance in
`magentic-stack/docs/architecture/plan_vv-bpmn-bbo.md` §19.
