# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

require_relative "result"
require_relative "seed"
require_relative "flow_template"
require_relative "medallion_flow"
require_relative "sal_view"
require_relative "graph_projection"
require_relative "tier"

module Mmg
  module Medallion
    # MCB registration surface for medallion flow (never-raise handlers).
    module PlatformActions
      module_function

      def mcb_actions
        [
          {
            name: "medallion_seed",
            domain: "medallion",
            personas: %w[superdev developer],
            describe: "Idempotent seed Bronze/Silver/Gold medallion tiers. Never-raise.",
            input_schema: { type: "object", properties: {} },
            handler: ->(_i, _c) { Seed.call }
          },
          {
            name: "medallion_template",
            domain: "medallion",
            personas: %w[superdev developer],
            describe: "Build a FlowTemplate from stage stamp maps. Never-raise.",
            input_schema: {
              type: "object",
              properties: {
                key: { type: "string" },
                stamps: {
                  type: "object",
                  description: "Optional {bronze:[], silver:[], gold:[]} stamp maps"
                }
              },
              required: %w[key]
            },
            handler: ->(i, _c) {
              h = stringify(i)
              stamps = h["stamps"] || {}
              r = FlowTemplate.build(h["key"]) do
                bronze { Array(stamps["bronze"]).each { |s| stamp(**symbolize_pairs(s)) } }
                silver { Array(stamps["silver"]).each { |s| stamp(**symbolize_pairs(s)) } }
                gold   { Array(stamps["gold"]).each { |s| stamp(**symbolize_pairs(s)) } }
              end
              return r unless r[:ok]
              r.merge(template: r[:template]&.to_h)
            }
          },
          {
            name: "medallion_flow_start",
            domain: "medallion",
            personas: %w[superdev developer],
            describe: "Start Bronze→Silver→Gold flow for a subject IRI. Never-raise.",
            input_schema: {
              type: "object",
              properties: {
                subject: { type: "string" },
                subject_iri: { type: "string" },
                template_key: { type: "string" },
                idempotency_key: { type: "string" }
              }
            },
            handler: ->(i, _c) {
              h = stringify(i)
              subj = h["subject"] || h["subject_iri"]
              return Result.failure(:subject_required, "subject or subject_iri required") if subj.to_s.empty?

              MedallionFlow.start(
                subject: subj,
                template: h["template_key"],
                idempotency_key: h["idempotency_key"]
              )
            }
          },
          {
            name: "medallion_promote",
            domain: "medallion",
            personas: %w[superdev developer],
            describe: "Adjacent promote subject flow (bronze→silver or silver→gold). Never-raise.",
            input_schema: {
              type: "object",
              properties: {
                subject: { type: "string" },
                subject_iri: { type: "string" },
                to: { type: "string", enum: %w[silver gold] },
                idempotency_key: { type: "string" }
              },
              required: %w[to]
            },
            handler: ->(i, _c) {
              h = stringify(i)
              subj = h["subject"] || h["subject_iri"]
              return Result.failure(:subject_required, "subject or subject_iri required") if subj.to_s.empty?

              MedallionFlow.promote(subject: subj, to: h["to"], idempotency_key: h["idempotency_key"])
            }
          },
          {
            name: "medallion_current",
            domain: "medallion",
            personas: %w[superdev developer vibe],
            describe: "Current medallion tier + flow for subject. Never-raise.",
            input_schema: {
              type: "object",
              properties: {
                subject: { type: "string" },
                subject_iri: { type: "string" }
              }
            },
            handler: ->(i, _c) {
              h = stringify(i)
              subj = h["subject"] || h["subject_iri"]
              return Result.failure(:subject_required, "subject or subject_iri required") if subj.to_s.empty?

              MedallionFlow.current(subject: subj)
            }
          },
          {
            name: "medallion_sal_view",
            domain: "medallion",
            personas: %w[superdev developer vibe],
            describe: "ACIA subtree for medallion flow (SAL/render consume). Never-raise.",
            input_schema: {
              type: "object",
              properties: {
                subject: { type: "string" },
                subject_iri: { type: "string" }
              }
            },
            handler: ->(i, _c) {
              h = stringify(i)
              subj = h["subject"] || h["subject_iri"]
              return Result.failure(:subject_required, "subject or subject_iri required") if subj.to_s.empty?

              SalView.for(subject: subj)
            }
          },
          {
            name: "medallion_status",
            domain: "medallion",
            personas: %w[superdev developer vibe],
            describe: "Medallion gem status + canonical tiers.",
            input_schema: { type: "object", properties: {} },
            handler: ->(_i, _c) {
              Seed.call if Tier.memory.empty? && !Tier.ar_ready?
              {
                ok: true,
                version: VERSION,
                tiers: Tier.in_rank_order.map(&:to_h),
                actions: mcb_actions.map { |a| a[:name] },
                flows: MedallionFlow.store.size
              }
            }
          }
        ]
      end

      def stringify(input)
        (input || {}).each_with_object({}) { |(k, v), a| a[k.to_s] = v }
      end

      def symbolize_pairs(s)
        h = s.is_a?(Hash) ? s : { "value" => s }
        if h.key?("key") || h.key?(:key)
          { (h["key"] || h[:key]).to_sym => (h["value"] || h[:value]) }
        else
          h.transform_keys(&:to_sym)
        end
      end
    end
  end
end
