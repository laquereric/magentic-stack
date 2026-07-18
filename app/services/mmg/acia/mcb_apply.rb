# frozen_string_literal: true

require "securerandom"

module Mmg
  module Acia
    # McbApply -- the IMPERATIVE SHELL around a pure Fmcb (epic_65 FORMAL MCB-ACTION MODEL). It:
    #   1. runs the pure Fmcb -> Proposal (no state touched)
    #   2. opens a TRANSACTION (requires_new -> a savepoint; the 'epoch' / transaction boundary)
    #   3. WRITES the proposed triples to the ACIA tree -- materialize the Node + create Triple rows
    #      (transaction-aware AR). This is step (1) of the separation: 'write the triple to the ACIA tree'.
    #   4. runs the 'Apply?' GATE on the proposal
    #   5. on ACCEPT: ADDS the ACIA-stored triples to the graph (Mmg::Acia::Graph.publish) + commits.
    #      This is step (2) of the separation: 'add the ACIA-stored triples to the graph'.
    #      on REJECT: raises Rollback -> the ACIA tree + triples are discarded; NO graph write.
    # Never-raise envelope. The two separated steps are why an Fmcb is testable without a graph.
    class McbApply
      DEFAULT_GATE = ->(_proposal, _node) { true }

      def self.call(fmcb:, input:, surface: nil, apply_gate: DEFAULT_GATE, tree_key: nil)
        proposal  = fmcb.call(input: input, surface: surface) # PURE
        tree_key ||= "fmcb:#{::SecureRandom.hex(6)}"
        node      = nil
        triples   = []
        applied   = false

        ::ActiveRecord::Base.transaction(requires_new: true) do
          node    = proposal.tree ? ::Mmg::Acia::Node.materialize(proposal.tree, tree_key: tree_key) : nil
          triples = ::Kernel.Array(proposal.triples).map do |t|
            ::Mmg::Acia::Triple.create!(
              node:       node,
              subject:    (t[:subject]    || t["subject"]).to_s,
              predicate:  (t[:predicate]  || t["predicate"]).to_s,
              object:     (t[:object]     || t["object"]).to_s,
              object_iri: !!(t[:object_iri] || t["object_iri"]),
              graph:      (t[:graph] || t["graph"] || ::Mmg::Acia::Graph::PUBLIC).to_s
            )
          end
          if apply_gate.call(proposal, node)
            add_triples_to_graph(triples) # the APPLY -- separable from the ACIA-tree write above
            applied = true
          else
            raise ::ActiveRecord::Rollback
          end
        end

        { ok: true, applied: applied, tree_key: tree_key,
          node_id: (applied ? node&.id : nil),
          triple_count: triples.size,
          ntriples: triples.map(&:to_ntriple) }
      rescue ::StandardError => e
        { ok: false, reason: :mcb_apply_failed, because: "#{e.class}: #{e.message}" }
      end

      # Add the ACIA-stored triples to the graph, grouped by named graph. The ONLY graph write. Never-raise.
      def self.add_triples_to_graph(triples)
        ::Kernel.Array(triples).group_by { |t| t.graph.to_s }.each do |g, ts|
          target = g.empty? ? ::Mmg::Acia::Graph::PUBLIC : g
          ::Mmg::Acia::Graph.publish(ts.map(&:to_ntriple), graph: target)
        end
      end
    end
  end
end
