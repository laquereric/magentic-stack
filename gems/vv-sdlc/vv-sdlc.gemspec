# frozen_string_literal: true

require_relative "lib/vv/sdlc/version"

Gem::Specification.new do |s|
  s.name        = "vv-sdlc"
  s.version     = Vv::Sdlc::VERSION
  s.summary     = "AI-in-SDLC process family on vv-bpmn-bbo. Token engine, not XML."
  s.description = "Seeds the AgentTask BPMN (agent 70% → independent reality test → " \
                  "mandatory human review by Vv::Base::Actor → observability). " \
                  "Agent-written tests are a step, not evidence. Private. " \
                  "Dry::Monads is not a dependency. CPCP bpmn.* lives on BACK, not here."
  s.authors     = ["MagenticMarket"]
  s.email       = ["substrate@magenticmarket.ai"]
  s.homepage    = "https://github.com/laquereric/magentic-stack"
  s.license     = "MIT"
  s.files       = Dir["lib/**/*", "README.md", "LICENSE", "*.gemspec"]
  s.require_paths = ["lib"]
  s.required_ruby_version = ">= 3.2"
  s.metadata = {
    "allowed_push_host" => "none",
    "source_code_uri" => "https://github.com/laquereric/magentic-stack/tree/main/gems/vv-sdlc",
    "rubygems_mfa_required" => "true"
  }
  s.add_dependency "vv-bpmn-bbo", ">= 0.1.0"
  s.add_dependency "activerecord", ">= 7.0"
  s.add_dependency "activesupport", ">= 7.0"
  s.add_development_dependency "sqlite3", ">= 1.4"
  s.add_development_dependency "rspec", "~> 3.13"
  s.add_development_dependency "rake", ">= 13.0"
end
