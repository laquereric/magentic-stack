# frozen_string_literal: true

# Oxigraph SPARQL backend for sqlite-sparql extension.
# Provides Vv::Graph::Sparql with SELECT / ASK / CONSTRUCT / UPDATE dispatch.
module Vv
  module Graph
    module OxirsBackend
      class << self
        # OxiRS graph engine is not yet wired (epic_17_oxirs_graph_engine is
        # proposed); the substrate uses the default Sparql backend. Callers guard
        # with `defined?(OxirsBackend) && OxirsBackend.available?`, so the
        # (defined) stub MUST answer this or they NoMethodError. false -> fall
        # back to Vv::Graph::Sparql.
        def available?
          false
        end

        # The real backend exposes a SELECT/ASK/CONSTRUCT/UPDATE/insert_data/
        # endpoint dispatch surface. These MUST be defined (public) even while
        # the engine is unwired, for two reasons:
        #   1. Specs that force `available? => true` stub these; with
        #      verify_partial_doubles the methods must exist on the module.
        #   2. A PUBLIC `select`/`ask` must shadow the private Kernel#select /
        #      IO methods -- otherwise `OxirsBackend.select(...)` resolves to
        #      private Kernel#select and raises a confusing
        #      "private method 'select' called" NoMethodError.
        def endpoint
          not_wired!(:endpoint)
        end

        def select(_query, graph: nil)
          not_wired!(:select)
        end

        def ask(_query, graph: nil)
          not_wired!(:ask)
        end

        def construct(_query, graph: nil)
          not_wired!(:construct)
        end

        def update(_statement, graph: nil)
          not_wired!(:update)
        end

        def insert_data(_data, graph: nil)
          not_wired!(:insert_data)
        end

        private

        def not_wired!(method_name)
          raise ::NotImplementedError,
                "Vv::Graph::OxirsBackend.#{method_name} is not wired " \
                "(available? => false); guard with OxirsBackend.available? " \
                "or use Vv::Graph::Sparql"
        end
      end
    end
  end
end
