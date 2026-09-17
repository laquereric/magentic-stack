# frozen_string_literal: true

require_relative "lib/vv/figma/version"

# ADR 0038: this repo is CLOSED. homepage must be magentic-stack.
# Origin: laquereric/vv-figma (standalone private copy, non-authoritative).
Gem::Specification.new do |s|
  s.name        = "vv-figma"
  s.version     = Vv::Figma::VERSION
  s.summary     = "Figma Plugin API + REST boundary for Magentic"
  s.description = "Never-raise Figma boundary: one browser load wrapping " \
                  "the Plugin API and Embed, plus a Ruby REST client " \
                  "and OAuth 2.0. Editor.js calls the high-level surface; " \
                  "this gem owns every Figma-specific call. Credentials are " \
                  "read from ENV and never stored here. Private; not pushed " \
                  "to rubygems.org."
  s.authors     = ["Eric Laquer"]
  s.email       = ["eric@magenticmarket.ai"]
  s.homepage    = "https://github.com/laquereric/magentic-stack"
  s.files       = Dir["lib/**/*", "public/**/*", "README.md", "LICENSE", "docs/**/*"]
  s.require_paths = ["lib"]
  s.required_ruby_version = ">= 3.2"
  s.license     = "Nonstandard"
  s.metadata = {
    "allowed_push_host" => "none",
    "source_code_uri" => "https://github.com/laquereric/magentic-stack/tree/main/gems/vv-figma",
    "rubygems_mfa_required" => "true"
  }
end
