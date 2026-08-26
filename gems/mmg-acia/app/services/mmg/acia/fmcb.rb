# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

module Mmg
  module Acia
    # Fmcb -- an MCB Action as a PURE function (epic_65 FORMAL MCB-ACTION MODEL). `call(input:, surface:)`
    # reads ONLY the `surface` (the McbMap tool surface, a subset of the substrate surface) and returns a
    # Proposal describing PROPOSED state -- the ACIA "graph out". It NEVER effects state: no graph write,
    # no AR persistence. Because it depends only on `surface`, an Fmcb is purely functionally testable by
    # MOCKING the substrate (the mock supplies just the surface). McbApply is the imperative shell that
    # runs an Fmcb inside a transaction and applies-or-rejects its Proposal.
    #
    # A Proposal is:
    #   tree    -- a render-node hash (Mmg::Acia::Node.materialize input), or nil
    #   triples -- [ { subject:, predicate:, object:, object_iri:, graph: }, ... ]  the proposed graph changes
    #
    # Subclasses implement #compute(input:, surface:) -> Proposal. Never-raise.
    class Fmcb
      Proposal = ::Struct.new(:tree, :triples, keyword_init: true)

      def call(input:, surface: nil)
        p = compute(input: (input.is_a?(::Hash) ? input : {}), surface: surface)
        p.is_a?(Proposal) ? p : empty_proposal
      rescue ::StandardError
        empty_proposal
      end

      # Override in a subclass. Default: propose nothing.
      def compute(input:, surface:)
        empty_proposal
      end

      def empty_proposal
        Proposal.new(tree: nil, triples: [])
      end
    end
  end
end
