# frozen_string_literal: true

# Oxigraph SPARQL backend for sqlite-sparql extension.
# Provides Vv::Graph::Sparql with SELECT / ASK / CONSTRUCT / UPDATE dispatch.
module Vv
  module Graph
    module OxirsBackend
      # OxiRS graph engine is not yet wired (epic_17_oxirs_graph_engine is
      # proposed); the substrate uses the default Sparql backend. Callers guard
      # with `defined?(OxirsBackend) && OxirsBackend.available?`, so the (defined)
      # stub MUST answer this or they NoMethodError. false -> fall back.
      def self.available?
        false
      end
    end
  end
end
