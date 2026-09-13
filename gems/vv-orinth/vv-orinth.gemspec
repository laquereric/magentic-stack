# frozen_string_literal: true

require_relative "lib/vv/orinth/version"

Gem::Specification.new do |spec|
  spec.name    = "vv-orinth"
  spec.version = Vv::Orinth::VERSION
  spec.authors = ["MagenticMarket contributors"]
  spec.email   = ["substrate@magenticmarket.ai"]

  spec.summary = "v2 Ornith loop: five envelopes + GRPO. Blocked on SelfLearn v1."
  spec.description = <<~DESC.strip
    Private gem for the Ornith-1.5 cycle (task, scaffold, rollout, reward,
    monitor) and a declared GRPO step that updates a MIND policy checkpoint
    only. V1Binding refuses until ProcedureRepo + SelfLearn plants exist.
    Does not auto-promote Gold. Not on rubygems.org.

    Spelling is orinth (this gem / Orinth1.md); the model family is Ornith.
  DESC

  spec.homepage = "https://github.com/laquereric/magentic-stack"
  spec.license  = "MIT"
  spec.required_ruby_version = ">= 3.1"

  spec.metadata = {
    "allowed_push_host" => "none",
    "source_code_uri" => "https://github.com/laquereric/magentic-stack/tree/main/gems/vv-orinth",
    "rubygems_mfa_required" => "true"
  }

  spec.files = Dir["lib/**/*.rb", "README.md", "LICENSE", "VERSION"]
  spec.require_paths = ["lib"]
end
