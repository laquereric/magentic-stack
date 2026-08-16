# frozen_string_literal: true
require_relative "lib/rails_cpcp/version"

Gem::Specification.new do |s|
  s.name        = "rails-cpcp"
  s.version     = RailsCpcp::VERSION
  s.summary     = "Additive Rails engine projecting Rails resources as CID-grounded JSON-RPC-LD (CPCP) PULL/PUSH operations for a mandatory two-pod deployment."
  s.description = "rails-cpcp lets a conventional Rails monolith ALSO deploy as a CPCP (PubSubStandard_1 / JSON-RPC-LD-PS1) pod. Mount the engine at /_cpcp, declare projections of your models, and get a CID at /_cpcp/cid.json plus a never-raise JSON-RPC-LD PULL/PUSH surface. Ships a thin FRONT pod and a Kamal two-pod deploy template (Rails=BACK + distinct FRONT)."
  s.authors     = ["Eric Laquer"]
  s.homepage    = "https://github.com/laquereric/rails-cpcp"
  s.license     = "Apache-2.0"
  s.files       = Dir["lib/**/*", "app/**/*", "config/**/*", "front/**/*", "deploy/**/*", "README.md", "LICENSE"]
  s.required_ruby_version = ">= 3.1"
  s.add_dependency "rails", ">= 7.0"
  s.metadata = {
    "source_code_uri" => "https://github.com/laquereric/rails-cpcp",
    "rubygems_mfa_required" => "true"
  }
end
