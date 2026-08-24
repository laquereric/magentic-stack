# frozen_string_literal: true
require_relative "lib/vv/blob/version"

Gem::Specification.new do |s|
  s.name        = "vv-blob"
  s.version     = Vv::Blob::VERSION
  s.summary     = "Content-addressed blob storage in SQLite"
  s.description = "Blob storage in a SQLite database, addressed by sha256 digest. " \
                  "The digest is the key: put is idempotent, and a name cannot drift " \
                  "from what it names. Never raises across the boundary."
  s.authors     = ["Eric Laquer"]
  s.files       = Dir["lib/**/*", "README.md", "LICENSE"]
  s.require_paths = ["lib"]
  s.required_ruby_version = ">= 3.2"
  s.license     = "Nonstandard"
  s.add_dependency "sqlite3", ">= 2.1"
end
