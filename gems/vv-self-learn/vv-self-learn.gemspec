# frozen_string_literal: true

require_relative "lib/vv/self_learn/version"

Gem::Specification.new do |spec|
  spec.name    = "vv-self-learn"
  spec.version = Vv::SelfLearn::VERSION
  spec.authors = ["MagenticMarket contributors"]
  spec.email   = ["substrate@magenticmarket.ai"]

  spec.summary = "GOLD→PROD→Bronze→recommend. EvalGrading. Not Ornith v1."
  spec.description = <<~DESC.strip
    SelfLearn v1 contract: three CPCP methods (collect, eval, recommend),
    Wilson 95% interval, deterministic grader for SHAPE digests. PROD may
    collect; PROD may not promote. Ornith/GRPO/five envelopes refuse as
    ornith_not_v1.

    Private. Not on rubygems.org. No ActiveRecord, no DuckDB, no GRPO.
  DESC

  spec.homepage = "https://github.com/laquereric/magentic-stack"
  spec.license  = "MIT"
  spec.required_ruby_version = ">= 3.1"

  spec.metadata = {
    "allowed_push_host" => "none",
    "source_code_uri" => "https://github.com/laquereric/magentic-stack/tree/main/gems/vv-self-learn",
    "rubygems_mfa_required" => "true"
  }

  spec.files = Dir["lib/**/*.rb", "README.md", "LICENSE", "VERSION"]
  spec.require_paths = ["lib"]
end
