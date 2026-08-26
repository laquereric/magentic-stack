# frozen_string_literal: true
require_relative "lib/mmg/adr/version"
Gem::Specification.new do |s|
  s.name        = "mmg-adr"
  s.version     = Mmg::Adr::VERSION
  s.summary     = "ADR-as-spec -- architecture decision records as machine-readable state, with an AR ledger and a grounded graph."
  s.description = "An architectural rule an agent never reads is operationally dead. mmg-adr parses ADR " \
                  "files with YAML frontmatter into an ActiveRecord ledger (proposed -> accepted -> " \
                  "superseded, immutable once accepted) and projects their attributes into a GROUNDED " \
                  "named graph via mmg-graph, so the decision set is queryable: which decisions govern a " \
                  "path, which name no enforcing mechanism, and which point at code that has moved."
  s.authors     = ["Eric Laquer"]
  s.license     = "Apache-2.0"
  s.files       = Dir["lib/**/*", "app/**/*", "README.md", "LICENSE"]
  s.required_ruby_version = ">= 3.3"
  s.add_dependency "rails", ">= 8.0"
end
