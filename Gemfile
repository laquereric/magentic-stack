# frozen_string_literal: true
# Ruby workspace for the OWN IT / OFFICIAL Rails components.
# Path gems are activated as each component is subtree-imported (see docs/SOURCE_STATUS.md).
source "https://rubygems.org"

# gems/ -- the owned contract layer (ADR 0001, ADR 0002).
gem "rails-cpcp",          path: "gems/rails-cpcp"
gem "rails-osi-level-8",   path: "gems/rails-osi-level-8"
gem "mmg-adr",             path: "gems/mmg-adr"
gem "mmg-graph",           path: "gems/mmg-graph"

# The monorepo is CLOSED (ADR 0038): these gems have no other home, so this
# workspace is the only place they are built and their specs are the only
# proof they work. Every gemspec under gems/ belongs here -- a gem that is the
# sole copy and is never loaded is an unverified single point of truth.
gem "mmg-acia",            path: "gems/mmg-acia"
gem "mmg-acia-crud",       path: "gems/mmg-acia-crud"
gem "mmg-blob",            path: "gems/mmg-blob"
gem "mmg-semantic-editor", path: "gems/mmg-semantic-editor"
gem "vv-base",             path: "gems/vv-base"
gem "vv-blob",             path: "gems/vv-blob"
gem "vv-graph",            path: "gems/vv-graph"
gem "vv-html-components",  path: "gems/vv-html-components"

# Phase 0 ADR 0001 imports (OWN IT tooling / runtimes -- see docs/SOURCE_STATUS.md)
gem "vv-docker-swap",      path: "tooling/docker-swap"
gem "mmg-effect-plane",    path: "runtimes/effect-plane"
gem "vv-slo",              path: "tooling/slo"

# NOTE: rails-threedot-back (plugins/threedot-back) and mmg-switchyard
# (plugins/switchyard-routing) were listed here but plugins/ no longer exists --
# it was removed in the one-home-per-gem restructure. Re-add them from their real
# path if they come back into the tree; a path gem pointing at nothing fails the
# whole bundle, so they are not left as dead entries.

# Gems without their own Gemfile run their specs on this workspace (bin/spec-all).
gem "rspec", "~> 3.13"
