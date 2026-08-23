# frozen_string_literal: true
require_relative "lib/vv/docker_swap/version"

Gem::Specification.new do |s|
  s.name        = "vv-docker-swap"
  s.version     = Vv::DockerSwap::VERSION
  s.authors     = ["Eric Laquer"]
  s.license     = "Apache-2.0"
  s.summary     = "Layer sharing for closely related Rails service images, as checkable rules"
  s.description = "Closely related Rails services should swap in ONE immutable common parent " \
                  "image so Docker stores the base and common-bundle layers once. This gem " \
                  "models the design choice, the two-part sharing invariant that fails " \
                  "silently (identical digest-pinned parent AND identically resolved common " \
                  "gems), the build rules that decide whether the cache and the layers survive, " \
                  "the layer-union arithmetic that keeps summed image sizes from double-counting " \
                  "shared bytes, and the caveat that this buys disk and bandwidth -- not RAM."
  s.required_ruby_version = ">= 3.1"
  s.files       = Dir["lib/**/*.rb", "README.md", "LICENSE", "docs/**/*"]
  s.require_paths = ["lib"]
  s.add_development_dependency "rspec", "~> 3.13"
end
