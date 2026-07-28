# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

module Mmg
  module Acia
    module Fmcbs
      # Echo -- the smallest possible Fmcb (epic_65 Stage 1 example). Given input {subject, predicate,
      # object[, object_iri]}, it PROPOSES one ACIA node describing the assertion + one Triple asserting
      # (subject predicate object). PURE: it reads nothing from the substrate (a bare surface double
      # suffices), writes no graph, persists no AR -- proving Fmcb mockability. McbApply turns the
      # proposal into a committed graph triple (or rolls it back).
      class Echo < ::Mmg::Acia::Fmcb
        def compute(input:, surface:)
          s = input[:subject].to_s
          p = input[:predicate].to_s
          o = input[:object].to_s
          object_iri = !!input[:object_iri]
          tree = { kind: "text", semantic_role: "triple", value: "#{s} #{p} #{o}" }
          triples = [{ subject: s, predicate: p, object: o, object_iri: object_iri,
                       graph: ::Mmg::Acia::Graph::PUBLIC }]
          Proposal.new(tree: tree, triples: triples)
        end
      end
    end
  end
end
