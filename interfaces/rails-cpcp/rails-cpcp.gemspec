# frozen_string_literal: true
require_relative "lib/rails_cpcp/version"

Gem::Specification.new do |s|
  s.name        = "rails-cpcp"
  s.version     = RailsCpcp::VERSION
  s.summary     = "CPCP -- coordination-protocol-contract-package: the affordance a deterministic entity grants a non-deterministic one, as read access and write access over a typed Rails seam."
  s.description = "CPCP is coordination-protocol-contract-package. A deterministic system that lets a non-deterministic one in must be able to say afterwards what was done and on whose word, and the rules follow from that: never-raise envelopes, an operationId required on every write, a sole writer on the far side, and closed shapes owned by OSI Level 8. rails-cpcp is the Rails-side grant. Mount the engine at /_cpcp, declare projections of your models, and get read access (direction: :pull) and write access (direction: :push) over CID-grounded JSON-RPC-LD, plus a CID at /_cpcp/cid.json. Additive: the app stays a normal monolith and the same source also deploys as two pods (Rails=BACK + a distinct FRONT)."
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
