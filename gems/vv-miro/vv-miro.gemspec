# frozen_string_literal: true

require_relative "lib/vv/miro/version"

# ADR 0038: this repo is CLOSED, and rule 2 is specific -- no gemspec under
# gems/ may name a laquereric/ repo other than magentic-stack. The gem arrived
# from a standalone private repo whose gemspec pointed at itself, which is the
# exact configuration 0038 was written about: a reader arriving here would be
# directed at the other copy, and that is how divergence starts. Retargeted on
# the way in. The standalone repo is now the non-authoritative copy and 0038
# rule 3 says archive it -- an owner action on GitHub, not taken here.
Gem::Specification.new do |s|
  s.name        = "vv-miro"
  s.version     = Vv::Miro::VERSION
  s.summary     = "Miro Web SDK + REST v2 boundary for Magentic"
  s.description = "Never-raise Miro boundary: one browser load wrapping " \
                  "Web SDK 2.0 and Live Embed, plus a Ruby REST v2 client " \
                  "and OAuth 2.0. Editor.js calls the high-level surface; " \
                  "this gem owns every miro-specific call. Credentials are " \
                  "read from ENV and never stored here. Private; not pushed " \
                  "to rubygems.org."
  s.authors     = ["Eric Laquer"]
  s.email       = ["eric@magenticmarket.ai"]
  s.homepage    = "https://github.com/laquereric/magentic-stack"
  s.files       = Dir["lib/**/*", "public/**/*", "README.md", "LICENSE", "docs/**/*"]
  s.require_paths = ["lib"]
  s.required_ruby_version = ">= 3.2"
  s.license     = "Nonstandard"
  s.metadata = {
    "allowed_push_host" => "none",
    "source_code_uri" => "https://github.com/laquereric/magentic-stack/tree/main/gems/vv-miro",
    "rubygems_mfa_required" => "true"
  }
end
