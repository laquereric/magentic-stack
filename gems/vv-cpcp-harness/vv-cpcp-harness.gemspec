# frozen_string_literal: true

require_relative "lib/vv/cpcp_harness/version"

Gem::Specification.new do |s|
  s.name        = "vv-cpcp-harness"
  s.version     = Vv::CpcpHarness::VERSION
  s.summary     = "Ruby bridge between an agent harness and CPCP"
  s.description = "Never-raise Ruby bridge between an agent tool surface and the " \
                  "Coordination Protocol Contract Package. A seam's published " \
                  "operations become tools (PULL reads, PUSH writes carrying an " \
                  "operationId); native tools adopt CPCP identity, faces, envelopes " \
                  "and stable refusal reasons. Reads both refusal forms and both " \
                  "signals, retries only where replay is safe, and journals every " \
                  "write with the session and human behind it."
  s.authors     = ["Eric Laquer"]
  s.email       = ["eric@magenticmarket.ai"]
  s.homepage    = "https://github.com/laquereric/magentic-stack"
  s.files       = Dir["lib/**/*", "exe/*", "cpcp/**/*", "README.md", "LICENSE", "docs/**/*"]
  s.bindir      = "exe"
  s.executables = ["vv-cpcp-harness-mcp"]
  s.require_paths = ["lib"]
  s.required_ruby_version = ">= 3.2"
  s.license     = "Nonstandard"
  s.metadata = {
    "allowed_push_host" => "none",
    "source_code_uri" => "https://github.com/laquereric/magentic-stack/tree/main/gems/vv-cpcp-harness",
    "rubygems_mfa_required" => "true"
  }
end
