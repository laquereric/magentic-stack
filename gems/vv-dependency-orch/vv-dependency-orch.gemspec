# frozen_string_literal: true

require_relative "lib/vv/dependency_orch/version"

Gem::Specification.new do |spec|
  spec.name    = "vv-dependency-orch"
  spec.version = Vv::DependencyOrch::VERSION
  spec.authors = ["MagenticMarket contributors"]
  spec.email   = ["substrate@magenticmarket.ai"]

  spec.summary     = "One identity, many placements: digest-addressed resources, " \
                     "what depends on them, and what breaks when one moves."
  spec.description = <<~DESC.strip
    Digest pinning works. What is missing is any answer to "what depends on
    this, and what breaks if I move it." Six register shapes and eight gates in
    magentic-stack, and not one of them crosses a kind: one proves a git pin can
    roll back, another proves no FROM is undigested, and nothing answers "the
    floor moved -- who is now wrong?"

    This gem models a RESOURCE as one identity (a digest, never a tag) with many
    PLACEMENTS (local daemon, registry, host, git remote) and many REFERENCES
    (lines in files, in repos). Edges are the product, not nodes. It answers
    three questions: forward dependencies, reverse blast radius, and drift --
    where a declared digest disagrees with the placement actually there.

    Absence is kept honest and it costs real machinery. `unreachable` is not
    `absent`: silence from a host is not evidence its image is gone, and an
    adapter may only report `absent` after a round trip it actually completed.
    `not_indexed` is neither -- it means nobody looked.

    It does NOT reimplement the pin index. vv-code-search already indexes pin
    lines and keeps DECLARES apart from REFERENCES; this gem consumes it, as a
    soft dependency, and reports not_indexed when it is absent rather than
    parsing a lockfile itself. Two answers to "which lines carry a pin" is how
    they start to disagree.

    Never boots Rails. magentic-stack is a Rails-at-root monorepo; this gem
    keeps its own load path so the pin graph can be asked without booting the
    pod. A resource manager must read files; a Rails initializer must not be
    the only way to do that.

    Private. Not pushed to rubygems.org.
  DESC

  spec.homepage = "https://github.com/laquereric/magentic-stack"
  spec.license  = "Apache-2.0"
  spec.required_ruby_version = ">= 3.1"

  # Closed (ADR 0038): there is no standalone repo to point at, and a homepage
  # that names one is where divergence starts.
  spec.metadata = {
    "allowed_push_host" => "none",
    "source_code_uri" => "https://github.com/laquereric/magentic-stack/tree/main/gems/vv-dependency-orch",
    "rubygems_mfa_required" => "true"
  }

  # vv-code-search is deliberately NOT a declared dependency. It lives beside
  # this gem in gems/; requiring it lazily means absence degrades to
  # not_indexed rather than failing the bundle -- the honest reason, since a
  # missing index gem is the purest case of never having looked.
  spec.files = Dir["lib/**/*.rb", "README.md", "LICENSE", "VERSION"]
  spec.require_paths = ["lib"]
end
