# frozen_string_literal: true
require_relative "rails_threedot_back/version"
require_relative "rails_threedot_back/cpcp_projection"
require_relative "rails_threedot_back/engine" if defined?(::Rails::Engine)

# rails-threedot-back -- the threedot BACK. CID is the ROOT ActiveRecord (has_many operations,
# capabilities, shapes, object_nodes); the object model is AR-based. Served to the webview shell
# over the single CPCP seam (/_cpcp via rails-cpcp); optionally grounded by rails-osi-level-8.
# Vv::Graph::Storable RDF projection is ENABLED on the models but DEFERRED (AR-primary first cut).
module RailsThreedotBack; end
