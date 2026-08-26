# frozen_string_literal: true

module Mmg
  module Graph
    # Registers graph storage on the CPCP seam.
    #
    # CPCP IS THE DESTINATION.
    #
    # This gem also self-registers MCB actions (graphdb_query / graphdb_publish /
    # graphdb_update). Those are the LEGACY surface: they predate the pod and
    # still serve the substrate, so they stay until nothing calls them. New
    # capability lands here, not there.
    #
    # The two are not co-equal. MCB is one tool with an action vocabulary; CPCP is
    # a typed contract at POST /_cpcp/rpc with shape gating, a required
    # operationId on writes, and a sole writer on the far side. An agent that
    # reaches storage through CPCP cannot mark its own effect committed, and that
    # property is the reason to evolve toward it rather than to keep both.
    #
    # Where they disagree, CPCP wins. The MCB publish path still accepts what this
    # one refuses -- an ungrounded write -- and closing that is the next step, not
    # a reason to mirror it here.
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

          # COUNT THE NAMED GRAPHS TOO, or it counts nothing.
          #
          # This asked WHERE { ?s ?p ?o }, which in SPARQL is the DEFAULT graph.
          # Every triple this gem writes goes into a NAMED graph -- publish puts
          # it in the entry's graph, because that is what grounds it -- so the
          # count answered 0 with the store full, and answered it in the same
          # confident shape as a true answer. A status query that cannot see the
          # thing it reports on is worse than no status query.
          operation "graph.count", direction: :pull,
            summary: "How many triples are actually there, default graph and named graphs both",
            via: ->(_p, _ctx) {
              Mmg::Graph::Execute.query(
                "SELECT (COUNT(*) AS ?n) WHERE { { ?s ?p ?o } UNION { GRAPH ?g { ?s ?p ?o } } }"
              )
            }

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

        # The entry and the assertion stand or fall TOGETHER.
        #
        # Saving first and publishing after leaves an entry accounting for triples
        # that were never asserted -- a record saying "this is what we stored and
        # why" pointing at an empty named graph. That is worse than no record: it
        # reads as evidence. If the store cannot be reached, the account goes back.
        # requires_new: true -- A SAVEPOINT, NOT A JOINED TRANSACTION.
        #
        # Without it this guarantee held only while no caller wrapped the call.
        # A plain `transaction` block nested inside an outer one JOINS it, and
        # ActiveRecord::Rollback raised in a joined block is swallowed: the outer
        # transaction carries on and COMMITS the entry. The account would survive
        # while the assertion never happened -- the exact artifact described
        # above, produced by the code meant to prevent it.
        #
        # A savepoint rolls back on its own terms either way.
        result = nil
        ::ActiveRecord::Base.transaction(requires_new: true) do
          entry.save!
          result = Execute.publish(Array(triples), entry: entry)
          raise ::ActiveRecord::Rollback unless result.is_a?(::Hash) && result[:ok]
        end

        if result.is_a?(::Hash) && result[:ok]
          result
        else
          (result || refuse(:publish_failed, "publish returned nothing"))
            .merge(entry_rolled_back: true,
                   because: "#{result && result[:because]} — the entry was rolled back rather than left " \
                            "accounting for triples that were never asserted")
        end
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
