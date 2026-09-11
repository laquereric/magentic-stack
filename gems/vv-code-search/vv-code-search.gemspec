# frozen_string_literal: true

require_relative "lib/vv/code_search/version"

Gem::Specification.new do |spec|
  spec.name    = "vv-code-search"
  spec.version = Vv::CodeSearch::VERSION
  spec.authors = ["MagenticMarket contributors"]
  spec.email   = ["substrate@magenticmarket.ai"]

  spec.summary     = "Pre-calculated per-line search over trees we already host: " \
                     "pins, lexical, and the difference between 'nothing here' and " \
                     "'never looked'."
  spec.description = <<~DESC.strip
    Agents grep because grep is the right primitive for a tree nobody has
    indexed: discovery precedes navigation, a repository is not only code, and
    an empty result from `rg` is EVIDENCE in a way that an index miss is not.
    vv-code-search does not argue with any of that. It takes the narrower claim
    that reconstructing the same edges on every agent turn is waste, and makes
    trees we already host stop being unknown every time.

    Two phases that must not blur. INDEX is expensive and runs once per
    (repo, fork, rev, schema). LOOKUP is a hash probe on a warm index and
    carries the product's only hard bound: one line, every enabled dimension,
    under a second, with no model on the path. A dimension that cannot answer by
    line is refused the hot union at registration rather than measured after it
    has already blown a hover's budget.

    The pins dimension keeps DECLARES apart from REFERENCES, because the reverse
    question a maintainer actually asks -- this pin moved, which lines care --
    wants the second set. The declaration is where you change a version; the
    references are what a review has to re-visit because it changed. It reads
    Gemfile.lock, pin manifests, .gitmodules, base image digests, and
    digest-pinned compose images.

    Absence is a signal, and the gem spends real machinery keeping it honest.
    Three outcomes stay distinct: the rev was never indexed, this dimension
    never read this file, and this dimension looked and found nothing. Only the
    third is evidence. Collapsing them into an empty array reproduces exactly
    the failure the lexical dimension exists to avoid.

    Private. Not pushed to rubygems.org. Dry::Monads is not a dependency; every
    public entry returns a never-raise envelope.
  DESC

  spec.homepage = "https://github.com/laquereric/magentic-stack"
  spec.license  = "MIT"
  spec.required_ruby_version = ">= 3.1"

  # ADR 0038: this gem is closed. There is no standalone repo to point at, and a
  # homepage that names one is how divergence starts.
  spec.metadata = {
    "allowed_push_host" => "none",
    "source_code_uri" => "https://github.com/laquereric/magentic-stack/tree/main/gems/vv-code-search",
    "rubygems_mfa_required" => "true"
  }

  spec.files = Dir["lib/**/*.rb", "README.md", "LICENSE", "VERSION"]
  spec.require_paths = ["lib"]
end
