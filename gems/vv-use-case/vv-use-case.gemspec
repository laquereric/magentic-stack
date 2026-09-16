# frozen_string_literal: true

require_relative "lib/vv/use_case/version"

Gem::Specification.new do |spec|
  spec.name    = "vv-use-case"
  spec.version = Vv::UseCase::VERSION
  spec.authors = ["MagenticMarket contributors"]
  spec.email   = ["substrate@magenticmarket.ai"]

  spec.summary = "Use-Case 3.0 Essentials: Fabric plugin, model extract, one-way Miro share."
  spec.description = <<~DESC.strip
    Light Use-Case Modeling on a Fabric board: actors, use-case ellipses,
    system boundary, associations. Extract sharedai.uc.essentials.v1 from
    Fabric JSON. Map onto vv-miro Effects. Overlay consumes this gem.
    Soft-depends on vv-miro. Does not depend on vv-perch.
    Private. Not on rubygems.org.
  DESC

  spec.homepage = "https://github.com/laquereric/magentic-stack"
  spec.license  = "MIT"
  spec.required_ruby_version = ">= 3.1"

  spec.metadata = {
    "allowed_push_host" => "none",
    "source_code_uri" => "https://github.com/laquereric/magentic-stack/tree/main/gems/vv-use-case",
    "rubygems_mfa_required" => "true"
  }

  spec.files = Dir["lib/**/*.rb", "public/**/*", "README.md", "LICENSE", "VERSION"]
  spec.require_paths = ["lib"]
end
