# frozen_string_literal: true
require_relative "lib/app_oriented_translation/version"
Gem::Specification.new do |s|
  s.name        = "app-oriented-translation"
  s.version     = AppOrientedTranslation::VERSION
  s.summary     = "Oriented Translation - orientation, meaning clarification and stewardship translation on OSI L8."
  s.description = "Design source gem for Oriented Translation: a governed human surface over " \
                  "OSI Level 8 Profile 11 (Meaning). Carries mission/vision/personas as intent:* types, " \
                  "journeys as c4:Journey + ux:Flow, page mockups as Profile 9 ACIA trees, and the L8 " \
                  "modification proposals the design surfaced. Ships an additive Rails engine whose " \
                  "only job is ONE shared page shell for every Profile 9 surface. Private."
  s.authors     = ["CBI Business Transactions, LLC"]
  s.license     = "LicenseRef-DataYoursSoftwareMine-1.0"
  s.files       = Dir["lib/**/*", "app/**/*", "docs/**/*", "README.md", "LICENSE", "*.gemspec"]
  s.require_paths = ["lib"]
  s.required_ruby_version = ">= 3.2"
  s.add_dependency "actionview", ">= 8.0"
  s.add_dependency "railties", ">= 8.0"
end
