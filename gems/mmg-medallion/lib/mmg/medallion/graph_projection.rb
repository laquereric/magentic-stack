# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

require_relative "result"
require_relative "vocab"
require_relative "tier"
require_relative "subject_ref"
require_relative "grounding"
require_relative "promotion"
require_relative "n_triples"

module Mmg
  module Medallion
    # RES event → RDF triple projection (idempotent by event_id) (design §5).
    class GraphProjection
      GRAPH = {} # graph_iri => { subject => { predicate => object } }
      APPLIED = {} # event_id => true

      def self.clear!
        GRAPH.clear
        APPLIED.clear
        { ok: true }
      end

      def self.graph
        GRAPH
      end

      def initialize(graph_sink: nil)
        @graph_sink = graph_sink
      end

      def apply(event)
        apply_hash(normalize(event))
      end

      def apply_hash(h)
        Result.capture(reason: :graph_projection_failed) do
          h = h.transform_keys(&:to_s)
          eid = h["id"] || h["event_id"]
          if eid && APPLIED[eid]
            return Result.success(event_id: eid, projected: true, idempotent: true)
          end

          case h["type"].to_s
          when "medallion.flow_started.v1"
            apply_current_grounding(h, tier_slug: h["tier_slug"] || "bronze")
            apply_flow_resource(h)
          when "medallion.promoted.v1"
            apply_current_grounding(h, tier_slug: h["to_tier_slug"])
            apply_promotion_resource(h)
          else
            return Result.failure(:unsupported_event, "#{h['type']} is not a medallion event")
          end

          APPLIED[eid] = true if eid
          Result.success(event_id: eid, projected: true, graph_iri: h["graph_iri"] || Vocab::TIER_GRAPH)
        end
      end

      def snapshot(graph_iri: Vocab::TIER_GRAPH)
        Result.success(graph_iri: graph_iri, triples: flatten(GRAPH[graph_iri.to_s] || {}))
      end

      # M1: raw N-Triples lines into a named graph (the always-on half of
      # an armed write). Lines that do not parse fail the ingest -- the
      # gate parses first, so a post-gate ingest cannot fail; direct
      # callers get the refusal instead of a half-written graph.
      def ingest(graph_iri:, lines:)
        lines = Array(lines).map(&:to_s)
        parsed = []
        lines.each_with_index do |line, i|
          r = NTriples.parse(line)
          unless r[:ok]
            return Result.failure(
              :unparseable_triples,
              "ingest refused line #{i}: #{r[:because]}; nothing was written"
            )
          end
          parsed << r
        end

        triples = parsed.map do |t|
          { s: render_term(t[:s]), p: render_term(t[:p]), o: render_term(t[:o]) }
        end
        write_triples(graph_iri.to_s, triples)
        Result.success(graph_iri: graph_iri.to_s, triples_written: triples.size)
      end

      def render_term(term)
        case term[:kind]
        when :iri then "<#{term[:value]}>"
        when :literal then %("#{term[:value]}")
        when :blank then "_:#{term[:value]}"
        else term[:value].to_s
        end
      end
      private :render_term

      private

      def normalize(event)
        if event.respond_to?(:type) && event.respond_to?(:data)
          d = event.data.is_a?(Hash) ? event.data : {}
          d.merge("type" => event.type, "id" => (event.respond_to?(:id) ? event.id : nil))
        elsif event.is_a?(Hash)
          event
        else
          { "type" => "unknown" }
        end
      end

      def apply_current_grounding(h, tier_slug:)
        tier = Tier.for(tier_slug)
        return Result.failure(:tier_registry_incomplete, "#{tier_slug} is absent") unless tier

        ref = SubjectRef.new(iri: h["subject_iri"], graph_iri: h["graph_iri"] || Vocab::TIER_GRAPH)
        grounding = Grounding.new(subject_ref: ref, tier: tier)
        write_triples(ref.graph_iri, grounding.emit_triples, replace_pred: Vocab::MEDALLION_TIER_P)
      end

      def apply_flow_resource(h)
        flow_iri = h["flow_iri"] || Vocab.flow(h["subject_iri"])
        g_iri = h["graph_iri"] || Vocab::TIER_GRAPH
        triples = [
          { s: flow_iri, p: Vocab::RDF_TYPE, o: Vocab::MEDALLION_FLOW },
          { s: flow_iri, p: Vocab::SUBJECT, o: h["subject_iri"] },
          { s: flow_iri, p: Vocab::MEDALLION_TIER_P, o: Vocab.tier(h["tier_slug"] || "bronze") }
        ]
        write_triples(g_iri, triples)
      end

      def apply_promotion_resource(h)
        promo = Promotion.from_event(h)
        write_triples(h["graph_iri"] || Vocab::TIER_GRAPH, promo.emit_triples)
      end

      def write_triples(graph_iri, triples, replace_pred: nil)
        g = GRAPH[graph_iri.to_s] ||= {}
        Array(triples).each do |t|
          s = t[:s] || t["s"]
          p = t[:p] || t["p"]
          o = t[:o] || t["o"]
          next if s.nil? || p.nil?

          g[s] ||= {}
          if replace_pred && p == replace_pred
            g[s][p] = o
          else
            g[s][p] = o
          end
        end
        true
      end

      def flatten(graph_hash)
        out = []
        graph_hash.each do |s, preds|
          preds.each { |p, o| out << { s: s, p: p, o: o } }
        end
        out
      end
    end
  end
end
