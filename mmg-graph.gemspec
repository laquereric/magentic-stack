# frozen_string_literal: true
require_relative "lib/mmg/graph/version"
Gem::Specification.new do |s|
  s.name        = "mmg-graph"
  s.version     = Mmg::Graph::VERSION
  s.summary     = "Wrapper around the Rust graph DB (Oxigraph) SPARQL interface -- publish/query/update; federation anticipated."
  s.description = "ONE place MM talks to the Rust graph DB (Oxigraph) over its HTTP SPARQL interface -- " \
                  "publish (INSERT DATA to a named graph), query (SELECT), update (SPARQL UPDATE) -- instead " \
                  "of every gem hand-rolling Net::HTTP. Anticipates Manus's FEDERATED graph DB (multi-store / " \
                  "SPARQL SERVICE across endpoints) as a seam that is intentionally NOT implemented yet. KISS."
  s.authors     = ["Eric Laquer"]
  s.files       = Dir["lib/**/*", "app/**/*", "README.md"]
  s.required_ruby_version = ">= 3.3"
  s.add_dependency "rails", ">= 8.0"
end
