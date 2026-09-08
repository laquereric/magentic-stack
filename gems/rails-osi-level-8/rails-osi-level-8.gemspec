# frozen_string_literal: true

require_relative "lib/rails_osi_level_8/version"

Gem::Specification.new do |s|
  s.name        = "rails-osi-level-8"
  s.version     = RailsOsiLevel8::VERSION
  s.summary     = "OSI Level 8 cybernetic-interface grammar as a Rails engine - a semantic adapter atop CPCP (rails-cpcp)."
  s.description = "rails-osi-level-8 realizes the OSI Level 8 spec (Context=perception/PULL, Effect=action/PUSH; grounded JSON-LD + closed SHACL profile shapes; three-ledger discipline; Profiles 1-8) as an ADDITIVE Rails engine that decorates rails-cpcp - NOT a second RPC surface. /_cpcp stays the single public seam."
  s.authors     = ["CBI Business Transactions, LLC"]
  s.homepage    = "https://github.com/laquereric/magentic-stack"
  s.license     = "Apache-2.0"
  s.files       = Dir[
    "lib/**/*",
    "db/**/*",
    "data/**/*",
    "docs/**/*",
    "spec/**/*",
    "README.md",
    "LICENSE",
    "*.gemspec"
  ]
  s.require_paths = ["lib"]
  s.required_ruby_version = ">= 3.2"
  s.add_dependency "rails", ">= 8.0"
  s.add_dependency "shapes-application", "= 0.0.0"
  # Direct, not transitive. ProfileCatalog resolves L8_PROTOCOL_MAP (13
  # entries) from this gem. shapes-application also depends on it; that
  # is not a declaration by this consumer.
  s.add_dependency "shapes-level-8", "= 0.0.0"
  # THE BOARD MOUNTS THE SEMANTIC EDITOR AS A MODAL.
  #
  # mmg-semantic-editor's own README says that is what it is for, and Profile 9's
  # translation board is the consumer it means. Two of its modules are load
  # bearing here: Prose.render fills the editor's textarea, and CanonicalId
  # decides which cards may carry a pencil at all -- a Translation is derived per
  # request and never a write target, so it must not offer an edit.
  #
  # Reimplementing that prose format here would have been a second copy of a
  # round trip, drifting the first time either side changed.
  #
  # Note the install order this implies for anything building a GEM_HOME:
  # mmg-semantic-editor before rails-osi-level-8. It declares no dependencies of
  # its own, so it can go early.
  s.add_dependency "mmg-semantic-editor", "= 0.1.0"
  s.add_development_dependency "rspec", "~> 3.13"
end
