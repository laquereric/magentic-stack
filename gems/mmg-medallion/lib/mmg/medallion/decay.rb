# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

require_relative "result"

module Mmg
  module Medallion
    # Per-tier decay policy (M8). Not a global TTL.
    #
    # Retention hints used to be slogans (ephemeral_candidate /
    # review_extend / retain_unless_governed). This binds each slogan to a
    # clock and to the evidence a forget must carry before the cascade
    # walks. Forget evidence must match the clock: a Bronze tombstone
    # executes on the legal-retention clock, so it names its retention
    # basis and who decided; Silver closes carry their successor or
    # correction row by construction; Gold utility is a review, not a timer.
    module Decay
      POLICIES = {
        "bronze" => {
          clock: "legal_retention",
          evidence: %w[retention_basis decided_by],
          meaning: "Bronze decays on a legal-retention clock; working memory (volatile Bronze) " \
                   "decays when the session ends"
        },
        "silver" => {
          clock: "contradiction_supersession",
          evidence: %w[superseding_fact_id contradicting_fact_id],
          meaning: "Silver decays on contradiction and supersession; the closing row IS the evidence"
        },
        "gold" => {
          clock: "utility",
          evidence: %w[utility_review],
          meaning: "Gold decays on utility; a 0-weight activation remains visible on inspect, " \
                   "it is just not injected"
        }
      }.freeze

      module_function

      def policy(tier)
        t = tier.to_s.downcase
        p = POLICIES[t]
        unless p
          return Result.failure(
            :audit_rejected,
            "no decay policy for tier #{tier.inspect}; policies exist for #{POLICIES.keys.join(', ')}"
          )
        end

        Result.success(tier: t, clock: p[:clock], evidence: p[:evidence], meaning: p[:meaning])
      end

      def bound?
        POLICIES.keys.sort == %w[bronze gold silver] &&
          POLICIES.values.map { |p| p[:clock] }.uniq.size == 3
      end

      # nil when the forget evidence matches the tier's clock; a refusal
      # otherwise. Never-raise. Silver closes are validated by
      # construction (the successor/correction row), so this gate serves
      # the Bronze tombstone and the Gold utility review.
      def evidence_refusal(tier:, evidence:)
        pol = policy(tier)
        return pol unless pol[:ok]

        ev = evidence.is_a?(Hash) ? evidence.transform_keys(&:to_s) : {}
        # Silver: either closing key satisfies the clock.
        if pol[:tier] == "silver"
          return nil if pol[:evidence].any? { |k| present?(ev[k]) }

          return Result.failure(
            :audit_rejected,
            "a Silver close executes on the #{pol[:clock]} clock; evidence must name " \
            "#{pol[:evidence].join(' or ')}"
          )
        end

        missing = pol[:evidence].reject { |k| present?(ev[k]) }
        return nil if missing.empty?

        Result.failure(
          :audit_rejected,
          "a #{pol[:tier]} forget executes on the #{pol[:clock]} clock; evidence is missing " \
          "#{missing.join(', ')}"
        )
      end

      def present?(value)
        !value.nil? && !(value.respond_to?(:empty?) && value.empty?)
      end
      private_class_method :present?
    end
  end
end
