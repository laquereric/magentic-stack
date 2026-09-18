# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

require_relative "result"

module Mmg
  module Medallion
    # M3: the doctrine as a method. Doctrine with no method is a comment.
    #
    # audit! judges a promotion proposal and rejects, never-raise:
    #   (a) a proposed fourth Build tier,
    #   (b) Bronze that transforms,
    #   (c) Silver that only copies,
    #   (d) Gold promotion without SemanticModel + Contract + SHACL report + CAS.
    #
    # The proposal is data: string or symbol keys. The (b)/(c) flags describe
    # stage behavior and fire wherever the proposal claims to target --
    # a Bronze landing that transforms is refused even if nothing else is
    # wrong with it. Flags are strict booleans: only `true` fires, so a
    # stray string can never arm a rejection (or disarm one).
    #
    # Split of duties, so this never drifts from the actuators: audit!
    # checks the PRESENCE of Gold evidence; Curator on the armed path
    # checks its DEPTH (governed model, matching contract, live SLA).
    # Purpose policing (a Consume/Operate thing wearing a Build rank)
    # lives in Flow (M7), not here.
    module Audit
      TIERS = %w[bronze silver gold].freeze
      GOLD_EVIDENCE = %w[semantic_model contract shacl_report cas_digest].freeze

      module_function

      def call(proposal)
        p = proposal.is_a?(Hash) ? proposal.transform_keys(&:to_s) : {}
        tier = p["tier"].to_s.downcase

        unless TIERS.include?(tier)
          return Result.failure(:audit_rejected, fourth_tier_because(p["tier"]))
        end

        if p["bronze_transforms"] == true
          return Result.failure(
            :audit_rejected,
            "Bronze is raw landing: nothing overwritten, nothing summarised in place. " \
            "A Bronze step that transforms is bronze_mutated wearing a proposal's clothes"
          )
        end

        if p["silver_copies"] == true
          return Result.failure(
            :audit_rejected,
            "Silver's unique state-change is conformance (identity, timestamp, SHACL). " \
            "A Silver step that only copies adds no meaning and promotes nothing"
          )
        end

        if tier == "gold"
          missing = GOLD_EVIDENCE.reject { |k| present?(p[k]) }
          unless missing.empty?
            return Result.failure(
              :audit_rejected,
              "a Gold promotion without #{missing.join(', ')} is not a governed product; " \
              "Gold is defined once, with model, contract, gate report, and content address"
            )
          end
        end

        Result.success(tier: tier, checks: checks_for(tier))
      end

      def checks_for(tier)
        checks = %w[no_fourth_tier bronze_does_not_transform]
        checks << "silver_conforms" if %w[silver gold].include?(tier)
        checks << "gold_evidenced" if tier == "gold"
        checks
      end
      private_class_method :checks_for

      def fourth_tier_because(asked)
        if asked.to_s.downcase == "platinum"
          "proposed fourth Build tier \"platinum\": knowledge folded into weights has no " \
          "tombstone, so it is Purpose::OPERATE, never a rank. This maximalism is what " \
          "audit! exists to reject"
        else
          "proposed tier #{asked.inspect}: the Build tiers are #{TIERS.join(', ')}. " \
          "A fourth rank is exactly the maximalism audit! exists to reject"
        end
      end
      private_class_method :fourth_tier_because

      def present?(value)
        !value.nil? && !(value.respond_to?(:empty?) && value.empty?)
      end
      private_class_method :present?
    end
  end
end
