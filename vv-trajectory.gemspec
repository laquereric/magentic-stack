# frozen_string_literal: true

require_relative "lib/vv/trajectory/version"

# Private. Not pushed to rubygems.org.
Gem::Specification.new do |s|
  s.name        = "vv-trajectory"
  s.version     = Vv::Trajectory::VERSION
  s.summary     = "The path taken toward a slice's aim, recorded and measured."
  s.description = "Sits above perch and at the edge of the smart zone. Records a " \
                  "run as observed steps, never summarised; detects the dumb zone " \
                  "from the record rather than from length -- repetition, " \
                  "reasoning loops, drifted aims, exhausted budgets; measures a " \
                  "run against an oracle trajectory with deterministic metrics " \
                  "only (tool selection, argument accuracy, Kendall's tau, " \
                  "receipt verification); and reports the gradient between " \
                  "durable record and ephemeral prose, which is the quantity a " \
                  "reset raises. Calls no model. No runtime dependencies."
  s.authors     = ["MagenticMarket"]
  s.email       = ["substrate@magenticmarket.ai"]
  s.homepage    = "https://github.com/laquereric/coherent"
  s.license     = "MIT"
  s.files       = Dir["lib/**/*", "README.md", "LICENSE", "VERSION", "*.gemspec"]
  s.require_paths = ["lib"]
  s.required_ruby_version = ">= 3.2"
  s.metadata = {
    "allowed_push_host" => "none",
    "rubygems_mfa_required" => "true"
  }
  s.add_development_dependency "rake", ">= 13.0"
  s.add_development_dependency "rspec", "~> 3.13"
end
