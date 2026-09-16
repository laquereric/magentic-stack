# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

require_relative "layer"
require_relative "purpose"
require_relative "result"

module Mmg
  module Medallion
    # Semantic Flow: source graph(s) → target layer graph with audit hooks.
    # P0/P1 of semantic medallion — namespace-safe registry + layer contract.
    #
    # M7: purpose is CARRIED, not only documented. Consume and Operate are
    # siblings of Build, not ranks. A Consume flow targeting a Build tier is
    # refused here so Platinum cannot arrive as a fourth rank.
    class Flow
      REGISTRY = {}

      attr_reader :name, :source_graphs, :target_tier, :shape_set, :version, :promotion_policy,
                  :purpose

      def initialize(name, source_graphs: [], target_tier: "silver", shape_set: nil, version: "1",
                     promotion_policy: "manual", purpose: Purpose::BUILD)
        @name = name.to_s
        @source_graphs = Array(source_graphs)
        @target_tier = target_tier.to_s.downcase
        @shape_set = shape_set
        @version = version.to_s
        @promotion_policy = promotion_policy.to_s
        @purpose = (Purpose.coerce(purpose) || purpose.to_s.downcase)
      end

      def self.register(name, **kwargs)
        f = new(name, **kwargs)
        REGISTRY[f.name] = f
        f
      end

      def self.find(name) = REGISTRY[name.to_s]
      def self.names = REGISTRY.keys.sort

      def contract
        layer = Layer.contract(target_tier)
        return layer unless layer[:ok]

        {
          ok: true,
          flow: name,
          source_graphs: source_graphs,
          target_tier: target_tier,
          target_graph: Layer.graph_iri(flow: name, tier: target_tier, revision: version),
          shape_set: shape_set,
          version: version,
          promotion_policy: promotion_policy,
          purpose: purpose,
          layer: layer,
          retention_hint: Layer.retention_hint(target_tier)
        }
      end

      def build? = purpose == Purpose::BUILD

      # nil when the flow may run; a refusal otherwise. Never-raise (M7).
      def refusal
        unless Purpose.valid?(purpose)
          return Result.failure(:audit_rejected,
                                "purpose must be build|consume|operate, got #{purpose.inspect}")
        end

        if build? && !Layer.valid?(target_tier)
          if target_tier == "platinum"
            return Result.failure(
              :platinum_not_a_tier,
              "platinum is not a Build tier: knowledge folded into weights has no tombstone; " \
              "it is Purpose::OPERATE, an optional rebuildable cache distilled from SILVER"
            )
          end
          return Result.failure(:unknown_tier,
                                "unknown tier #{target_tier.inspect}; the Build tiers are bronze, silver, gold")
        end

        if !build? && Layer.valid?(target_tier)
          return Result.failure(
            :audit_rejected,
            "#{name} is #{purpose} but targets the Build tier #{target_tier}; a Consume or Operate " \
            "thing wearing a Build rank is what lets Platinum in"
          )
        end

        nil
      end

      # Dry projection plan (no write). Conformer/Curator actuators later.
      def plan_projection(revision: nil)
        c = contract
        return c unless c[:ok]

        rev = (revision || version).to_s
        {
          ok: true,
          dry_run: true,
          flow: name,
          from: source_graphs,
          to: Layer.graph_iri(flow: name, tier: target_tier, revision: rev),
          gate: c[:layer][:gate],
          audit: {
            flow: name,
            version: rev,
            shape_set: shape_set,
            policy: promotion_policy,
            purpose: purpose
          },
          because: "P1 dry plan — Conformer write + SHACL gate not armed"
        }
      end
    end
  end
end
