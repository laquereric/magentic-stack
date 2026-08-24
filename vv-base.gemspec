# frozen_string_literal: true

require_relative "lib/vv/base/version"

Gem::Specification.new do |s|
  s.name        = "vv-base"
  s.version     = Vv::Base::VERSION
  s.summary     = "Canonical AR homes for Actor/Persona/Journey/Flow/Mission/Vision."
  s.description = "Platform models that were sitting in mind-pod's app/models. " \
                  "Namespaced under Vv::Base; table names stay unprefixed. " \
                  "A gem does not own the host ApplicationRecord. " \
                  "LedgerPlaced.cross_boundary keeps private_local off the CPCP PULL boundary."
  s.authors     = ["MagenticMarket"]
  s.license     = "Nonstandard"
  s.files       = Dir["lib/**/*", "db/migrate/**/*", "README.md", "LICENSE", "*.gemspec"]
  s.require_paths = ["lib"]
  s.required_ruby_version = ">= 3.2"
  s.add_dependency "activerecord", ">= 7.0"
  s.add_dependency "activesupport", ">= 7.0"
  s.add_dependency "railties", ">= 7.0"
  s.add_development_dependency "sqlite3", ">= 1.4"
  s.add_development_dependency "rspec", "~> 3.13"
end
