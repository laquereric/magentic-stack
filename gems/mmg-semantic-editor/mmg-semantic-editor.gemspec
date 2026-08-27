# frozen_string_literal: true

require_relative "lib/mmg/semantic_editor/version"

Gem::Specification.new do |spec|
  spec.name = "mmg-semantic-editor"
  spec.version = Mmg::SemanticEditor::VERSION
  spec.authors = ["Eric Laquer"]
  spec.email = ["LaquerEric@gmail.com"]

  spec.summary = "Edit an ACIA document that stands for several records; decompose the result into simultaneous edits."
  spec.description = <<~DESC
    A headless semantic editor. It takes an ACIA tree whose nodes carry canonical
    ids and disclosure tiers, offers a prose view of a Frame and what it carries
    (Meanings, Clarifications), and turns an edited tree back into the set of
    writes it implies -- grouped by target structure and offered whole or not at
    all. Knows nothing about HTTP, the board, or any particular store.
  DESC

  spec.homepage = "https://github.com/laquereric/magentic-stack"
  spec.license = "Apache-2.0"
  spec.required_ruby_version = ">= 3.1"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage

  spec.files = Dir["lib/**/*.rb", "README.md", "LICENSE"]
  spec.require_paths = ["lib"]
end
