# frozen_string_literal: true
require_relative "lib/vv/slo/version"

Gem::Specification.new do |s|
  s.name        = "vv-slo"
  s.version     = Vv::Slo::VERSION
  s.authors     = ["Eric Laquer"]
  s.summary     = "Machine-readable SLOs, observability contracts, and runbooks with HITL gates"
  s.description = "Reliability as enforceable spec: an SLO a pipeline can query, an error " \
                  "budget wired as a deployment gate with a distinct rung for agent-generated " \
                  "changes, a CI-validated observability contract, and a runbook gradient whose " \
                  "human-approval gate sits at irreversibility x blast radius -- never at model confidence."
  s.required_ruby_version = ">= 3.1"
  s.files       = Dir["lib/**/*.rb", "README.md", "docs/**/*"]
  s.require_paths = ["lib"]
  s.add_development_dependency "rspec", "~> 3.13"
end
