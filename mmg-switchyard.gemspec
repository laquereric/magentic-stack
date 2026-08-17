# frozen_string_literal: true
require_relative "lib/mmg/switchyard/version"
Gem::Specification.new do |s|
  s.name = "mmg-switchyard"
  s.version = Mmg::Switchyard::VERSION
  s.summary = "threedot's LLM-assistance plane via NVIDIA Switchyard (dev + runtime); CID-Config<->Switchyard contract, local|remote routing, OTEL via mmg-observe."
  s.authors = ["CBI Business Transactions, LLC"]
  s.license = "LicenseRef-DataYoursSoftwareMine-1.0"
  s.files = Dir["lib/**/*", "docs/**/*", "README.md", "LICENSE"]
  s.required_ruby_version = ">= 3.1"
end
