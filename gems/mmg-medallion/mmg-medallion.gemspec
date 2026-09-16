# frozen_string_literal: true

require_relative "lib/mmg/medallion/version"

# ADR 0038: this repo is CLOSED. Promoted here from magentic-market-ai as the
# M-home decision in docs/plans/medallion-memory-primitives.md -- magentic-stack is now
# canonical for this gem and the copy over there becomes stale. The gemspec
# named no homepage at all, which passes rule 2 only because it points nowhere;
# pointing home is the actual requirement, so it now does.
Gem::Specification.new do |s|
  s.name        = "mmg-medallion"
  s.version     = Mmg::Medallion::VERSION
  s.summary     = "Semantic Medallion — Bronze->Silver->Gold RDF projection plane (migrates/supersedes vv-medallion)."
  s.description = "The MagenticMarket CQRS projection plane, evolved semantic: Bronze->Silver->Gold " \
                  "layers over RDF triples. Migrates + supersedes vv-medallion (Flow registry, " \
                  "Conformer Bronze->Silver, Curator Silver->Gold, audit!). Composes with Mm::GraphMemory, " \
                  "Mmg::Curation, and SHACL. Storage stays separate (data plane); this owns projection. " \
                  "The generic BUILD engine: vv-medallion_memory may depend on this, never the reverse."
  s.authors     = ["MagenticMarket"]
  s.homepage    = "https://github.com/laquereric/magentic-stack"
  s.license     = "MIT"
  s.files       = Dir["lib/**/*", "app/**/*", "db/**/*", "docs/**/*", "spec/**/*", "README.md"]
  s.require_paths = ["lib"]
  s.required_ruby_version = ">= 3.3"
  s.metadata = {
    "allowed_push_host" => "none",
    "source_code_uri" => "https://github.com/laquereric/magentic-stack/tree/main/gems/mmg-medallion",
    "rubygems_mfa_required" => "true"
  }
end
