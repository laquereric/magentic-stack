# frozen_string_literal: true

module Mmg
  module Graph
    # Registers graph storage on the CPCP seam.
    #
    # This gem already self-registers MCB actions (graphdb_query / graphdb_publish
    # / graphdb_update). Those serve the SUBSTRATE. A pod agent reaches durable
    # state through CPCP at POST /_cpcp/rpc instead, so the same store has to be
    # reachable there too -- one store, two seams, one definition of what may be
    # done to it.
    #
    # Note what is NOT registered: anything taking a bare graph name. The write
    # operation CREATES the grounding entry from the date, name and description
    # it is given, so supplying the account and grounding the node are the same
    # act. A caller cannot do one without the other.
    module Cpcp
      module_function

      def register!
        return { ok: false, reason: :cpcp_absent, because: "rails-cpcp is not loaded" } unless defined?(::RailsCpcp)

        ::RailsCpcp.project(model: "Graph") do
          operation "graph.query", direction: :pull, params: %w[sparql], result: :collection,
            summary: "SPARQL SELECT against the store",
            via: ->(p, _ctx) { Mmg::Graph::Execute.query(p["sparql"].to_s) }

          operation "graph.count", direction: :pull,
            summary: "How many triples are actually there",
            via: ->(_p, _ctx) { Mmg::Graph::Execute.query("SELECT (COUNT(*) AS ?n) WHERE { ?s ?p ?o }") }

          operation "graph.entries", direction: :pull, result: :collection,
            summary: "What has been asserted and why: date, name, description per entry",
            via: ->(_p, _ctx) { Mmg::Graph::Cpcp.entries }

          operation "graph.publish", direction: :push,
            params: %w[operationId date name description triples],
            summary: "Assert triples under a new grounded entry. Requires date, name and description",
            via: ->(p, _ctx) { Mmg::Graph::Cpcp.publish(p) }
        end

        { ok: true, operations: %w[graph.query graph.count graph.entries graph.publish] }
      end

      # The write. Creating the entry and grounding the node are ONE act: there is
      # no path here that asserts triples without saying when, what and why.
      def publish(params)
        return refuse(:model_unavailable, "ActiveRecord is not loaded; entries cannot be created") unless defined?(::ActiveRecord::Base)

        entry = Entry.new(
          date: params["date"], name: params["name"], description: params["description"]
        )
        unless entry.valid?
          return refuse(:entry_incomplete,
                        "every graph entry needs date, name, description; #{entry.errors.full_messages.join('; ')}. " \
                        "Triples say what was asserted, never why it is here")
        end

        triples = params["triples"]
        return refuse(:triples_required, "graph.publish needs triples") if Array(triples).empty?

        entry.save!
        Execute.publish(Array(triples), entry: entry)
      rescue StandardError => e
        refuse(:publish_failed, "#{e.class}: #{e.message}")
      end

      def entries
        return refuse(:model_unavailable, "ActiveRecord is not loaded") unless defined?(::ActiveRecord::Base)

        rows = Entry.order(id: :desc).limit(100).map do |e|
          { ref: e.ref, graph: e.graph_name, date: e.date, name: e.name, description: e.description }
        end
        { ok: true, rows: rows }
      rescue StandardError => e
        refuse(:read_failed, "#{e.class}: #{e.message}")
      end

      def refuse(reason, because) = { ok: false, reason: reason, because: because }
    end
  end
end
