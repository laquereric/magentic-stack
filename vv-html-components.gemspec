# frozen_string_literal: true

require_relative "lib/vv/html/components/version"

Gem::Specification.new do |s|
  s.name        = "vv-html-components"
  s.version     = Vv::Html::Components::VERSION
  s.summary     = "Light-DOM enhancement layer for OSI L8 Profile 9 ACIA pages."
  s.description = "One static JavaScript include that upgrades already-rendered " \
                  "Profile 9 markup via attribute-selected light-DOM adapters. " \
                  "No runtime network, no shadow DOM on visual components."
  s.authors     = ["CBI Business Transactions, LLC"]
  s.license     = "LicenseRef-DataYoursSoftwareMine-1.0"
  s.files       = Dir[
    "lib/**/*",
    "dist/**/*",
    "docs/**/*",
    "test-fixtures/**/*",
    "README.md",
    "CHANGELOG.md",
    "LICENSE",
    "*.gemspec"
  ]
  s.require_paths = ["lib"]
  s.required_ruby_version = ">= 3.2"
end
