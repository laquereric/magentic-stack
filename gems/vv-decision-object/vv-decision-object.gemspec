# frozen_string_literal: true

require_relative "lib/vv/decision_object/version"

Gem::Specification.new do |s|
  s.name        = "vv-decision-object"
  s.version     = Vv::DecisionObject::VERSION
  s.summary     = "Decisions as durable, inspectable, governable objects"
  s.description = "Never-raise Ruby library for decision objects: the " \
                  "six-layer record (intent, constraint, signal, evaluation, " \
                  "commitment, feedback), Jev-shaped typed questions " \
                  "(Choice, Score, Noul) with calibrated confidence, DMN " \
                  "decision tables for the deterministic half, lifecycle " \
                  "governance, and an append-only decision trace."
  s.authors     = ["Eric Laquer"]
  s.email       = ["eric@magenticmarket.ai"]
  s.homepage    = "https://github.com/laquereric/magentic-stack"
  s.files       = Dir["lib/**/*", "README.md", "CHANGELOG.md", "LICENSE", "*.gemspec"]
                     .select { |f| File.file?(f) }
  s.require_paths = ["lib"]
  s.required_ruby_version = ">= 3.2"
  s.license     = "LicenseRef-Proprietary-CBI-1.0"
  s.metadata = {
    "allowed_push_host" => "none",
    "source_code_uri" => "https://github.com/laquereric/magentic-stack/tree/main/gems/vv-decision-object",
    "rubygems_mfa_required" => "true"
  }
  s.add_development_dependency "rake", ">= 13.0"
  s.add_development_dependency "rspec", "~> 3.13"
end
