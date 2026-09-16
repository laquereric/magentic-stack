# frozen_string_literal: true

require_relative "lib/vv/nooa/version"

Gem::Specification.new do |spec|
  spec.name    = "vv-nooa"
  spec.version = Vv::Nooa::VERSION
  spec.authors = ["MagenticMarket contributors"]
  spec.email   = ["substrate@magenticmarket.ai"]

  spec.summary = "Doctrine-as-data for NVIDIA's Object-Oriented Agents harness: " \
                 "six capabilities, published evidence, isolation classifier."
  spec.description = <<~DESC.strip
    Models NVIDIA Object-Oriented Agents (NOOA) as queryable doctrine: the six
    model-facing harness capabilities, the published SWE-bench Verified harness
    delta on a fixed model, and the code-as-action isolation classifier
    (defense-in-depth vs containment boundary). Each capability records the
    NVIDIA form, the magentic-stack realization, and a portable steal lesson.

    This gem does not wrap, import, or execute the pinned NOOA upstream. That
    Python harness is consumed by runtimes/mind-pod; gems/adapters/ is the
    only code allowed to reach into that tree (ADR 0020). Isolation doctrine
    names Monty (ADR 0071) as the interpreter boundary.

    Private. Not on rubygems.org. Dry::Monads is not a dependency; every
    public entry returns a never-raise envelope.
  DESC

  spec.homepage = "https://github.com/laquereric/magentic-stack"
  spec.license  = "MIT"
  spec.required_ruby_version = ">= 3.1"

  # ADR 0038: this gem is closed. There is no standalone repo to point at, and a
  # homepage that names one is how divergence starts.
  spec.metadata = {
    "allowed_push_host" => "none",
    "source_code_uri" => "https://github.com/laquereric/magentic-stack/tree/main/gems/vv-nooa",
    "rubygems_mfa_required" => "true"
  }

  spec.files = Dir["lib/**/*.rb", "README.md", "LICENSE", "VERSION"]
  spec.require_paths = ["lib"]
end
