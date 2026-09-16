# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

module Mmg
  module Medallion
    # Abstract subject reference (IRI + optional named graph).
    class SubjectRef
      attr_reader :iri, :graph_iri

      def initialize(iri:, graph_iri: nil)
        @iri = iri.to_s
        @graph_iri = (graph_iri || Vocab::TIER_GRAPH).to_s
      end

      def self.coerce(subject)
        case subject
        when SubjectRef then subject
        when Hash
          h = subject.transform_keys { |k| k.to_s }
          new(iri: h["iri"] || h["subject_iri"], graph_iri: h["graph_iri"])
        when String, Symbol
          new(iri: subject.to_s)
        else
          if subject.respond_to?(:iri)
            new(iri: subject.iri, graph_iri: (subject.graph_iri if subject.respond_to?(:graph_iri)))
          else
            new(iri: subject.to_s)
          end
        end
      end

      def to_h
        { iri: iri, graph_iri: graph_iri }
      end
    end
  end
end
