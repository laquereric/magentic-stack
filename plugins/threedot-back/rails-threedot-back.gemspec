# frozen_string_literal: true
require_relative "lib/rails_threedot_back/version"
Gem::Specification.new do |s|
  s.name        = "rails-threedot-back"
  s.version     = RailsThreedotBack::VERSION
  s.summary     = "The threedot BACK: CID-as-AR-root Rails engine serving the threedot plugin over the CPCP seam."
  s.description = "rails-threedot-back is the live data plane for the threedot VS Code webview shell. CID is the ROOT ActiveRecord (has_many operations/capabilities/shapes/object_nodes); the plugin object model is AR-based; served over the single public /_cpcp seam (rails-cpcp), optionally grounded by rails-osi-level-8. The static .threedot/cid.json is a bootstrap discovery seed only. Vv::Graph::Storable RDF projection is enabled but deferred (AR-primary first cut)."
  s.authors     = ["CBI Business Transactions, LLC"]
  s.homepage    = "https://github.com/laquereric/rails-threedot-back"
  s.license     = "Apache-2.0"
  s.files       = Dir["lib/**/*", "app/**/*", "db/**/*", "docs/**/*", "README.md", "LICENSE", "*.gemspec"]
  s.require_paths = ["lib"]
  s.required_ruby_version = ">= 3.2"
  s.add_dependency "rails", ">= 8.0"
end
