# frozen_string_literal: true

require_relative "lib/vv/routing/version"

Gem::Specification.new do |s|
  s.name        = "vv-routing"
  s.version     = Vv::Routing::VERSION
  s.summary     = "Two-tier LLM routing split by plane: synthesis, where a toolchain checks the output, and production, where nothing does."
  s.description = <<~DESC.strip
    The two-tier argument -- route mechanical tool calls to a small fast model,
    keep the frontier model for the answer a person reads -- is an argument about
    CHECKABILITY, and it leaves out the variable that decides the risk: who reads
    the output before someone depends on it.

    On the SYNTHESIS plane the model emits code, plans or shapes, and a compiler,
    a spec and the sweep read them first; a wrong answer costs a retry. On the
    PRODUCTION plane the output is consumed live and nothing checks it by
    default. So Route REFUSES a production route to the cheap tier unless a
    verifier is named, the frontier tier is chosen, or the risk is accepted in
    writing.

    Names no models: which model serves a completion is SWITCH's business, and a
    gem reaching through that seam would be deciding it from the wrong side.
  DESC
  s.authors     = ["Eric Laquer"]
  s.files       = Dir["lib/**/*", "docs/**/*", "README.md"]
  s.required_ruby_version = ">= 3.3"
end
