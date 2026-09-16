# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

require "securerandom"
require "time"
require_relative "result"
require_relative "vocab"
require_relative "tier"
require_relative "seed"
require_relative "subject_ref"
require_relative "grounding"
require_relative "promotion"
require_relative "flow_template"
require_relative "storable_local"
require_relative "graph_projection"

module Mmg
  module Medallion
    # Subject-scoped Bronze → Silver → Gold flow instance (design §3, §6).
    class MedallionFlow
      include StorableLocal

      STORE = {} # subject_iri => flow snapshot

      attr_reader :subject_ref, :template, :idempotency_key, :current_tier_slug,
                  :event_log, :started_at, :flow_iri

      def initialize(subject_ref:, template:, idempotency_key: nil, current_tier_slug: "bronze")
        @subject_ref = SubjectRef.coerce(subject_ref)
        @template = template
        @idempotency_key = (idempotency_key || "idemp_#{SecureRandom.hex(6)}").to_s
        @current_tier_slug = current_tier_slug.to_s
        @event_log = []
        @started_at = Time.now.utc
        @flow_iri = Vocab.flow(@subject_ref.iri)
      end

      def iri
        flow_iri
      end

      def current_tier
        Tier.for(current_tier_slug)
      end

      def to_h
        {
          iri: iri,
          subject_iri: subject_ref.iri,
          graph_iri: subject_ref.graph_iri,
          current_tier: current_tier_slug,
          template_key: template&.key,
          idempotency_key: idempotency_key,
          events: event_log.map { |e| e.is_a?(Hash) ? e : e.to_h },
          started_at: started_at.iso8601
        }
      end

      triples do
        triple iri, Vocab::RDF_TYPE, Vocab::MEDALLION_FLOW
        triple iri, Vocab::SUBJECT, subject_ref.iri
        triple iri, Vocab::MEDALLION_TIER_P, current_tier.iri if current_tier
        triple iri, Vocab::FLOW_TEMPLATE, template.iri if template
      end

      class << self
        def store
          STORE
        end

        def clear!
          STORE.clear
          { ok: true }
        end

        def find(subject)
          ref = SubjectRef.coerce(subject)
          STORE[ref.iri]
        end

        # Start a flow at Bronze (or resume existing idempotent).
        def start(subject:, template: nil, idempotency_key: nil, &block)
          Result.capture(reason: :flow_start_failed) do
            seed = Seed.call
            return seed unless seed[:ok]

            tpl_result = resolve_template(template, &block)
            return tpl_result unless tpl_result[:ok]

            tpl = tpl_result[:template]
            ref = SubjectRef.coerce(subject)
            existing = STORE[ref.iri]
            if existing && idempotency_key && existing.idempotency_key == idempotency_key.to_s
              return Result.success(flow: existing.to_h, grounding: existing.grounding_triples,
                                   events: existing.event_log, idempotent: true)
            end

            flow = new(subject_ref: ref, template: tpl, idempotency_key: idempotency_key)
            bronze = Tier.for("bronze")
            return Result.failure(:tier_registry_incomplete, "bronze absent — seed first") unless bronze

            event = {
              "id" => "ev_#{SecureRandom.hex(8)}",
              "type" => "medallion.flow_started.v1",
              "subject_iri" => ref.iri,
              "graph_iri" => ref.graph_iri,
              "flow_iri" => flow.iri,
              "tier_slug" => "bronze",
              "stamps" => tpl.stamps_for("bronze"),
              "at" => Time.now.utc.iso8601
            }
            flow.event_log << event
            grounding = Grounding.new(subject_ref: ref, tier: bronze)
            STORE[ref.iri] = flow

            proj = GraphProjection.new.apply_hash(event.merge("to_tier_slug" => "bronze"))
            Result.success(
              flow: flow.to_h,
              grounding: grounding.emit_triples,
              projection: proj,
              events: [event],
              tier: bronze.to_h
            )
          end
        end

        # Adjacent promotion only (bronze→silver, silver→gold).
        def promote(subject:, to:, idempotency_key: nil, stamps: nil)
          Result.capture(reason: :promote_failed) do
            seed = Seed.call
            return seed unless seed[:ok]

            ref = SubjectRef.coerce(subject)
            flow = STORE[ref.iri]
            return Result.failure(:flow_not_found, "no medallion flow for #{ref.iri}") unless flow

            to_slug = to.to_s.downcase
            return Result.failure(:unknown_tier, "to must be silver|gold") unless %w[silver gold].include?(to_slug)

            from = flow.current_tier
            dest = Tier.for(to_slug)
            return Result.failure(:tier_registry_incomplete, "#{to_slug} absent") unless dest
            return Result.failure(:illegal_transition,
                                 "cannot promote #{from.slug} → #{to_slug} (adjacent only)") unless adjacent?(from, dest)

            # Idempotent: already at dest
            if flow.current_tier_slug == to_slug
              return Result.success(flow: flow.to_h, idempotent: true, tier: dest.to_h)
            end

            event_id = "ev_#{SecureRandom.hex(8)}"
            promo_stamps = stamps || flow.template&.stamps_for(to_slug) || []
            promo = Promotion.new(
              event_id: event_id,
              flow_iri: flow.iri,
              subject_ref: ref,
              from_tier: from,
              to_tier: dest,
              stamps: promo_stamps
            )
            event = {
              "id" => event_id,
              "type" => "medallion.promoted.v1",
              "event_id" => event_id,
              "subject_iri" => ref.iri,
              "graph_iri" => ref.graph_iri,
              "flow_iri" => flow.iri,
              "from_tier_slug" => from.slug,
              "to_tier_slug" => dest.slug,
              "stamps" => promo_stamps,
              "occurred_at" => promo.occurred_at.iso8601,
              "at" => Time.now.utc.iso8601
            }
            flow.event_log << event
            flow.instance_variable_set(:@current_tier_slug, to_slug)
            grounding = Grounding.new(subject_ref: ref, tier: dest)
            proj = GraphProjection.new.apply_hash(event)

            Result.success(
              flow: flow.to_h,
              promotion: promo.to_h,
              promotion_triples: promo.emit_triples,
              grounding: grounding.emit_triples,
              projection: proj,
              tier: dest.to_h
            )
          end
        end

        def current(subject:)
          Result.capture(reason: :current_failed) do
            ref = SubjectRef.coerce(subject)
            flow = STORE[ref.iri]
            return Result.failure(:flow_not_found, "no medallion flow for #{ref.iri}") unless flow

            tier = flow.current_tier
            Result.success(
              flow: flow.to_h,
              tier: tier&.to_h,
              subject_iri: ref.iri,
              grounding: Grounding.new(subject_ref: ref, tier: tier).emit_triples
            )
          end
        end

        def grounding_for(subject)
          flow = find(subject)
          return [] unless flow && flow.current_tier

          Grounding.new(subject_ref: flow.subject_ref, tier: flow.current_tier).emit_triples
        end

        private

        def adjacent?(from, to)
          to.rank == from.rank + 1
        end

        def resolve_template(template, &block)
          case template
          when FlowTemplate
            Result.success(template: template)
          when Hash
            if template[:ok] && template[:template]
              Result.success(template: template[:template])
            elsif template["key"] || template[:key]
              key = template["key"] || template[:key]
              stamps = template["stamps_by_stage"] || template[:stamps_by_stage] || default_stamps
              Result.success(template: FlowTemplate.new(key: key, stamps_by_stage: stamps))
            else
              Result.failure(:invalid_template, "template hash needs key")
            end
          when String, Symbol
            Result.success(template: FlowTemplate.new(key: template, stamps_by_stage: default_stamps))
          when nil
            if block
              FlowTemplate.build("inline_#{SecureRandom.hex(4)}", &block)
            else
              Result.success(template: FlowTemplate.new(key: "default", stamps_by_stage: default_stamps))
            end
          else
            Result.failure(:invalid_template, "unsupported template type #{template.class}")
          end
        end

        def default_stamps
          {
            "bronze" => [{ "key" => "layer", "value" => "bronze" }],
            "silver" => [{ "key" => "layer", "value" => "silver" }],
            "gold" => [{ "key" => "layer", "value" => "gold" }]
          }
        end
      end

      def grounding_triples
        return [] unless current_tier

        Grounding.new(subject_ref: subject_ref, tier: current_tier).emit_triples
      end
    end
  end
end
