# frozen_string_literal: true
require_relative "lib/mmg/blob/version"

Gem::Specification.new do |s|
  s.name        = "mmg-blob"
  s.version     = Mmg::Blob::VERSION
  s.summary     = "Blob storage at the boundary: thin-slice apps and LLM tool calls"
  s.description = "Exposes vv-blob content-addressed storage as CPCP operations " \
                  "(blob.put/get/stat/list) so a Rails slice and an LLM reach the " \
                  "same store through the same shape-gated seam."
  s.authors     = ["Eric Laquer"]
  s.files       = Dir["lib/**/*", "README.md", "LICENSE"]
  s.require_paths = ["lib"]
  s.required_ruby_version = ">= 3.2"
  s.license     = "Nonstandard"
  s.add_dependency "vv-blob", ">= 0.1.0"
  # base64 stopped being a DEFAULT gem in Ruby 3.4 and is now bundled, so a
  # bare require fails under bundler unless it is declared. The base image is
  # on 3.4.9, so this is not hypothetical.
  s.add_dependency "base64", "~> 0.2"
end
