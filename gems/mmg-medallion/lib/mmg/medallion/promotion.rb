# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

require "securerandom"
require "time"
require_relative "vocab"
require_relative "storable_local"
require_relative "subject_ref"

module Mmg
  module Medallion
    # Immutable adjacent tier transition (bronze→silver, silver→gold).
    class Promotion
      include StorableLocal

      attr_reader :event_id, :flow_iri, :subject_ref, :from_tier, :to_tier,
                  :occurred_at, :stamps

      def initialize(event_id:, flow_iri:, subject_ref:, from_tier:, to_tier:,
                     occurred_at: nil, stamps: [])
        @event_id = event_id.to_s
        @flow_iri = flow_iri.to_s
        @subject_ref = SubjectRef.coerce(subject_ref)
        @from_tier = from_tier
        @to_tier = to_tier
        @occurred_at = occurred_at || Time.now.utc
        @stamps = Array(stamps).map { |s| s.is_a?(Hash) ? s.transform_keys(&:to_s) : s }.freeze
      end

      def iri
        Vocab.promotion(event_id)
      end

      def to_h
        {
          event_id: event_id,
          iri: iri,
          flow_iri: flow_iri,
          subject_iri: subject_ref.iri,
          from_tier: from_tier.slug,
          to_tier: to_tier.slug,
          occurred_at: occurred_at.iso8601,
          stamps: stamps
        }
      end

      triples do
        triple iri, Vocab::RDF_TYPE, Vocab::PROMOTION
        triple iri, Vocab::FLOW, flow_iri
        triple iri, Vocab::SUBJECT, subject_ref.iri
        triple iri, Vocab::PROMOTED_FROM, from_tier.iri
        triple iri, Vocab::PROMOTED_TO, to_tier.iri
        triple iri, Vocab::OCCURRED_AT, occurred_at.iso8601
      end

      def self.from_event(event)
        data = event.respond_to?(:data) ? event.data : event
        h = data.is_a?(Hash) ? data.transform_keys { |k| k.to_s } : {}
        new(
          event_id: h["event_id"] || h["id"] || SecureRandom.hex(8),
          flow_iri: h["flow_iri"],
          subject_ref: SubjectRef.new(iri: h["subject_iri"], graph_iri: h["graph_iri"]),
          from_tier: Tier.for(h["from_tier_slug"] || h["from_tier"]),
          to_tier: Tier.for(h["to_tier_slug"] || h["to_tier"]),
          occurred_at: (Time.parse(h["occurred_at"]) rescue Time.now.utc),
          stamps: h["stamps"] || []
        )
      end
    end
  end
end
