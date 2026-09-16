# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

require_relative "result"
require_relative "tier"
require_relative "flow_template"
require_relative "medallion_flow"

module Mmg
  module Medallion
    # Single ACIA subtree for a MedallionFlow — consumed by mmg-sal/mmg-render (no fork).
    class SalView
      def self.for(subject:)
        Result.capture(reason: :sal_view_failed) do
          current = MedallionFlow.current(subject: subject)
          return current unless current[:ok]

          flow_h = current[:flow]
          tier_h = current[:tier]
          tier = Tier.for(tier_h.is_a?(Hash) ? tier_h[:slug] || tier_h["slug"] : tier_h)
          node = new(flow: flow_h, current_tier: tier).acia_node
          Result.success(node: node, subject_iri: flow_h[:subject_iri] || flow_h["subject_iri"])
        end
      end

      def initialize(flow:, current_tier:)
        @flow = flow.is_a?(Hash) ? flow.transform_keys(&:to_s) : flow
        @current_tier = current_tier
      end

      def acia_node
        flow_iri = @flow["iri"] || @flow[:iri]
        {
          "id" => "medallion-flow:#{flow_iri}",
          "kind" => "group",
          "semantic_role" => "medallion_flow",
          "label" => "Medallion refinement flow",
          "properties" => {
            "subject_iri" => @flow["subject_iri"],
            "current_tier" => @current_tier&.slug,
            "flow_iri" => flow_iri
          },
          "children" => FlowTemplate::STAGES.map { |slug| tier_node(slug) }
        }
      end

      private

      def tier_node(slug)
        tier = Tier.for(slug)
        state =
          if @current_tier.nil?
            "pending"
          elsif tier.rank < @current_tier.rank
            "complete"
          elsif tier.rank == @current_tier.rank
            "current"
          else
            "pending"
          end

        {
          "id" => "medallion-flow:#{@flow['iri']}:tier:#{slug}",
          "kind" => "step",
          "semantic_role" => "medallion_tier",
          "label" => tier&.name || slug.capitalize,
          "description" => tier&.description,
          "state" => state,
          "properties" => {
            "tier_iri" => tier&.iri,
            "rank" => tier&.rank,
            "current" => state == "current"
          }
        }
      end
    end
  end
end
