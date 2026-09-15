# frozen_string_literal: true

require_relative "lib/vv/perch/version"

# ADR 0038: closed. No gemspec under gems/ may name a laquereric/ repo
# other than magentic-stack.
Gem::Specification.new do |s|
  s.name        = "vv-perch"
  s.version     = Vv::Perch::VERSION
  s.summary     = "Relational grounding for Perch v2: slice, freeze ladder, orphan ledger."
  s.description = "Schema-only Rails engine. Table prefix perch_. " \
                  "Fifteen tables. No Effect Gate, no Effect Ledger, no signatures, " \
                  "no ranking. Throughput is released slices, never methods. " \
                  "Private; not pushed to rubygems.org. Dry::Monads is not a dependency."
  s.authors     = ["MagenticMarket"]
  s.email       = ["substrate@magenticmarket.ai"]
  s.homepage    = "https://github.com/laquereric/magentic-stack"
  s.license     = "MIT"
  s.files       = Dir["lib/**/*", "db/migrate/**/*", "README.md", "LICENSE", "VERSION", "*.gemspec"]
  s.require_paths = ["lib"]
  s.required_ruby_version = ">= 3.2"
  s.metadata = {
    "allowed_push_host" => "none",
    "source_code_uri" => "https://github.com/laquereric/magentic-stack/tree/main/gems/vv-perch",
    "rubygems_mfa_required" => "true"
  }
  s.add_dependency "activerecord", ">= 7.0"
  s.add_dependency "activesupport", ">= 7.0"
  s.add_dependency "railties", ">= 7.0"
  s.add_development_dependency "sqlite3", ">= 1.4"
  s.add_development_dependency "rspec", "~> 3.13"
  s.add_development_dependency "rake", ">= 13.0"
end
