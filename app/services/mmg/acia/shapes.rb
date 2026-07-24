# frozen_string_literal: true

require "securerandom"

module Mmg
  module Acia
    # Shapes -- NON-ENFORCING SHACL Core validation of ACIA node triples against
    # lib/mmg/acia/acia_shapes.ttl, reusing vv-graph's SHACL Core validator
    # (Vv::Graph::Shacl.validate over NAMED GRAPHS in the mounted store). This is a
    # VALIDATION seam only: it NEVER gates McbApply and NEVER mutates durable state --
    # it materializes the triples into an EPHEMERAL data graph, validates, and clears it.
    #
    #   Mmg::Acia::Shapes.validate(node.to_triples)     # validate a triple list
    #   Mmg::Acia::Shapes.validate(tree_key: "brf_...") # validate a whole tree
    #
    # Returns a never-raise envelope:
    #   { ok: true,  conforms: <bool>, results: [ <violation hash>, ... ] }
    #   { ok: false, reason: <sym>, because: <str> }
    #
    # Graceful-degrade: { ok: false, reason: :shacl_unavailable } if the vv-graph SHACL
    # validator/loader is not loadable.
    #
    # Phase A: sh:targetClass via per-role rdf:type IRIs.
    # Phase B: Tab requires explicit aria:selected; use ValidatedSnapshot + enforce:
    # true on deliver_tree! to gate. validate() remains non-blocking (report only).
    class Shapes
      SHAPES_TTL   = ::File.expand_path("../../../../lib/mmg/acia/acia_shapes.ttl", __dir__)
      SHAPES_GRAPH = "urn:mmg:acia:shapes"
      DATA_PREFIX  = "urn:mmg:acia:validate:"

      # triples: an Array of N-Triple strings (e.g. node.to_triples). tree_key: validate
      # every node of a materialized tree instead. Exactly one is required.
      def self.validate(triples = nil, tree_key: nil)
        return refused(:shacl_unavailable, "Vv::Graph::Shacl not loadable") unless shacl_available?

        rows = resolve_triples(triples, tree_key)
        return refused(:no_triples, "no triples to validate (pass triples or tree_key)") if rows.empty?

        loaded = load_shapes
        return loaded unless loaded[:ok]

        data_graph   = "#{DATA_PREFIX}#{::SecureRandom.hex(8)}"
        report_graph = "#{data_graph}:report"
        begin
          pub = ::Mmg::Acia::Graph.publish(rows, graph: data_graph)
          return refused(:data_load_failed, pub[:because].to_s) if pub.is_a?(::Hash) && pub[:ok] == false

          res = ::Vv::Graph::Shacl.validate(
            data_graph:   data_graph,
            shapes_graph: SHAPES_GRAPH,
            report_graph: report_graph,
          )
          return refused((res.is_a?(::Hash) ? res[:reason] : :validate_failed),
                         (res.is_a?(::Hash) ? res[:because] : res.inspect)) unless res.is_a?(::Hash) && res[:ok] == true

          { ok: true, conforms: res[:conforms] == true, results: ::Kernel.Array(res[:violations]) }
        ensure
          clear_graph(data_graph)
          clear_graph(report_graph)
        end
      rescue ::StandardError => e
        refused(:validate_failed, "#{e.class}: #{e.message}")
      end

      # --- internals (never-raise) ---------------------------------------------

      def self.shacl_available?
        return true if defined?(::Vv::Graph::Shacl) && defined?(::Vv::Graph::Shacl::Loader)
        require "vv/graph/shacl"
        require "vv/graph/shacl/loader"
        defined?(::Vv::Graph::Shacl) && defined?(::Vv::Graph::Shacl::Loader) ? true : false
      rescue ::LoadError, ::StandardError
        false
      end

      def self.load_shapes
        body = ::File.read(SHAPES_TTL)
        env  = ::Vv::Graph::Shacl::Loader.load(body, format: :ttl, scope: SHAPES_GRAPH)
        return env if env.is_a?(::Hash) && env[:ok] == false
        { ok: true }
      rescue ::StandardError => e
        refused(:shapes_load_failed, "#{e.class}: #{e.message}")
      end

      def self.resolve_triples(triples, tree_key)
        if triples
          ::Kernel.Array(triples)
        elsif tree_key && !tree_key.to_s.empty?
          ::Mmg::Acia::Node.for_tree(tree_key).flat_map(&:to_triples)
        else
          []
        end
      rescue ::StandardError
        []
      end

      def self.clear_graph(graph)
        ::Mmg::Acia::Graph.update("CLEAR GRAPH <#{graph}>", graph: graph)
      rescue ::StandardError
        nil
      end

      def self.refused(reason, because = nil)
        { ok: false, reason: reason, because: because.to_s }
      end
    end
  end
end
