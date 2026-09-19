# frozen_string_literal: true

require_relative "lib/vv/frame/version"

# Private. Not pushed to rubygems.org.
Gem::Specification.new do |s|
  s.name        = "vv-frame"
  s.version     = Vv::Frame::VERSION
  s.summary     = "The shared trajectory: the frame, its decisions, and a budgeted load for the smart zone."
  s.description = "Reads an Open Knowledge Format bundle of one frame document " \
                  "and its architecture-decision concepts, and answers structural " \
                  "questions over it: which decisions govern this path, which " \
                  "gates enforce them, where a decision sits on the frame's axes, " \
                  "and whether that placement is legal. Assembles the trajectory " \
                  "four parties share -- development-time agents, production-time " \
                  "agents, developers, users -- and packs it into the sharp part " \
                  "of a context window, verbatim, naming whatever did not fit. " \
                  "Never raises at the boundary. Does not summarise and does not " \
                  "rank. No runtime dependencies."
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
