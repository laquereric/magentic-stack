# frozen_string_literal: true

require_relative "lib/vv/canvas/version"

Gem::Specification.new do |spec|
  spec.name    = "vv-canvas"
  spec.version = Vv::Canvas::VERSION
  spec.authors = ["MagenticMarket contributors"]
  spec.email   = ["substrate@magenticmarket.ai"]

  spec.summary = "Fabric canvas: digest-named versions, graph_iri refused, board accounts."
  spec.description = <<~DESC.strip
    Canvas support extracted from shared-ai-space-app. BlobGate, Boards, CPCP
    blob.* / board.*, Fabric 7.4.0 editor assets. Digest is the name.
    Private. Not on rubygems.org.
  DESC

  spec.homepage = "https://github.com/laquereric/magentic-stack"
  spec.license  = "MIT"
  spec.required_ruby_version = ">= 3.1"

  spec.metadata = {
    "allowed_push_host" => "none",
    "source_code_uri" => "https://github.com/laquereric/magentic-stack/tree/main/gems/vv-canvas",
    "rubygems_mfa_required" => "true"
  }

  spec.files = Dir["lib/**/*.rb", "public/**/*", "README.md", "LICENSE", "VERSION"]
  spec.require_paths = ["lib"]
end
