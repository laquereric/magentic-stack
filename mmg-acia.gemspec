# frozen_string_literal: true

require_relative "lib/mmg/acia/version"

Gem::Specification.new do |s|
  s.name        = "mmg-acia"
  s.version     = Mmg::Acia::VERSION
  s.summary     = "ACIA core model: the ACIA tree, its markdown materialization, and its graph projection -- extracted from mmg-sal (epic_65)."
  s.description = "CORE substrate primitive (epic_65 ACIA Core Model). The ACIA tree as an AR ancestry hierarchy " \
                  "(Mmg::Acia::Node), the host-agnostic node-tree BUILDERS (Mmg::Acia::Tree -- the 'ACIA OUT' of an " \
                  "operation), the Markdown MATERIALIZATION (Mmg::Acia::Markdown -- durable .md objects), and the " \
                  "graph projection + mm: references (Mmg::Acia::Graph, urn:mm:vocab/acia#). SAL and the host gems " \
                  "(mmg-tmux/mmg-web) DELIVER an ACIA-based UX on top of this core; LLM consumption of ACIA trees is " \
                  "a separable concern. Operations become ACIA IN -> LLM -> ACIA OUT -> [tmux | web]."
  s.authors     = ["MagenticMarket"]
  s.license     = "MIT"
  s.files       = Dir["lib/**/*", "app/**/*", "db/**/*", "bin/**/*", "docs/adr/**/*", "README.md"]
  s.require_paths = ["lib"]
  s.required_ruby_version = ">= 3.3"

  s.add_dependency "rails", ">= 8.0"
  s.add_dependency "ancestry"   # Mmg::Acia::Node: materialized-path hierarchy for the ACIA tree
end
