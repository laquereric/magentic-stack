# frozen_string_literal: true

module Mmg
  module Acia
    # State (graph-out) for the ACIA core (epic_65 -- moved verbatim from Mmg::Sal::Graph).
    # Writes via the ONE mounted graph write facade, Vv::Graph::Sparql (execute/select).
    # Mmg::Graph::Execute is UNMOUNTED in this app -- the AR-anchored medallion routes
    # through Vv::Graph (docs: substrate-needs-one-real-graph-write-facade). Named-graph
    # URNs kept as urn:mmg:sal:* for DATA CONTINUITY (the acia# rename is a later isolated
    # step; existing node decorations already live there). Never-raise. Mmg::Sal::Graph delegates here.
    class Graph
      PUBLIC  = "urn:mmg:sal:public"
      PRIVATE = "urn:mmg:sal:private"

      # publish an array of N-Triple strings. execute's insert_each_triple is LINE-oriented,
      # so the triples MUST be NEWLINE-joined (a space-joined body inserts only the first).
      def self.publish(triples, graph: PUBLIC)
        return { ok: false, reason: :graph_unmounted } unless defined?(::Vv::Graph::Sparql)
        body = ::Kernel.Array(triples).join("\n")
        return { ok: true, count: 0 } if body.strip.empty?
        ::Vv::Graph::Sparql.execute("INSERT DATA { #{body} }", graph: graph)
      rescue ::StandardError => e
        { ok: false, reason: :publish_failed, because: "#{e.class}: #{e.message}" }
      end

      def self.query(sparql, graph: PUBLIC)
        return { ok: false, reason: :graph_unmounted } unless defined?(::Vv::Graph::Sparql)
        ::Vv::Graph::Sparql.select(sparql, graph: graph)
      rescue ::StandardError => e
        { ok: false, reason: :query_failed, because: "#{e.class}: #{e.message}" }
      end

      # SPARQL 1.1 UPDATE (INSERT DATA / DELETE WHERE / ...) via the mounted facade.
      def self.update(sparql, graph: PUBLIC)
        return { ok: false, reason: :graph_unmounted } unless defined?(::Vv::Graph::Sparql)
        ::Vv::Graph::Sparql.execute(sparql, graph: graph)
      rescue ::StandardError => e
        { ok: false, reason: :update_failed, because: "#{e.class}: #{e.message}" }
      end
    end
  end
end
