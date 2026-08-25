# frozen_string_literal: true

require_relative "lib/rails_osi_level_8/version"

Gem::Specification.new do |s|
  s.name        = "rails-osi-level-8"
  s.version     = RailsOsiLevel8::VERSION
  s.summary     = "OSI Level 8 cybernetic-interface grammar as a Rails engine - a semantic adapter atop CPCP (rails-cpcp)."
  s.description = "rails-osi-level-8 realizes the OSI Level 8 spec (Context=perception/PULL, Effect=action/PUSH; grounded JSON-LD + closed SHACL profile shapes; three-ledger discipline; Profiles 1-8) as an ADDITIVE Rails engine that decorates rails-cpcp - NOT a second RPC surface. /_cpcp stays the single public seam."
  s.authors     = ["CBI Business Transactions, LLC"]
  s.homepage    = "https://github.com/laquereric/rails-osi-level-8"
  s.license     = "Apache-2.0"
  s.files       = Dir[
    "lib/**/*",
    "db/**/*",
    "data/**/*",
    "docs/**/*",
    "spec/**/*",
    "README.md",
    "LICENSE",
    "*.gemspec"
  ]
  s.require_paths = ["lib"]
  s.required_ruby_version = ">= 3.2"
  s.add_dependency "rails", ">= 8.0"
  s.add_development_dependency "rspec", "~> 3.13"
end
