# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

module Mmg
  module Acia
    # Triple -- one PROPOSED graph triple OWNED by an ACIA Node until McbApply commits it (epic_65
    # Fmcb/McbApply). An Fmcb writes Triples to the ACIA tree (transaction-aware AR); McbApply adds the
    # ACIA-stored triples to the graph on ACCEPT. `object_iri` distinguishes an IRI object (<...>) from a
    # literal ("..."). Never-effects-state on its own: it is a staged proposal until McbApply commits.
    class Triple < ::ActiveRecord::Base
      self.table_name = "mmg_acia_triples"

      belongs_to :node, class_name: "Mmg::Acia::Node", optional: true

      validates :subject,   presence: true
      validates :predicate, presence: true

      # The N-Triple line this proposed triple contributes (feeds Mmg::Acia::Graph.publish on apply).
      def to_ntriple
        obj = object_iri ? "<#{object}>" : "\"#{lit(object)}\""
        "<#{subject}> <#{predicate}> #{obj} ."
      end

      # Same literal escaping as Mmg::Acia::Node#lit (N-Triples string literal).
      def lit(v)
        v.to_s.gsub("\\", "\\\\").gsub('"', '\\"').gsub("\n", '\\n').gsub("\r", '\\r').gsub("\t", '\\t')
      end
    end
  end
end
