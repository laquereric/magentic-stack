# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name        = "shapes-application"
  s.version     = "0.0.0"
  s.summary     = "Application contract shapes, one family slot per application"
  s.description = "Packaging home for an application's accepted request/response " \
                  "contract and application-specific refinements of protocol shapes. " \
                  "A family, not a flat namespace: contracts live under " \
                  "contracts/<application-id>/. Empty of TTL in step 4. Rails-free."
  s.authors     = ["Eric Laquer"]
  s.license     = "Nonstandard"
  s.files       = Dir["lib/**/*", "README.md", "LICENSE", "contracts/**/*"]
  s.require_paths = ["lib"]
  s.required_ruby_version = ">= 3.2"
  # Rails-free by construction.
  # Application MAY depend on protocol. Protocol MUST NOT depend on application.
  s.add_dependency "shapes-level-8", "= 0.0.0"
end
