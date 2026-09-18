# frozen_string_literal: true

require_relative "lib/vv/per_site/version"

# ADR 0038: this repo is CLOSED. homepage must be magentic-stack.
# Origin: laquereric/vv-per-site (standalone private copy, non-authoritative).
Gem::Specification.new do |s|
  s.name        = "vv-per-site"
  s.version     = Vv::PerSite::VERSION
  s.summary     = "Rails engine: hierarchical OKF stored in AR, per-site CTA leaves."
  s.description = "Stores an Open Knowledge File (OKF) docs tree in an ActiveRecord " \
                  "ancestry hierarchy so an anonymous visitor can be guided, question " \
                  "by question, to a Call-To-Action registered by a particular site. " \
                  "SIC (or any OKF author) converts docs/ into data/seed/docs and loads " \
                  "them the way Rails seeds AR databases."
  s.authors     = ["Eric Laquer"]
  s.email       = ["eric@magenticmarket.ai"]
  s.homepage    = "https://github.com/laquereric/magentic-stack"
  s.files       = Dir[
    "lib/**/*",
    "app/**/*",
    "db/**/*",
    "tasks/**/*",
    "data/**/*",
    "README.md",
    "LICENSE",
    "CHANGELOG.md",
    "*.gemspec"
  ]
  s.require_paths = ["lib"]
  s.required_ruby_version = ">= 3.2"
  s.license = "Nonstandard"
  s.metadata = {
    "allowed_push_host" => "none",
    "source_code_uri" => "https://github.com/laquereric/magentic-stack/tree/main/gems/vv-per-site",
    "rubygems_mfa_required" => "true"
  }

  s.add_dependency "activerecord", ">= 7.0"
  s.add_dependency "activesupport", ">= 7.0"
  s.add_dependency "railties", ">= 7.0"
  s.add_dependency "ancestry", ">= 4.0"

  s.add_development_dependency "sqlite3", ">= 1.4"
  s.add_development_dependency "rspec", "~> 3.13"
  s.add_development_dependency "rake", "~> 13.0"
end
