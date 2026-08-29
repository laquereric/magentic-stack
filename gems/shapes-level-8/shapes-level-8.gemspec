# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name        = "shapes-level-8"
  s.version     = "0.0.0"
  s.summary     = "OSI Level 8 protocol-profile shapes and reusable vocabulary"
  s.description = "Packaging home for versioned protocol-profile shapes whose " \
                  "validity does not depend on one application's routes, persistence, " \
                  "adapter, or deployment. Empty of TTL in step 4. Rails-free: " \
                  "validators and codegen run standalone in CI."
  s.authors     = ["Eric Laquer"]
  s.license     = "Nonstandard"
  s.files       = Dir["lib/**/*", "README.md", "LICENSE", "bundles/**/*"]
  s.require_paths = ["lib"]
  s.required_ruby_version = ">= 3.2"
  # Rails-free by construction. Must not depend on shapes-application
  # (enforced by check_shape_gem_deps.py).
end
