# vv-per-site  (PRIVATE)

Rails engine that stores an [OKF](https://github.com/) docs tree in an
ActiveRecord **ancestry hierarchy**, then lets a **particular site** register
Call-To-Action leaves on that tree.

Stewardship Intelligence Cloud (SIC) authors the knowledge as OKF markdown
in `docs/`. A web market will be built from thousands of these trees. What
this gem stores is the **per-site** data needed to guide an **anonymous
user**, question by question, to a CTA that *this* site registered.

```
SIC docs/  ──seed──►  data/seed/docs/*.yml  ──load──►  vv_per_site_okf_nodes
                                                         (ancestry tree)
                                                              │
                                                              │ site binds
                                                              ▼
                                                       vv_per_site_ctas
```

Internal nodes are the questions along the way (folders, documents,
heading-sections). Leaves marked `cta_leaf` — a persona's "Needs next",
an organization's "Entry point", an explicit CTA section — are what a
site binds an action to (calendar, form, download, URL).

## Models

| class | table | role |
|---|---|---|
| `Vv::PerSite::OkfNode` | `vv_per_site_okf_nodes` | OKF tree. `has_ancestry`. |
| `Vv::PerSite::Site` | `vv_per_site_sites` | A particular site in the market. |
| `Vv::PerSite::Cta` | `vv_per_site_ctas` | That site's action on one leaf. |

Models inherit `Vv::PerSite::Record`, **not** the host's `ApplicationRecord`.
This is an isolated engine (`isolate_namespace Vv::PerSite`). Hosts run the
engine migrations; do not create tables from an initializer.

```ruby
site = Vv::PerSite::Site.create!(
  key: "wheat-stewardship",
  name: "Wheat Stewardship",
  host: "wheat.example",
  bundle_key: "stewardship-intelligence"
)

leaf = Vv::PerSite::OkfNode.in_bundle(site.bundle_key)
                           .cta_leaves
                           .find_by!(okf_path: "generated/personas.md#the-builder")

site.ctas.create!(
  okf_node: leaf,
  key: "builder-primer",
  title: "Request the technical primer",
  action_kind: "calendar",
  payload: { event: "discovery" }
)

guide = site.guide
step  = guide.root           # { ok:, node:, options:, cta: }
step  = guide.choose("index.md", "generated")
step  = guide.at("generated/personas.md#the-builder")
step[:cta]                   # the site's registered CTA, or nil
```

Never-raise at the service boundary: `{ ok: true, … }` or
`{ ok: false, reason:, because: }`.

## CPCP seam

`Vv::PerSite::Cpcp.register!` projects the guide onto `POST /_cpcp/rpc`
(model `PerSite`), so an agent walks the same questions an anonymous
visitor walks. The engine calls it `after_initialize`; it is a silent
no-op (`{ ok: false, reason: :cpcp_absent }`) when rails-cpcp is absent.
Nodes and CTAs cross as plain hashes — never AR objects.

| operation | direction | params |
|---|---|---|
| `persite.guide.root` | pull | `site_key` |
| `persite.guide.at` | pull | `site_key`, `okf_path` |
| `persite.guide.choose` | pull | `site_key`, `from_path`, `child_path` |
| `persite.sites.list` | pull | — |
| `persite.leaves.list` | pull | `bundle_key`, optional `site_key` adds each leaf's binding |
| `persite.site.register` | push | `operationId`, `key`, `name`, `bundle_key`, optional `host` |
| `persite.cta.register` | push | `operationId`, `site_key`, `okf_path`, `key`, `title`, `action_kind`, optional `payload` |
| `persite.cta.remove` | push | `operationId`, `site_key`, `okf_path` |

Pushes require `operationId` (enforced by the dispatcher, replayed on
retry). `cta.register` refuses `not_a_cta_leaf` when the path is not a
leaf; `site.register` re-points the site when the key already exists.

## SIC: convert docs and load AR

From the SIC repo root, with this gem in the Gemfile:

```ruby
# Path gem in magentic-stack (ADR 0038):
gem "vv-per-site", path: "gems/vv-per-site"
```

```
bundle exec rake vv_per_site:okf:sync
```

That is the one-shot. It:

1. Reads `docs/` (OKF markdown + folders).
2. Writes `data/seed/docs/**/*.yml` — one YAML file per node, parent
   before child, attributes matching the AR columns. This is the same
   shape Rails uses to seed AR databases (`db/seeds.rb` loads YAML).
3. Upserts those YAML records into `vv_per_site_okf_nodes`.

Split steps:

```
bundle exec rake vv_per_site:okf:seed     # docs/ → data/seed/docs
bundle exec rake vv_per_site:okf:load     # data/seed/docs → AR
bundle exec rake vv_per_site:okf:import   # docs/ → AR, skip YAML
```

ENV overrides: `DOCS`, `SEED`, `BUNDLE`, `DATABASE_URL`.

Without a Rails host, the tasks boot their own SQLite at
`tmp/vv_per_site.sqlite3`. A host that mounts the engine uses its own
`environment` task and its own database.

A Rails host seeds with:

```ruby
# db/seeds.rb
Vv::PerSite::Engine.load_seed
# or
Vv::PerSite.load_seed(seed_root: Rails.root.join("data/seed/docs"))
```

## Seed layout

```
data/seed/docs/
  _manifest.yml                      # load order
  index.yml                          # bundle root (docs/index.md)
  log.yml
  from_human/
    _folder.yml
    foundations.yml
    vision.yml
  generated/
    _folder.yml
    personas.yml
    personas/
      the-builder.yml                # heading section / CTA leaf
      the-community-steward.yml
```

Each YAML document is a hash of `OkfNode` attributes, including
`okf_path` and `parent_okf_path` so the ancestry chain can be rebuilt
without numeric ids. (`path` is reserved by the ancestry gem.)

## Install in a Rails host

```ruby
# Path gem in magentic-stack (ADR 0038):
gem "vv-per-site", path: "gems/vv-per-site"
```

```
bundle exec rails db:migrate
```

## Specs

```
bundle exec rspec
```

Temp SQLite in process. No host app required.
