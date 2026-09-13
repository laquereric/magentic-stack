# frozen_string_literal: true

require_relative "lib/vv/code_repo/version"

Gem::Specification.new do |spec|
  spec.name    = "vv-code-repo"
  spec.version = Vv::CodeRepo::VERSION
  spec.authors = ["MagenticMarket contributors"]
  spec.email   = ["substrate@magenticmarket.ai"]

  spec.summary = "Procedure catalog contract: digest-named Gold on BACK AR + blob."
  spec.description = <<~DESC.strip
    ProcedureRepo as a private gem. Identity is sha256 of bytes. AR will hold
    the named account (slug, Gold pointer, LinkML cites, language bindings);
    this gem is the CONTRACT half: closed refusals, CPCP operation list,
    land/bind/serve/promote envelopes, and the DEV/PROD grant.

    No ActiveRecord, no DuckDB, no procedure.eval. Private. Not on rubygems.org.
  DESC

  spec.homepage = "https://github.com/laquereric/magentic-stack"
  spec.license  = "MIT"
  spec.required_ruby_version = ">= 3.1"

  spec.metadata = {
    "allowed_push_host" => "none",
    "source_code_uri" => "https://github.com/laquereric/magentic-stack/tree/main/gems/vv-code-repo",
    "rubygems_mfa_required" => "true"
  }

  spec.files = Dir["lib/**/*.rb", "README.md", "LICENSE", "VERSION"]
  spec.require_paths = ["lib"]
end
