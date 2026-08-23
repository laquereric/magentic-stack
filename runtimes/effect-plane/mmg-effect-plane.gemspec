# frozen_string_literal: true
require_relative "lib/mmg/effect_plane/version"

Gem::Specification.new do |s|
  s.name        = "mmg-effect-plane"
  s.version     = Mmg::EffectPlane::VERSION
  s.authors     = ["Eric Laquer"]
  s.license     = "Apache-2.0"
  s.summary     = "Plane C: where an effect lands, how durable it is, and what rollback means"
  s.description = "The Magentic Stack deployment effect plane. Plane A (execution registration) " \
                  "is reversible by teardown; Plane B (domain truth) is append-only; Plane C is " \
                  "materialized effect state -- which immutable materialization is active and how " \
                  "it was produced. Rollback here is legitimate ONLY as an explicit fork-and-activate " \
                  "that appends a fact, never as a rewind of domain truth. Classifies an effect " \
                  "across the five pipeline stages (source, oci_image, container_layer, " \
                  "snapshot_image, host_volume), validates the conjunctive C1-C9 snapshot contract, " \
                  "and rules that a bare `docker commit` is not an admissible release path. Contains " \
                  "no Docker client, no signer, and no policy engine: it validates evidence."
  s.required_ruby_version = ">= 3.1"
  s.files       = Dir["lib/**/*.rb", "README.md", "LICENSE", "docs/**/*"]
  s.require_paths = ["lib"]
  s.add_development_dependency "rspec", "~> 3.13"
end
