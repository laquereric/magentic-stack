# frozen_string_literal: true

require_relative "lib/vv/decision_object/roi/version"

Gem::Specification.new do |s|
  s.name        = "vv-roi"
  s.version     = Vv::DecisionObject::Roi::VERSION
  s.summary     = "Prices the options a decision already declares"
  s.description = "Never-raise Ruby library that makes consequence " \
                  "computable for vv-decision-object: human-declared stakes " \
                  "per option, a risk appetite kept separate from both " \
                  "measurement and constraint, expected value and net option " \
                  "value against the cost of holding, a veto that can only " \
                  "ever be more conservative than the threshold layer, " \
                  "realized value for the feedback layer, and a portfolio " \
                  "view of the options a system has sold."
  s.authors     = ["Eric Laquer"]
  s.email       = ["eric@magenticmarket.ai"]
  s.homepage    = "https://github.com/laquereric/magentic-stack"
  s.files       = Dir["lib/**/*", "README.md", "LICENSE", "docs/**/*"]
                     .reject { |f| File.basename(f) == ".DS_Store" }
  s.require_paths = ["lib"]
  s.required_ruby_version = ">= 3.2"
  s.license     = "Nonstandard"
  s.metadata = {
    "allowed_push_host" => "none",
    "source_code_uri" => "https://github.com/laquereric/magentic-stack/tree/main/gems/vv-roi",
    "rubygems_mfa_required" => "true"
  }
end
